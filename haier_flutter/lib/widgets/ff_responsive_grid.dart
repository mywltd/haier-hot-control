import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';

import 'ff_tokens.dart';

/// 按可用宽度折行，避免桌面缩放或长文案被固定列宽挤出窗口。
class FfResponsiveGrid extends StatelessWidget {
  const FfResponsiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 280,
    this.maxColumns = 3,
    this.gap = FfTokens.itemGap,
  }) : assert(minItemWidth > 0),
       assert(maxColumns > 0),
       assert(gap >= 0);

  final List<Widget> children;
  final double minItemWidth;
  final int maxColumns;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = math.max(
          1,
          math.min(
            maxColumns,
            ((constraints.maxWidth + gap) / (minItemWidth + gap)).floor(),
          ),
        );
        final width = math.max(
          0.0,
          (constraints.maxWidth - gap * (columns - 1)) / columns,
        );
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}
