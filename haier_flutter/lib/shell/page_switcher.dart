import 'package:fluent_ui/fluent_ui.dart';

/// 侧栏切页的过渡（Fluent「页面刷新」）：
/// 旧页 120ms 快速淡出；新页稍后淡入，同时从下方 40px 以强减速曲线滑到原位。
/// 两页只有极短的重叠，不会叠字，也不会中途闪白。
class PageSwitcher extends StatelessWidget {
  const PageSwitcher({super.key, required this.pageKey, required this.child});

  /// 页面标识，变化时播放过渡。
  final Object pageKey;
  final Widget child;

  static const _enter = Duration(milliseconds: 380);
  static const _exit = Duration(milliseconds: 120);

  /// Fluent 2 的 Decelerate Max：起步快、长时间柔和减速。
  static const _decelerate = Cubic(0.1, 0.9, 0.2, 1);
  static const _fadeIn = Interval(0.15, 0.6, curve: Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: reduceMotion ? Duration.zero : _enter,
      reverseDuration: reduceMotion ? Duration.zero : _exit,
      // 只用线性时间，曲线在 _transition 里按进 / 出分别处理。
      switchInCurve: Curves.linear,
      switchOutCurve: Curves.linear,
      layoutBuilder: _layout,
      transitionBuilder: _transition,
      child: _OwnScroll(key: ValueKey(pageKey), child: child),
    );
  }

  static Widget _layout(Widget? current, List<Widget> previous) {
    // 必须铺满：页面里的 ScaffoldPage 需要紧约束。
    return Stack(fit: StackFit.expand, children: [...previous, ?current]);
  }

  static Widget _transition(Widget child, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final t = animation.value;
        final leaving =
            animation.status == AnimationStatus.reverse ||
            animation.status == AnimationStatus.dismissed;
        final dy = leaving ? 0.0 : 40 * (1 - _decelerate.transform(t));
        // 树结构保持不变，页面从「进入」变成「离开」时状态不丢。
        return IgnorePointer(
          ignoring: leaving,
          child: ExcludeFocus(
            excluding: leaving,
            child: Opacity(
              opacity: _fadeIn.transform(t),
              child: Transform.translate(offset: Offset(0, dy), child: child),
            ),
          ),
        );
      },
    );
  }
}

/// 每个页面一个独立的 PrimaryScrollController。
///
/// 过渡时新旧两页同时在树上；共用同一个控制器会让 Fluent 的常显滚动条报
/// 「attached to more than one ScrollPosition」。
class _OwnScroll extends StatefulWidget {
  const _OwnScroll({super.key, required this.child});

  final Widget child;

  @override
  State<_OwnScroll> createState() => _OwnScrollState();
}

class _OwnScrollState extends State<_OwnScroll> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PrimaryScrollController(
      controller: _controller,
      automaticallyInheritForPlatforms: TargetPlatform.values.toSet(),
      child: widget.child,
    );
  }
}
