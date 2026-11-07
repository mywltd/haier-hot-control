import 'package:fluent_ui/fluent_ui.dart';

import 'ff_tokens.dart';

/// Store 式标题栏左侧：返回键出现时，图标与标题一起让位。
///
/// [onBack] 为 null 时收起返回键；[child] 通常为应用图标与标题组成的行。
/// 导航状态由外壳提供，组件不访问路由或原生窗口。
class FfTitleBarHeader extends StatelessWidget {
  const FfTitleBarHeader({
    super.key,
    required this.child,
    this.onBack,
    this.backTooltip,
    this.animationProgress,
  });

  final Widget child;
  final VoidCallback? onBack;
  final String? backTooltip;

  /// 外层同时调整搜索框时，共享返回动画进度，避免分别动画导致中间帧相撞。
  final double? animationProgress;

  @override
  Widget build(BuildContext context) {
    final visible = onBack != null;
    if (animationProgress case final progress?) {
      return _buildHeader(context, progress, child);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: visible ? 1 : 0),
      duration: FfTokens.duration(context, FfTokens.navigation),
      curve: FfTokens.navigationCurve,
      builder: _buildHeader,
      child: child,
    );
  }

  Widget _buildHeader(BuildContext context, double progress, Widget? child) {
    final visible = onBack != null;
    final tooltip =
        backTooltip ?? FluentLocalizations.of(context).backButtonTooltip;
    final rtl = Directionality.of(context) == TextDirection.rtl;

    // 共用一个进度，让快速进出内页也能从当前画面接续，不跳回动画起点。
    final interactive = visible && progress > 0.5;
    // 品牌区先让出空间再显箭头，归位时先淡出，避免两者在中间帧重叠。
    final opacity = const Interval(
      0.35,
      1,
      curve: Curves.easeOut,
    ).transform(progress);
    return SizedBox(
      height: 48,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: EdgeInsetsDirectional.only(start: 26 + 40 * progress),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: 1,
              child: child,
            ),
          ),
          if (progress > 0)
            PositionedDirectional(
              start: 20,
              top: 8,
              width: 32,
              height: 32,
              child: IgnorePointer(
                ignoring: !interactive,
                child: ExcludeFocus(
                  excluding: !interactive,
                  child: ExcludeSemantics(
                    excluding: !interactive,
                    child: Opacity(
                      opacity: opacity,
                      child: Transform.translate(
                        offset: Offset((rtl ? 8 : -8) * (1 - progress), 0),
                        child: Tooltip(
                          message: tooltip,
                          excludeFromSemantics: true,
                          child: Semantics(
                            label: tooltip,
                            child: IconButton(
                              // 退场时保留正常颜色；交互已由外层立即关闭。
                              onPressed: () => onBack?.call(),
                              icon: WindowsIcon(
                                rtl
                                    ? WindowsIcons.chrome_back_mirrored
                                    : WindowsIcons.chrome_back,
                                fallbackIcon: rtl
                                    ? FluentIcons.chrome_back_mirrored
                                    : FluentIcons.chrome_back,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
