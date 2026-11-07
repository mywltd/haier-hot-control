import 'package:fluent_ui/fluent_ui.dart';

const String kUiFontFamily = 'Microsoft YaHei UI';

const List<String> kFontFamilyFallback = [
  'Microsoft YaHei',
  'Segoe UI',
  'sans-serif',
];

/// 应用名：标题栏、托盘提示、启动卡片都用它。
const String kAppTitle = '示例应用';

const Locale kAppLocale = Locale('zh', 'CN');

/// 主题只在两种状态间切换：「跟随系统」和与系统相反的那一种。
///
/// 系统浅色时：跟随系统 ⇄ 夜间模式；系统深色时：跟随系统 ⇄ 日间模式。
/// 手动选的模式与系统一致时（例如系统到晚上自动变深色）自动回到跟随系统，
/// 所以永远不会出现「点了却看不出变化」的第三种状态。
class AppThemeController extends ChangeNotifier with WidgetsBindingObserver {
  AppThemeController({ThemeMode initial = ThemeMode.system, this.onChanged})
    : _mode = initial {
    WidgetsBinding.instance.addObserver(this);
    _normalize();
  }

  /// 模式变化后回调，用于持久化。
  final ValueChanged<ThemeMode>? onChanged;
  ThemeMode _mode;

  ThemeMode get mode => _mode;

  Brightness get _platform =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness;

  void toggle() {
    if (_mode != ThemeMode.system) {
      _set(ThemeMode.system);
      return;
    }
    _set(_platform == Brightness.dark ? ThemeMode.light : ThemeMode.dark);
  }

  /// 侧栏按钮文字：当前状态。
  String get paneLabel => switch (_mode) {
    ThemeMode.system => '跟随系统',
    ThemeMode.light => '日间模式',
    ThemeMode.dark => '夜间模式',
  };

  @override
  void didChangePlatformBrightness() => _normalize();

  void _normalize() {
    final matches =
        (_mode == ThemeMode.dark && _platform == Brightness.dark) ||
        (_mode == ThemeMode.light && _platform == Brightness.light);
    if (matches) {
      _set(ThemeMode.system);
    }
  }

  void _set(ThemeMode next) {
    if (_mode == next) {
      return;
    }
    _mode = next;
    notifyListeners();
    onChanged?.call(next);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

class AppThemeScope extends InheritedNotifier<AppThemeController> {
  const AppThemeScope({
    super.key,
    required AppThemeController super.notifier,
    required super.child,
  });

  static AppThemeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppThemeScope>();
    if (scope == null || scope.notifier == null) {
      throw StateError('AppThemeScope 未找到');
    }
    return scope.notifier!;
  }
}

FluentThemeData buildAppTheme(Brightness brightness) {
  final base = Typography.fromBrightness(brightness: brightness);
  return FluentThemeData(
    brightness: brightness,
    accentColor: Colors.blue,
    fontFamily: kUiFontFamily,
    scaffoldBackgroundColor: Colors.transparent,
    // 雅黑没有 Semibold，600 会被渲染成粗体；页面标题、数值等大字用常规体更清爽。
    typography: Typography.raw(
      display: _uiText(base.display?.copyWith(fontWeight: FontWeight.normal)),
      titleLarge: _uiText(
        base.titleLarge?.copyWith(fontWeight: FontWeight.normal),
      ),
      title: _uiText(base.title?.copyWith(fontWeight: FontWeight.normal)),
      subtitle: _uiText(base.subtitle?.copyWith(fontWeight: FontWeight.normal)),
      bodyLarge: _uiText(base.bodyLarge),
      bodyStrong: _uiText(base.bodyStrong),
      body: _uiText(base.body),
      // Windows 11 type ramp：Caption 为 12/16 Regular（fluent_ui 默认 w300）。
      caption: _uiText(base.caption?.copyWith(fontWeight: FontWeight.normal)),
    ),
    // 侧栏与标题栏透出云母；主体内容层的半透明填充见 shell/nav_sidebar.dart。
    // 切页过渡见 shell/page_switcher.dart。
    navigationPaneTheme: const NavigationPaneThemeData(
      backgroundColor: Colors.transparent,
    ),
  );
}

TextStyle? _uiText(TextStyle? style) {
  return style?.copyWith(
    fontFamily: kUiFontFamily,
    fontFamilyFallback: kFontFamilyFallback,
  );
}
