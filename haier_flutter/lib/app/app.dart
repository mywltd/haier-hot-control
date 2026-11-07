import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';

import '../shell/app_shell.dart';
import '../haier/haier_state.dart';
import '../widgets/ff_focus_dismissal.dart';
import 'shell_settings.dart';
import 'splash_view.dart';
import 'theme.dart';
import 'window_activity.dart';
import 'window_backdrop.dart';
import 'window_bootstrap.dart';

enum _Phase { splash, leaving, main }

class App extends StatefulWidget {
  /// [startup] 不为 null 时先显示启动卡片，等它完成（至少 [kSplashMinDuration]、
  /// 最多 [kSplashMaxDuration]）后再进入主界面；测试里不传，直接显示主界面。
  const App({
    super.key,
    this.startup,
    this.initialAccent,
    this.accentChanges,
    this.state,
  });

  final Future<void>? startup;
  // 原生读色留在入口；测试可注入色阶和变化流，不访问本机设置。
  final AccentColor? initialAccent;
  final Stream<AccentColor>? accentChanges;
  final HaierState? state;

  @override
  State<App> createState() => _AppState();
}

/// 启动卡片至少停留这么久，避免一闪而过；服务器慢时最多等这么久，剩下的连接在后台继续。
const kSplashMinDuration = Duration(milliseconds: 1200);
const kSplashMaxDuration = Duration(seconds: 3);
const _splashFade = Duration(milliseconds: 160);

class _AppState extends State<App> with WidgetsBindingObserver {
  final _activity = WindowActivity();
  // 系统切换透明效果时会插入 / 移除 DisableAcrylic；保留路由、输入和已打开菜单的状态。
  final _materialContentKey = GlobalKey();
  late _Phase _phase = widget.startup == null ? _Phase.main : _Phase.splash;
  // 上次选的主题保存在设置里，重启后保持。
  late final AppThemeController _theme = AppThemeController(
    initialAccent: widget.initialAccent,
    accentChanges: widget.accentChanges,
    initial:
        ThemeMode.values.asNameMap()[ShellSettings.instance.themeMode] ??
        ThemeMode.system,
    onChanged: (mode) =>
        unawaited(ShellSettings.instance.setThemeMode(mode.name)),
  );
  late final _backdropInputs = Listenable.merge([
    ShellSettings.instance,
    backdropOpaque,
  ]);

  // 当前亮 / 暗。材质、毛玻璃参数变化时用它重算窗口背景，不重建整个应用。
  bool? _dark;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _theme.addListener(_onThemeChanged);
    _backdropInputs.addListener(_syncBackdrop);
    _activity.addListener(_onActivityChanged);
    refreshBackdropOpaque();
    final startup = widget.startup;
    if (startup != null) {
      unawaited(_finishSplash(startup));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _activity.removeListener(_onActivityChanged);
    _backdropInputs.removeListener(_syncBackdrop);
    _theme.removeListener(_onThemeChanged);
    _theme.dispose();
    _activity.dispose();
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  // 「透明效果」开关没有通知；多半是去系统设置里切换后再回来，窗口重新激活时重读。
  void _onActivityChanged() {
    if (_activity.active) {
      refreshBackdropOpaque();
    }
  }

  @override
  void didChangeAccessibilityFeatures() => refreshBackdropOpaque();

  /// 启动卡片淡出 → 窗口在原屏幕居中放大 → 主界面淡入；窗口全程可见。
  Future<void> _finishSplash(Future<void> startup) async {
    await Future.wait([
      Future<void>.delayed(kSplashMinDuration),
      startup.timeout(kSplashMaxDuration, onTimeout: () {}).catchError((_) {}),
    ]);
    if (!mounted) {
      return;
    }
    setState(() => _phase = _Phase.leaving);
    if (!WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations) {
      await Future<void>.delayed(_splashFade);
    }
    try {
      await enterMainWindow();
    } catch (_) {}
    if (mounted) {
      setState(() => _phase = _Phase.main);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppThemeScope(
      notifier: _theme,
      child: FluentApp(
        title: kAppTitle,
        locale: kAppLocale,
        supportedLocales: const [kAppLocale, Locale('en')],
        debugShowCheckedModeBanner: false,
        themeMode: _theme.mode,
        color: _theme.accentColor,
        theme: buildAppTheme(Brightness.light, accentColor: _theme.accentColor),
        darkTheme: buildAppTheme(
          Brightness.dark,
          accentColor: _theme.accentColor,
        ),
        builder: (context, child) {
          final dark = _syncWindowEffect(context);
          final content = WindowActivityScope(
            key: _materialContentKey,
            notifier: _activity,
            child: FfFocusDismissal(child: _content(context, child)),
          );
          // 系统关了透明效果时铺纯色（见 backdropOpaque）；平时透明，露出云母 / 毛玻璃。
          return ListenableBuilder(
            listenable: _backdropInputs,
            builder: (context, inner) => ColoredBox(
              color: _planFor(dark).fill ?? Colors.transparent,
              child: backdropOpaque.value
                  ? DisableAcrylic(child: inner!)
                  : inner,
            ),
            child: content,
          );
        },
        home: HaierScope(
          notifier: widget.state ?? HaierState.instance,
          child: const AppShell(),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, Widget? shell) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    switch (_phase) {
      case _Phase.splash:
      case _Phase.leaving:
        return AnimatedOpacity(
          opacity: _phase == _Phase.splash ? 1 : 0,
          duration: reduceMotion ? Duration.zero : _splashFade,
          curve: Curves.easeIn,
          child: const SplashView(),
        );
      case _Phase.main:
        final page = shell ?? const SizedBox.shrink();
        if (widget.startup == null) {
          return page;
        }
        // 从启动卡片过来：主界面淡入。
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          builder: (context, t, child) => Opacity(opacity: t, child: child),
          child: page,
        );
    }
  }

  bool _syncWindowEffect(BuildContext context) {
    final dark = FluentTheme.of(context).brightness == Brightness.dark;
    if (_dark != dark) {
      _dark = dark;
      // 第一帧画出、窗口显示之后再设。显示前就设毛玻璃，启动卡片在 Windows 11 上不模糊、
      // 还拿不到焦点（真窗口实测）；不要挪到 runApp 之前。
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncBackdrop());
    }
    return dark;
  }

  BackdropPlan _planFor(bool dark) => planBackdrop(
    material: ShellSettings.instance.windowMaterial,
    acrylic: ShellSettings.instance.acrylic,
    dark: dark,
  );

  // 不在这里去重：applyBackdrop 对比的是真正生效的方案，上次下发失败时这次会重试。
  void _syncBackdrop() {
    final dark = _dark;
    if (dark != null) {
      unawaited(applyBackdrop(_planFor(dark)));
    }
  }
}
