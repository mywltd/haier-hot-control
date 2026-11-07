import 'package:fluent_ui/fluent_ui.dart';
import 'package:window_manager/window_manager.dart';

import '../app/desktop_session.dart';
import '../app/theme.dart';
import '../app/window_activity.dart';
import '../app/window_bootstrap.dart';
import '../app/shell_settings.dart';
import '../pages/home/home_page.dart';
import '../pages/list/list_page.dart';
import '../pages/settings/settings_page.dart';
import 'close_prompt.dart';
import 'nav_sidebar.dart';
import 'page_switcher.dart';

/// 侧栏页面下标，配合 [ShellNavScope.goTo] 跳转。
abstract final class ShellPage {
  static const home = 0;
  static const list = 1;
  static const settings = 2;
}

class ShellNavScope extends InheritedWidget {
  const ShellNavScope({super.key, required this.goTo, required super.child});

  final ValueChanged<int> goTo;

  static ShellNavScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ShellNavScope>();
    if (scope == null) {
      throw StateError('ShellNavScope 未找到');
    }
    return scope;
  }

  @override
  bool updateShouldNotify(ShellNavScope oldWidget) => goTo != oldWidget.goTo;
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    DesktopSession.maybeInstance?.closePrompt = _askClose;
  }

  @override
  void dispose() {
    final session = DesktopSession.maybeInstance;
    if (session?.closePrompt == _askClose) {
      session!.closePrompt = null;
    }
    super.dispose();
  }

  Future<CloseAction?> _askClose() async {
    if (!mounted) {
      return CloseAction.tray;
    }
    return showClosePrompt(context, ShellSettings.instance);
  }

  void _goTo(int index) {
    if (_index == index) {
      return;
    }
    setState(() => _index = index);
  }

  // 页面入口：图标统一用 Segoe Fluent 线性图标，选中时只换主题色。
  static const _pages = [
    (NavEntry(label: '首页', icon: WindowsIcons.home, fallbackIcon: FluentIcons.home), HomePage()),
    (NavEntry(label: '列表', icon: WindowsIcons.bulleted_list, fallbackIcon: FluentIcons.bulleted_list), ListPage()),
  ];

  static const _settingsEntry = NavEntry(
    label: '设置',
    icon: WindowsIcons.settings,
    fallbackIcon: FluentIcons.settings,
  );

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final appTheme = AppThemeScope.of(context);
    final resources = theme.resources;
    final dark = theme.brightness == Brightness.dark;

    return ShellNavScope(
      goTo: _goTo,
      child: NavigationView(
        // 高标题栏 48：图标 20 与侧栏图标对齐，标题 Body；系统按钮仍为 32 高、贴顶。
        titleBar: TitleBar(
          height: 48,
          isBackButtonVisible: false,
          leftHeader: Padding(
            padding: const EdgeInsetsDirectional.only(start: 26),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/app_icon.ico',
                  width: 20,
                  height: 20,
                  errorBuilder: (_, _, _) => const SizedBox(width: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  kAppTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // 窗口失焦时标题变灰，同 Windows 11 系统标题栏。
                  style: theme.typography.body?.copyWith(
                    color: WindowActivityScope.activeOf(context)
                        ? resources.textFillColorPrimary
                        : resources.textFillColorTertiary,
                  ),
                ),
              ],
            ),
          ),
          captionControls: const Align(
            alignment: AlignmentDirectional.topEnd,
            widthFactor: 1,
            child: _WindowCaptionButtons(),
          ),
          onDragStarted: isDesktopWindow ? windowManager.startDragging : null,
          onDoubleTap: isDesktopWindow
              ? () async {
                  if (await windowManager.isMaximized()) {
                    await windowManager.restore();
                  } else {
                    await windowManager.maximize();
                  }
                }
              : null,
        ),
        // 切页过渡由 PageSwitcher 负责：它常驻不换 key，NavigationView 自带的转场不会触发。
        paneBodyBuilder: (item, body) => PageSwitcher(
          pageKey: _index,
          child: body ?? const SizedBox.shrink(),
        ),
        pane: NavigationPane(
          selected: _index,
          onChanged: _goTo,
          displayMode: PaneDisplayMode.compact,
          toggleable: false,
          toggleButton: null,
          // 侧栏自绘：NavigationView 只负责页面切换与转场。
          customPane: NavSidebarPane(
            entries: [for (final p in _pages) p.$1],
            footer: [
              // 图标反映当前实际的亮暗，文字是当前状态。
              NavEntry(
                label: appTheme.paneLabel,
                icon: dark ? WindowsIcons.quiet_hours : WindowsIcons.brightness,
                fallbackIcon: FluentIcons.brightness,
                onTap: appTheme.toggle,
              ),
              _settingsEntry,
            ],
          ),
          items: [
            for (final p in _pages) PaneItem(icon: const SizedBox(), body: p.$2),
          ],
          footerItems: [
            PaneItem(icon: const SizedBox(), body: const SettingsPage()),
          ],
        ),
      ),
    );
  }
}

