import 'package:fluent_ui/fluent_ui.dart';
import 'package:window_manager/window_manager.dart' as native;

import 'desktop_window.dart';

/// 只改变自绘标题的文字；窗口材质的激活状态交给 DWM。
class WindowActivity extends ChangeNotifier {
  WindowActivity() {
    _listener = maybeDesktopWindow?.addListener((event) {
      if (event is native.WindowFocusedEvent) active = true;
      if (event is native.WindowBlurredEvent) active = false;
    });
  }

  native.ListenerId? _listener;
  bool _active = true;
  bool get active => _active;
  set active(bool value) {
    if (_active == value) return;
    _active = value;
    notifyListeners();
  }

  @override
  void dispose() {
    final listener = _listener;
    if (listener != null) maybeDesktopWindow?.removeListener(listener);
    super.dispose();
  }
}

class WindowActivityScope extends InheritedNotifier<WindowActivity> {
  const WindowActivityScope({
    super.key,
    required WindowActivity super.notifier,
    required super.child,
  });
  static bool activeOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<WindowActivityScope>()
          ?.notifier
          ?.active ??
      true;
}
