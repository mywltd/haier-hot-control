import 'dart:ui' as ui;

import 'package:fluent_ui/fluent_ui.dart';

// 下拉列表与浮动菜单共用材质，避免各自修复后再次出现不同的合成顺序。
class PopupSurface extends StatelessWidget {
  const PopupSurface({
    super.key,
    required this.child,
    required this.borderRadius,
    this.tint,
    this.tintOpacity,
    this.luminosityOpacity,
    this.blendMode = BlendMode.srcOver,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final Color? tint;
  final double? tintOpacity;
  final double? luminosityOpacity;
  final BlendMode blendMode;

  static final _blur = ui.ImageFilter.blur(
    sigmaX: kBlurAmount,
    sigmaY: kBlurAmount,
  );

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final enabled = DisableAcrylic.of(context) == null;
    final color = tint ?? theme.acrylicBackgroundColor;
    final tintOpacity =
        this.tintOpacity ?? (tint == null ? theme.acrylicTintOpacity : 1.0);
    final luminosityOpacity =
        this.luminosityOpacity ?? theme.acrylicLuminosityOpacity;
    return ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: enabled
                ? BackdropFilter(
                    filter: _blur,
                    blendMode: blendMode,
                    child: const SizedBox.expand(),
                  )
                : ColoredBox(
                    color:
                        tint?.withValues(alpha: 1) ??
                        theme.acrylicFallbackColor,
                  ),
          ),
          if (enabled) ...[
            Positioned.fill(
              child: CustomPaint(
                painter: _PopupAcrylic(
                  AcrylicHelper.getLuminosityColor(
                    color,
                    luminosityOpacity,
                    tintOpacity,
                  ),
                  AcrylicHelper.getEffectiveTintColor(
                    color,
                    tintOpacity,
                    luminosityOpacity: luminosityOpacity,
                  ),
                ),
              ),
            ),
            const Positioned.fill(
              child: Opacity(
                opacity: 0.02,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage(
                        'assets/AcrylicNoise.png',
                        package: 'fluent_ui',
                      ),
                      repeat: ImageRepeat.repeat,
                      alignment: AlignmentDirectional.topStart,
                    ),
                  ),
                ),
              ),
            ),
          ],
          DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              border: Border.all(
                color: theme.resources.surfaceStrokeColorFlyout,
              ),
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

// 与材质分开包装，让下拉展开裁剪只影响内容，外部投影仍保持完整。
class PopupShadow extends StatelessWidget {
  const PopupShadow({
    super.key,
    required this.child,
    required this.borderRadius,
    this.elevation = 8,
  }) : assert(elevation >= 0);

  final Widget child;
  final BorderRadius borderRadius;
  final double elevation;

  @override
  Widget build(BuildContext context) => CustomPaint(
    // 模糊先采样，最后才画外部阴影，连面板边缘也不会采到自己的投影。
    foregroundPainter: _PopupShadowPainter(
      FluentTheme.of(context).shadowColor,
      borderRadius,
      elevation,
    ),
    child: child,
  );
}

class _PopupAcrylic extends CustomPainter {
  const _PopupAcrylic(this.luminosity, this.tint);

  final Color luminosity;
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(luminosity, BlendMode.luminosity);
    canvas.drawColor(tint, tint.a >= 1 ? BlendMode.src : BlendMode.color);
  }

  @override
  bool shouldRepaint(_PopupAcrylic oldDelegate) =>
      luminosity != oldDelegate.luminosity || tint != oldDelegate.tint;
}

class _PopupShadowPainter extends CustomPainter {
  const _PopupShadowPainter(this.color, this.borderRadius, this.elevation);

  final Color color;
  final BorderRadius borderRadius;
  final double elevation;

  @override
  void paint(Canvas canvas, Size size) {
    if (elevation == 0) return;
    final rect = Offset.zero & size;
    final shape = Path()..addRRect(borderRadius.toRRect(rect));
    // 透明面板的 drawShadow 会覆盖内部；裁掉内部才能保留正确的材质亮度。
    canvas.save();
    canvas.clipPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(rect.inflate(elevation * 10)),
        shape,
      ),
    );
    canvas.drawShadow(shape, color, elevation, true);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PopupShadowPainter oldDelegate) =>
      color != oldDelegate.color ||
      borderRadius != oldDelegate.borderRadius ||
      elevation != oldDelegate.elevation;
}
