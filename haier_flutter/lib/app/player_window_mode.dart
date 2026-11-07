import 'dart:async';
import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:screen_retriever/screen_retriever.dart' as screens;
import 'package:window_manager/window_manager.dart' as native;

import 'desktop_window.dart';

enum PlayerWindowMode {
  normal,
  pageFullscreen,
  systemFullscreen,
  pictureInPicture,
}

/// 窗口边界可注入，组件测试不创建原生窗口或读取正式配置。
abstract interface class PlayerWindowAdapter {
  bool get available;
  bool get fullScreen;
  set fullScreen(bool value);
  bool get maximized;
  void maximize();
  void unmaximize();
  Rect get bounds;
  set bounds(Rect value);
  Size get minimumSize;
  set minimumSize(Size value);
  Size get maximumSize;
  set maximumSize(Size value);
  bool get alwaysOnTop;
  set alwaysOnTop(bool value);
  bool get maximizable;
  set maximizable(bool value);
  Rect get workArea;
  void startDragging();
}

class _DesktopPlayerWindow implements PlayerWindowAdapter {
  native.Window get window => desktopWindow;
  @override
  bool get available => maybeDesktopWindow != null;
  @override
  bool get fullScreen => window.isFullScreen;
  @override
  set fullScreen(bool value) => window.isFullScreen = value;
  @override
  bool get maximized => window.isMaximized;
  @override
  void maximize() => window.maximize();
  @override
  void unmaximize() => window.unmaximize();
  @override
  Rect get bounds => window.bounds.toRect();
  @override
  set bounds(Rect value) => window.bounds = value.toNative();
  @override
  Size get minimumSize => window.minimumSize.toSize();
  @override
  set minimumSize(Size value) => window.minimumSize = value.toNative();
  @override
  Size get maximumSize => window.maximumSize.toSize();
  @override
  set maximumSize(Size value) => window.maximumSize = value.toNative();
  @override
  bool get alwaysOnTop => window.isAlwaysOnTop;
  @override
  set alwaysOnTop(bool value) => window.isAlwaysOnTop = value;
  @override
  bool get maximizable => window.isMaximizable;
  @override
  set maximizable(bool value) => window.isMaximizable = value;
  @override
  void startDragging() => window.startDragging();

  @override
  Rect get workArea {
    final displays = screens.DisplayManager.instance.getAll();
    try {
      for (final display in displays) {
        final area = display.workArea.toRect();
        if (area.contains(bounds.center)) return area;
      }
      return displays.isEmpty ? bounds : displays.first.workArea.toRect();
    } finally {
      for (final display in displays) {
        display.dispose();
      }
    }
  }
}

typedef _PipRestore = ({
  Rect bounds,
  Size minimum,
  Size maximum,
  bool maximized,
  bool topmost,
  bool maximizable,
});

/// 模式互斥；原生操作完成后才更新界面，避免按钮显示成功而窗口没有变化。
class PlayerWindowController extends ChangeNotifier {
  PlayerWindowController({PlayerWindowAdapter? window})
    : _window = window ?? _DesktopPlayerWindow() {
    if (window == null) {
      _observedWindow = maybeDesktopWindow;
      _listener = _observedWindow?.addListener((event) {
        if (event is native.WindowExitedFullScreenEvent) {
          // 系统菜单也能退出全屏；离开原生回调栈后再核对，避免重入窗口线程。
          scheduleMicrotask(() {
            if (!_disposed &&
                _mode == PlayerWindowMode.systemFullscreen &&
                !_window.fullScreen) {
              _mode = PlayerWindowMode.normal;
              notifyListeners();
            }
          });
        }
      });
    }
  }

  final PlayerWindowAdapter _window;
  PlayerWindowMode _mode = PlayerWindowMode.normal;
  _PipRestore? _pipRestore;
  native.Window? _observedWindow;
  native.ListenerId? _listener;
  bool _disposed = false;
  String? error;

