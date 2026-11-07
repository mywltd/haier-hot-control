import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart' as tray;
import 'package:window_manager/window_manager.dart' as native;

import 'desktop_window.dart';
import 'launch_at_startup.dart';
import 'shell_settings.dart';
import 'theme.dart';
import 'window_bootstrap.dart';

typedef ClosePrompt = Future<CloseAction?> Function();

/// 应用身份与窗口会话留在外壳，不进入纯 UI 组件包。
class DesktopSession extends ChangeNotifier {
  DesktopSession._();
  static DesktopSession? _instance;
  static DesktopSession? get maybeInstance => _instance;
  static DesktopSession get instance =>
      _instance ?? (throw StateError('桌面会话尚未初始化'));

  bool _launchAtStartup = false;
  bool _quitting = false;
  bool _prompting = false;
  native.ListenerId? _windowListener;
  tray.TrayIcon? _tray;
  tray.Menu? _menu;
  tray.MenuItem? _autostartItem;
  final _menuItems = <tray.MenuItem>[];
  final _menuListeners = <tray.ListenerId>[];
  tray.ListenerId? _trayListener;
  ClosePrompt? closePrompt;
  Future<void> Function()? onQuit;
  bool get launchAtStartupEnabled => _launchAtStartup;

  static Future<void> bootstrap() async {
    if (!isDesktopWindow || _instance != null) return;
    final session = _instance = DesktopSession._();
    session._init();
  }

  void _init() {
    _windowListener = desktopWindow.addListener((event) {
      if (event is native.WindowCloseRequestedEvent && !_quitting) {
        // 先同步拦下关闭，再等待界面层的异步确认。
        event.request.cancel();
        unawaited(requestClose());
      }
    });
    try {
      _launchAtStartup = LaunchAtStartup.isEnabled();
    } catch (error, stack) {
      developer.log('读取开机启动失败', error: error, stackTrace: stack);
    }
    try {
      final icon = _tray = tray.TrayIcon.create();
      if (icon == null) throw StateError('系统未创建托盘图标');
      icon.icon = tray.ImageAsset.fromAsset('assets/app_icon.ico');
      icon.setTooltip(kAppTitle);
      _trayListener = icon.addListener((event) {
        if (event is tray.TrayIconClickedEvent) unawaited(showWindow());
      });
      final menu = _menu = tray.Menu.create();
      if (menu == null) throw StateError('系统未创建托盘菜单');
      _addItem(menu, '显示主窗口', () => unawaited(showWindow()));
      _autostartItem = _addItem(
        menu,
        '开机自启动',
        () => unawaited(setLaunchAtStartup(!_launchAtStartup)),
        checkbox: true,
      );
      _syncAutostart();
      menu.addSeparator();
      _addItem(menu, '退出', () {
        // 等菜单事件释放借用句柄后再销毁原生资源。
        Timer.run(() => unawaited(quit()));
      });
      icon.setContextMenu(menu);
      icon.setContextMenuTrigger(tray.ContextMenuTrigger.rightClicked);
      icon.setVisible(true);
    } catch (error, stack) {
      developer.log('初始化托盘失败', error: error, stackTrace: stack);
    }
  }

  tray.MenuItem _addItem(
    tray.Menu menu,
    String label,
    VoidCallback action, {
    bool checkbox = false,
  }) {
    final item = tray.MenuItem.createWithLabelAndType(
      label,
      checkbox ? tray.MenuItemType.checkbox : tray.MenuItemType.normal,
    );
    if (item == null) throw StateError('无法创建菜单项');
    _menuItems.add(item);
    _menuListeners.add(
      item.addListener((event) {
        if (event is tray.MenuItemClickedEvent) action();
      }),
    );
    menu.addItem(item);
    return item;
  }

  void _syncAutostart() => _autostartItem?.state = _launchAtStartup
      ? tray.MenuItemState.checked
      : tray.MenuItemState.unchecked;

  Future<void> requestClose() async {
    if (_quitting || _prompting) return;
    var action = ShellSettings.instance.closeAction;
    final prompt = closePrompt;
    if (action == CloseAction.ask && prompt != null) {
      _prompting = true;
      try {
        await showWindow();
        action = await prompt() ?? CloseAction.ask;
      } finally {
        _prompting = false;
      }
    }
    switch (action) {
      case CloseAction.tray:
        await hideToTray();
      case CloseAction.exit:
        await quit();
      case CloseAction.ask:
        break;
    }
  }

  Future<void> hideToTray() async {
    if (_quitting) return;
    // 托盘初始化失败时保留可见窗口，避免用户找不到应用。
    if (_tray == null || _menu == null) return;
    desktopWindow.hide();
    desktopWindow.isVisibleInTaskbar = false;
  }

  Future<void> showWindow() async {
    final window = desktopWindow;
    window.isVisibleInTaskbar = true;
    window.show();
    if (window.isMinimized) window.restore();
    window.focus();
  }

  Future<void> setLaunchAtStartup(bool enabled) async {
    LaunchAtStartup.setEnabled(enabled);
    _launchAtStartup = LaunchAtStartup.isEnabled();
    _syncAutostart();
    notifyListeners();
  }

  Future<void> quit() async {
    if (_quitting) return;
    _quitting = true;
    try {
      await onQuit?.call();
    } catch (error, stack) {
      developer.log('退出前业务清理失败', error: error, stackTrace: stack);
    }
    try {
      await ShellSettings.instance.flush();
    } catch (error, stack) {
      developer.log('退出前保存失败', error: error, stackTrace: stack);
    }
    final icon = _tray;
    if (icon != null) {
      final listener = _trayListener;
      if (listener != null) icon.removeListener(listener);
      icon.setVisible(false);
      icon.setContextMenu(null);
      icon.dispose();
      _tray = null;
    }
    for (var i = 0; i < _menuItems.length; i++) {
      _menuItems[i].removeListener(_menuListeners[i]);
    }
    _menu?.clear();
    for (final item in _menuItems) {
      item.dispose();
    }
    _menu?.dispose();
    final listener = _windowListener;
    if (listener != null) desktopWindow.removeListener(listener);
    desktopWindow.isVisibleInTaskbar = true;
    await destroyDesktopWindow();
  }
}
