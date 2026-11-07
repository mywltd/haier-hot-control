import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// 放在应用 builder 中，统一退出页面与弹出层里的键盘焦点。
///
/// 指针按下或滚动时释放普通控件，输入框的点击、选字及点击外部行为
/// 仍由 EditableText 处理。Esc 只在控件、菜单和弹窗均未处理时兜底。
class FfFocusDismissal extends StatefulWidget {
  const FfFocusDismissal({super.key, required this.child});

  final Widget child;

  @override
  State<FfFocusDismissal> createState() => _FfFocusDismissalState();
}

class _FfFocusDismissalState extends State<FfFocusDismissal> {
  final _boundary = FocusNode(
    debugLabel: 'FfFocusDismissal',
    canRequestFocus: false,
    skipTraversal: true,
  );

  @override
  void initState() {
    super.initState();
    // 普通 Focus.onKeyEvent 会先于应用级 Shortcuts 收到 Esc，抢走弹窗关闭。
    FocusManager.instance.addLateKeyEventHandler(_onUnhandledKey);
  }

  @override
  void dispose() {
    FocusManager.instance.removeLateKeyEventHandler(_onUnhandledKey);
    _boundary.dispose();
    super.dispose();
  }

  FocusNode? get _focusedControl {
    if (!_boundary.hasFocus) return null;
    final focus = FocusManager.instance.primaryFocus;
    // 留在当前作用域，下一次 Tab 仍能遍历，也不会跳出模态弹窗。
    return focus is FocusScopeNode ? null : focus;
  }

  KeyEventResult _onUnhandledKey(KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape) {
      return KeyEventResult.ignored;
    }
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isAltPressed ||
        keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        keyboard.isShiftPressed) {
      return KeyEventResult.ignored;
    }
    final focus = _focusedControl;
    if (focus == null) return KeyEventResult.ignored;
    focus.unfocus();
    return KeyEventResult.handled;
  }

  void _onPointerInteraction(PointerEvent event) {
    final focus = _focusedControl;
    final context = focus?.context;
    if (context == null) return;
    // 不能先清空编辑焦点再重新聚焦，否则鼠标定位、拖选及输入法状态会被打断。
    if (context.widget is EditableText ||
        context.findAncestorStateOfType<EditableTextState>() != null) {
      return;
    }
    focus!.unfocus();
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: _onPointerInteraction,
    onPointerSignal: (event) {
      if (event is PointerScrollEvent) _onPointerInteraction(event);
    },
    onPointerPanZoomStart: _onPointerInteraction,
    child: Focus(
      focusNode: _boundary,
      includeSemantics: false,
      child: widget.child,
    ),
  );
}