  PlayerWindowMode get mode => _mode;
  bool get immersive => _mode != PlayerWindowMode.normal;

  bool toggle(PlayerWindowMode target) =>
      setMode(_mode == target ? PlayerWindowMode.normal : target);

  bool setMode(PlayerWindowMode target) {
    if (_mode == target &&
        (target != PlayerWindowMode.normal || _pipRestore == null)) {
      return true;
    }
    error = null;
    try {
      if ((target == PlayerWindowMode.systemFullscreen ||
              target == PlayerWindowMode.pictureInPicture) &&
          !_window.available) {
        throw StateError('窗口尚未就绪');
      }
      _restoreNative();
      _mode = PlayerWindowMode.normal;
      if (target == PlayerWindowMode.systemFullscreen) {
        _window.fullScreen = true;
        if (!_window.fullScreen) throw StateError('系统未进入全屏');
      } else if (target == PlayerWindowMode.pictureInPicture) {
        _enterPip();
      }
      _mode = target;
    } catch (_) {
      // 失败的进入操作也可能已经改了部分属性，先恢复自己保存的状态。
      try {
        if (_pipRestore != null) _restorePip();
        if (_window.available && _window.fullScreen) _window.fullScreen = false;
        _mode = PlayerWindowMode.normal;
      } catch (_) {
        // 保留恢复快照，下次退出或销毁时还能重试。
      }
      error = '窗口模式切换失败，请重试。';
    }
    notifyListeners();
    return error == null;
  }

  void _enterPip() {
    final maximized = _window.maximized;
    // 必须先取得普通窗口的边界，否则从最大化进入小窗后会丢失还原尺寸。
    if (maximized) _window.unmaximize();
    _pipRestore = (
      bounds: _window.bounds,
      minimum: _window.minimumSize,
      maximum: _window.maximumSize,
      maximized: maximized,
      topmost: _window.alwaysOnTop,
      maximizable: _window.maximizable,
    );
    final work = _window.workArea.deflate(16);
    final width = math.min(480.0, work.width);
    final height = math.min(340.0, work.height);
    _window.minimumSize = Size(math.min(320, width), math.min(220, height));
    _window.maximumSize = Size.zero;
    _window.maximizable = false;
    _window.alwaysOnTop = true;
    _window.bounds = Rect.fromLTWH(
      work.right - width,
      work.bottom - height,
      width,
      height,
    );
    if (!_window.alwaysOnTop || _window.bounds.width > width + 2) {
      throw StateError('系统未应用小窗尺寸或置顶');
    }
  }

  void _restorePip() {
    final saved = _pipRestore;
    if (saved == null) return;
    _window.minimumSize = saved.minimum;
    _window.maximumSize = saved.maximum;
    _window.maximizable = saved.maximizable;
    _window.alwaysOnTop = saved.topmost;
    _window.bounds = saved.bounds;
    if (saved.maximized) _window.maximize();
    _pipRestore = null;
  }

  void _restoreNative() {
    if (_mode == PlayerWindowMode.systemFullscreen && _window.available) {
      _window.fullScreen = false;
      if (_window.fullScreen) throw StateError('系统未退出全屏');
    }
    _restorePip();
  }

  void startDragging() {
    if ((_mode == PlayerWindowMode.pictureInPicture ||
            _mode == PlayerWindowMode.pageFullscreen) &&
        _window.available) {
      _window.startDragging();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    final listener = _listener;
    if (listener != null) _observedWindow?.removeListener(listener);
    try {
      _restoreNative();
    } finally {
      super.dispose();
    }
  }
}

class PlayerWindowScope extends InheritedNotifier<PlayerWindowController> {
  const PlayerWindowScope({
    super.key,
    required PlayerWindowController controller,
    required super.child,
  }) : super(notifier: controller);

  static PlayerWindowController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PlayerWindowScope>()?.notifier;
}
