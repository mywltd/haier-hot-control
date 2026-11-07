import 'package:fluent_ui/fluent_ui.dart';
import 'package:window_manager/window_manager.dart';

import 'window_bootstrap.dart';

/// 主窗口是否处于激活（前台）状态，自绘标题栏用它在失焦时把标题变灰。
///
/// 云母的激活 / 失焦切换由 DWM 自己做：window_manager 隐藏标题栏后会吞掉 WM_NCACTIVATE，
/// `windows/runner/flutter_window.cpp` 把它补交给 DefWindowProc。界面层不要再盖底色，
/// 否则一旦和 DWM 的状态对不上（比如从托盘恢复后），云母就被挡住。
class WindowActivity extends ChangeNotifier with WindowListener {
  WindowActivity() {
    if (isDesktopWindow) {
      windowManager.addListener(this);
    }
  }

  bool _active = true;

  bool get active => _active;

  set active(bool value) {
    if (_active == value) {
      return;
    }
    _active = value;
    notifyListeners();
  }

  @override
  void onWindowFocus() => active = true;

  @override
  void onWindowBlur() => active = false;

  @override
  void dispose() {
    if (isDesktopWindow) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }
}

class WindowActivityScope extends InheritedNotifier<WindowActivity> {
  const WindowActivityScope({
    super.key,
    required WindowActivity super.notifier,
    required super.child,
  });

  /// 不在作用域内时视为激活。
  static bool activeOf(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<WindowActivityScope>()
            ?.notifier
            ?.active ??
        true;
  }
}
