import 'dart:ui' as ui;

import 'package:fluent_ui/fluent_ui.dart';

/// 图片表面随鼠标移动的柔和高光；文字和可读性遮罩放在 [foreground]。
class FfCarouselSpotlight extends StatefulWidget {
  const FfCarouselSpotlight({
    super.key,
    required this.child,
    this.foreground,
    this.enabled = true,
    this.intensity = 0.18,
    this.radius = 200,
  }) : assert(intensity >= 0 && intensity <= 1),
       assert(radius > 0 && radius < double.infinity);

  final Widget child;

  /// 覆盖图片的内容不受高光提亮，同时保留完整的指针命中路径。
  final Widget? foreground;
  final bool enabled;
  final double intensity;
  final double radius;

  @override
  State<FfCarouselSpotlight> createState() => _FfCarouselSpotlightState();
}

class _FfCarouselSpotlightState extends State<FfCarouselSpotlight> {
  final _position = ValueNotifier<Offset?>(null);

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled =
        widget.enabled &&
        !MediaQuery.disableAnimationsOf(context) &&
        !MediaQuery.highContrastOf(context);
    return MouseRegion(
      onEnter: (event) => _position.value = event.localPosition,
      onHover: (event) => _position.value = event.localPosition,
      onExit: (_) => _position.value = null,
      child: RepaintBoundary(
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            CustomPaint(
              foregroundPainter: _SpotlightPainter(
                position: _position,
                enabled: enabled,
                radius: widget.radius,
                intensity: widget.intensity,
              ),
              child: widget.child,
            ),
            if (widget.foreground != null)
              Positioned.fill(child: widget.foreground!),
          ],
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({
    required this.position,
    required this.enabled,
    required this.radius,
    required this.intensity,
  }) : super(repaint: position);

  // 鼠标移动只重绘表面，避免重复构建图片、文字和无障碍节点。
  final ValueNotifier<Offset?> position;
  final bool enabled;
  final double radius;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final center = position.value;
    if (!enabled || center == null || size.isEmpty || intensity == 0) return;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          radius,
          [
            Colors.white.withValues(alpha: intensity),
            Colors.white.withValues(alpha: intensity * 0.35),
            Colors.white.withValues(alpha: 0),
          ],
          const [0, 0.45, 1],
        ),
    );
  }

  @override
  bool hitTest(Offset position) => false;

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) =>
      oldDelegate.position != position ||
      oldDelegate.enabled != enabled ||
      oldDelegate.radius != radius ||
      oldDelegate.intensity != intensity;
}
