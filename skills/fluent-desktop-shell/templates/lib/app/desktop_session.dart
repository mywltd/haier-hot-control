import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'launch_at_startup.dart';
import 'shell_settings.dart';
import 'theme.dart';
import 'window_bootstrap.dart';

/// 关闭窗口时询问用户；返回 null 表示不关闭。由界面层注册（见 AppShell）。
typedef ClosePrompt = Future<CloseAction?> Function();

/// 常驻托盘、关闭到托盘、开机自启动。
class DesktopSession extends ChangeNotifier
    with WindowListener, TrayListener {
  DesktopSession._();

  static DesktopSession? _instance;

  static DesktopSession? get maybeInstance => _instance;

  static DesktopSession get instance {
    final session = _instance;
    if (session == null) {
      throw StateError('DesktopSession 尚未初始化');
    }
    return session;
  }

  bool _launchAtStartup = false;
  bool _quitting = false;
  bool _prompting = false;

  /// 「每次询问」时用来弹窗。
  ClosePrompt? closePrompt;

  /// 退出前的业务清理（停止服务、写盘等），由应用在启动时注册。
  Future<void> Function()? onQuit;

  bool get launchAtStartupEnabled => _launchAtStartup;

  /// 右上角关闭、Alt+F4、任务栏关闭都走这里：按设置最小化到托盘 / 退出，或弹窗询问。
  Future<void> requestClose() async {
    if (_quitting || _prompting) {
      return;
    }
    var action = ShellSettings.instance.closeAction;
    final prompt = closePrompt;
    if (action == CloseAction.ask && prompt != null) {
      _prompting = true;
      try {
        // 从任务栏缩略图关闭时窗口可能是最小化的，先恢复才能看到弹窗。
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
        // 取消：什么都不做。没有弹窗可用时走到这里也保持窗口。
        break;
    }
  }

  static Future<void> bootstrap() async {
    if (!isDesktopWindow || _instance != null) {
      return;
    }
    final session = DesktopSession._();
    _instance = session;
    await session._init();
  }

  Future<void> _init() async {
    windowManager.addListener(this);
    await windowManager.setPreventClose(true);

    if (Platform.isWindows) {
      try {
        _launchAtStartup = LaunchAtStartup.isEnabled();
      } catch (e, st) {
        developer.log('读取开机自启动失败: $e', name: 'Desktop', stackTrace: st);
      }
    }

    try {
      trayManager.addListener(this);
      await trayManager.setIcon('assets/app_icon.ico');
      await trayManager.setToolTip(kAppTitle);
      await _refreshTrayMenu();
    } catch (e, st) {
      developer.log('初始化托盘失败: $e', name: 'Desktop', stackTrace: st);
    }
  }

  Future<void> hideToTray() async {
    if (_quitting) {
      return;
    }
    await windowManager.hide();
    await windowManager.setSkipTaskbar(true);
  }

  Future<void> showWindow() async {
    await windowManager.setSkipTaskbar(false);
    await windowManager.show();
    if (await windowManager.isMinimized()) {
      await windowManager.restore();
    }
    await windowManager.focus();
  }

  Future<void> setLaunchAtStartup(bool enabled) async {
    try {
      LaunchAtStartup.setEnabled(enabled);
      _launchAtStartup = LaunchAtStartup.isEnabled();
    } catch (e, st) {
      developer.log('设置开机自启动失败: $e', name: 'Desktop', stackTrace: st);
      rethrow;
    }
    notifyListeners();
    await _refreshTrayMenu();
  }

  Future<void> quit() async {
    if (_quitting) {
      return;
    }
    _quitting = true;
    try {
      await onQuit?.call();
      await ShellSettings.instance.flush();
    } catch (e, st) {
      developer.log('停止服务失败: $e', name: 'Desktop', stackTrace: st);
    }
    try {
      trayManager.removeListener(this);
      await trayManager.destroy();
    } catch (_) {}
    windowManager.removeListener(this);
    await windowManager.setPreventClose(false);
    await windowManager.setSkipTaskbar(false);
    await windowManager.close();
  }

  Future<void> _refreshTrayMenu() async {
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'show', label: '显示主窗口'),
          MenuItem.checkbox(
            key: 'autostart',
            label: '开机自启动',
            checked: _launchAtStartup,
          ),
          MenuItem.separator(),
          MenuItem(key: 'quit', label: '退出'),
        ],
      ),
    );
  }

  @override
  void onWindowClose() {
    if (_quitting) {
      return;
    }
    unawaited(requestClose());
  }

  @override
  void onTrayIconMouseDown() {
    unawaited(showWindow());
  }

  @override
  void onTrayIconRightMouseDown() {
    unawaited(trayManager.popUpContextMenu());
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        unawaited(showWindow());
      case 'autostart':
        unawaited(setLaunchAtStartup(!_launchAtStartup));
      case 'quit':
        unawaited(quit());
    }
  }
}