class _WindowCaptionButtons extends StatefulWidget {
  const _WindowCaptionButtons();

  @override
  State<_WindowCaptionButtons> createState() => _WindowCaptionButtonsState();
}

class _WindowCaptionButtonsState extends State<_WindowCaptionButtons>
    with WindowListener {
  final _closeFlyout = FlyoutController();

  @override
  void initState() {
    super.initState();
    if (isDesktopWindow) {
      windowManager.addListener(this);
    }
  }

  @override
  void dispose() {
    if (isDesktopWindow) {
      windowManager.removeListener(this);
    }
    _closeFlyout.dispose();
    super.dispose();
  }

  @override
  void onWindowMaximize() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _close() async {
    final session = DesktopSession.maybeInstance;
    if (session != null) {
      await session.requestClose();
      return;
    }
    await windowManager.close();
  }

  Future<void> _hideToTray() async {
    final session = DesktopSession.maybeInstance;
    if (session != null) {
      await session.hideToTray();
      return;
    }
    await windowManager.close();
  }

  Future<void> _showCloseFlyout() {
    return _closeFlyout.showFlyout(
      barrierColor: Colors.transparent,
      builder: (context) {
        return MenuFlyout(
          items: [
            MenuFlyoutItem(
              leading: const WindowsIcon(
                WindowsIcons.chevron_down,
                size: 16,
                fallbackIcon: FluentIcons.chevron_down,
              ),
              text: const Text('最小化到托盘'),
              onPressed: () {
                Flyout.of(context).close();
                _hideToTray();
              },
            ),
            MenuFlyoutItem(
              leading: const WindowsIcon(
                WindowsIcons.power_button,
                size: 16,
                fallbackIcon: FluentIcons.power_button,
              ),
              text: const Text('退出'),
              onPressed: () {
                Flyout.of(context).close();
                DesktopSession.maybeInstance?.quit();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isDesktopWindow) {
      return const SizedBox.shrink();
    }
    final theme = FluentTheme.of(context);
    return SizedBox(
      width: 138,
      height: 32,
      child: Row(
        children: [
          WindowCaptionButton.minimize(
            brightness: theme.brightness,
            onPressed: () async {
              if (await windowManager.isMinimized()) {
                await windowManager.restore();
              } else {
                await windowManager.minimize();
              }
            },
          ),
          FutureBuilder<bool>(
            future: windowManager.isMaximized(),
            builder: (context, snapshot) {
              if (snapshot.data == true) {
                return WindowCaptionButton.unmaximize(
                  brightness: theme.brightness,
                  onPressed: windowManager.unmaximize,
                );
              }
              return WindowCaptionButton.maximize(
                brightness: theme.brightness,
                onPressed: windowManager.maximize,
              );
            },
          ),
          FlyoutTarget(
            controller: _closeFlyout,
            child: Tooltip(
              message: '关闭（右键可直接选择）',
              child: GestureDetector(
                onSecondaryTap: _showCloseFlyout,
                child: WindowCaptionButton.close(
                  brightness: theme.brightness,
                  onPressed: _close,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
