import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:window_manager/window_manager.dart' as native;

import '../app/desktop_session.dart';
import '../app/desktop_window.dart';
import '../app/shell_settings.dart';
import '../app/theme.dart';
import '../app/window_activity.dart';
import '../haier/haier_state.dart';
import '../pages/control/control_page.dart';
import '../pages/devices/devices_page.dart';
import '../pages/login/login_page.dart';
import '../pages/settings/settings_page.dart';
import 'close_prompt.dart';
import 'nav_sidebar.dart';
import 'page_switcher.dart';

abstract final class ShellPage {
  static const devices = 0;
  static const control = 1;
  static const account = 2;
  static const settings = 3;
}

class ShellNavScope extends InheritedWidget {
  const ShellNavScope({super.key, required this.goTo, required super.child});
  final ValueChanged<int> goTo;

  static ShellNavScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellNavScope>()!;

  @override
  bool updateShouldNotify(ShellNavScope oldWidget) => goTo != oldWidget.goTo;
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = ShellPage.devices;

  @override
  void initState() {
    super.initState();
    DesktopSession.maybeInstance?.closePrompt = _askClose;
  }

  @override
  void dispose() {
    final session = DesktopSession.maybeInstance;
    if (session?.closePrompt == _askClose) session!.closePrompt = null;
    super.dispose();
  }

  Future<CloseAction?> _askClose() async =>
      mounted ? showClosePrompt(context, ShellSettings.instance) : null;

  void _goTo(int index) {
    if (_index != index && index >= 0 && index <= ShellPage.settings) {
      setState(() => _index = index);
    }
  }

  static const _entries = [
    NavEntry(
      label: '设备',
      icon: WindowsIcons.devices3,
      fallbackIcon: FluentIcons.devices3,
    ),
    NavEntry(
      label: '控制',
      icon: WindowsIcons.brightness,
      fallbackIcon: FluentIcons.sunny,
    ),
    NavEntry(
      label: '账号',
      icon: WindowsIcons.contact,
      fallbackIcon: FluentIcons.contact,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final appTheme = AppThemeScope.of(context);
    final dark = theme.brightness == Brightness.dark;
    final window = maybeDesktopWindow;
    return ShellNavScope(
      goTo: _goTo,
      child: NavigationView(
        titleBar: TitleBar(
          height: 48,
          isBackButtonVisible: false,
          leftHeader: Padding(
            padding: const EdgeInsetsDirectional.only(start: 26),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/app_icon.ico', width: 20, height: 20),
                const SizedBox(width: 12),
                Text(
                  kAppTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.body?.copyWith(
                    color: WindowActivityScope.activeOf(context)
                        ? theme.resources.textFillColorPrimary
                        : theme.resources.textFillColorTertiary,
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
          onDragStarted: window?.startDragging,
          onDoubleTap: window == null
              ? null
              : () {
                  window.isMaximized ? window.unmaximize() : window.maximize();
                },
        ),
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
          customPane: NavSidebarPane(
            entries: _entries,
            footer: [
              NavEntry(
                label: appTheme.paneLabel,
                icon: dark ? WindowsIcons.quiet_hours : WindowsIcons.brightness,
                fallbackIcon: FluentIcons.brightness,
                onTap: appTheme.toggle,
              ),
              const NavEntry(
                label: '设置',
                icon: WindowsIcons.settings,
                fallbackIcon: FluentIcons.settings,
              ),
            ],
          ),
          items: [
            PaneItem(
              icon: const SizedBox.shrink(),
              body: DevicesPage(
                onSelect: (device) {
                  unawaited(HaierScope.of(context).selectDevice(device.id));
                  _goTo(ShellPage.control);
                },
              ),
            ),
            PaneItem(icon: const SizedBox.shrink(), body: const ControlPage()),
            PaneItem(icon: const SizedBox.shrink(), body: const LoginPage()),
          ],
          footerItems: [
            PaneItem(icon: const SizedBox.shrink(), body: const SettingsPage()),
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

class _WindowCaptionButtonsState extends State<_WindowCaptionButtons> {
  final _closeFlyout = FlyoutController();
  native.ListenerId? _listener;

  @override
  void initState() {
    super.initState();
    _listener = maybeDesktopWindow?.addListener((event) {
      if (event is native.WindowMaximizedEvent ||
          event is native.WindowRestoredEvent) {
        if (mounted) setState(() {});
      }
    });
  }

  @override
  void dispose() {
    if (_listener != null) maybeDesktopWindow?.removeListener(_listener!);
    _closeFlyout.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    final session = DesktopSession.maybeInstance;
    if (session != null) {
      await session.requestClose();
    } else {
      maybeDesktopWindow?.close();
    }
  }

  void _showCloseFlyout() {
    unawaited(
      _closeFlyout.showFlyout(
        placementMode: FlyoutPlacementMode.bottomRight,
        builder: (context) => MenuFlyout(
          items: [
            MenuFlyoutItem(
              leading: const WindowsIcon(
                WindowsIcons.chevron_down,
                fallbackIcon: FluentIcons.chevron_down,
              ),
              text: const Text('最小化到托盘'),
              onPressed: () {
                Flyout.of(context).close();
                unawaited(DesktopSession.maybeInstance?.hideToTray());
              },
            ),
            MenuFlyoutItem(
              leading: const WindowsIcon(
                WindowsIcons.power_button,
                fallbackIcon: FluentIcons.power_button,
              ),
              text: const Text('退出程序'),
              onPressed: () {
                Flyout.of(context).close();
                unawaited(DesktopSession.maybeInstance?.quit());
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = FluentTheme.of(context).brightness;
    final window = maybeDesktopWindow;
    return SizedBox(
      width: 138,
      height: 32,
      child: Row(
        children: [
          Tooltip(
            message: '最小化',
            child: native.WindowCaptionButton.minimize(
              brightness: brightness,
              onPressed: window?.minimize,
            ),
          ),
          Tooltip(
            message: window?.isMaximized == true ? '还原' : '最大化',
            child: window?.isMaximized == true
                ? native.WindowCaptionButton.unmaximize(
                    brightness: brightness,
                    onPressed: window?.unmaximize,
                  )
                : native.WindowCaptionButton.maximize(
                    brightness: brightness,
                    onPressed: window?.maximize,
                  ),
          ),
          FlyoutTarget(
            controller: _closeFlyout,
            child: Tooltip(
              message: '关闭（右键可直接选择）',
              child: GestureDetector(
                onSecondaryTap: window == null ? null : _showCloseFlyout,
                child: native.WindowCaptionButton.close(
                  brightness: brightness,
                  onPressed: window == null ? null : _close,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
