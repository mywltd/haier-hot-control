import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';

import 'ff_title_bar_header.dart';
import 'ff_tokens.dart';

/// 窗口居中的 Store 式搜索标题栏。窗口按钮、拖动与导航由应用注入。
///
/// 继承 TitleBar 以便 NavigationView 正确预留 48px 高度；内部自行分配
/// 品牌、搜索和按钮宽度，避免上游固定的 2:1:2 比例把输入框挤窄。
class FfSearchTitleBar extends TitleBar {
  const FfSearchTitleBar({
    super.key,
    required this.appIcon,
    required this.appTitle,
    required this.search,
    required Widget super.captionControls,
    this.onBack,
    this.active = true,
    this.captionWidth = 138,
    this.compactWidth = 1000,
    super.onDragStarted,
    super.onDoubleTap,
  }) : super(height: 48, isBackButtonVisible: false);

  final Widget appIcon;
  final String appTitle;
  final Widget search;
  final VoidCallback? onBack;
  final bool active;
  final double captionWidth;
  final double compactWidth;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final titleStyle = theme.typography.body?.copyWith(
      color: active
          ? theme.resources.textFillColorPrimary
          : theme.resources.textFillColorTertiary,
    );
    final painter = TextPainter(
      text: TextSpan(text: appTitle, style: titleStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final titleExtent = painter.width + 12;
    painter.dispose();

    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 48,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            // 窄窗增加搜索占比，大屏限制绝对宽度；右侧保留可拖动的留白。
            final fraction = ((width - 800) / 600).clamp(0.0, 1.0);
            final preferred = math.min(640.0, width * (.62 - .12 * fraction));
            final right = math.max(0.0, width - captionWidth - 48);
            final targetStart = 26 + (onBack == null ? 0 : 40) + 20.0;
            final showTitle =
                width >= compactWidth &&
                (width - preferred) / 2 >= targetStart + titleExtent + 24;
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: onBack == null ? 0 : 1),
              duration: FfTokens.duration(context, FfTokens.navigation),
              curve: FfTokens.navigationCurve,
              builder: (context, backProgress, _) => TweenAnimationBuilder<double>(
                tween: Tween(end: showTitle ? 1 : 0),
                duration: FfTokens.duration(context, FfTokens.standard),
                curve: FfTokens.curve,
                builder: (context, titleProgress, _) {
                  final iconEnd = 46 + 40 * backProgress;
                  // 缩窗可一帧跳过多个断点，按当前边界裁剪标题，而不等待动画收完。
                  final titleRoom = math.max(0.0, right - iconEnd - 24 - 180);
                  final titleWidth = math.min(
                    titleExtent * titleProgress,
                    titleRoom,
                  );
                  final left = iconEnd + titleWidth + 24;
                  final searchWidth = math.min(
                    preferred,
                    math.max(0.0, right - left),
                  );
                  final searchStart = ((width - searchWidth) / 2).clamp(
                    left,
                    math.max(left, right - searchWidth),
                  );
                  return Stack(
                    children: [
                      // 拖窗区域作为兄弟节点，搜索与窗口按钮无需等待双击判定。
                      Positioned.fill(
                        child: _dragRegion(const SizedBox.expand()),
                      ),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: FfTitleBarHeader(
                          onBack: onBack,
                          animationProgress: backProgress,
                          child: _dragRegion(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Tooltip(
                                  message: appTitle,
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: appIcon,
                                  ),
                                ),
                                ClipRect(
                                  child: SizedBox(
                                    key: const Key('titlebar-title'),
                                    width: titleWidth,
                                    child: OverflowBox(
                                      alignment:
                                          AlignmentDirectional.centerStart,
                                      minWidth: titleExtent,
                                      maxWidth: titleExtent,
                                      child: ExcludeSemantics(
                                        excluding: !showTitle,
                                        child: Opacity(
                                          opacity: const Interval(
                                            .45,
                                            1,
                                            curve: Curves.easeOut,
                                          ).transform(titleProgress),
                                          child: Padding(
                                            padding:
                                                const EdgeInsetsDirectional.only(
                                                  start: 12,
                                                ),
                                            child: Text(
                                              appTitle,
                                              maxLines: 1,
                                              style: titleStyle,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      PositionedDirectional(
                        start: searchStart.toDouble(),
                        width: searchWidth,
                        top: 8,
                        height: 32,
                        child: search,
                      ),
                      PositionedDirectional(
                        end: 0,
                        top: 0,
                        width: captionWidth,
                        height: 32,
                        child: captionControls!,
                      ),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _dragRegion(Widget child) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onPanStart: onDragStarted == null ? null : (_) => onDragStarted!(),
    onDoubleTap: onDoubleTap,
    child: child,
  );
}
