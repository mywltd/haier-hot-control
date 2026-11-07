import 'package:fluent_ui/fluent_ui.dart';

enum FfStatus { neutral, info, success, warning, error }

/// 图标与文字共同表达状态，让灰度显示和读屏也能识别。
class FfStatusBadge extends StatelessWidget {
  const FfStatusBadge({
    super.key,
    required this.label,
    this.status = FfStatus.neutral,
  });

  final String label;
  final FfStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final res = theme.resources;
    final (icon, color) = switch (status) {
      FfStatus.neutral => (FluentIcons.circle_ring, res.textFillColorSecondary),
      FfStatus.info => (
        FluentIcons.info,
        theme.accentColor.defaultBrushFor(theme.brightness),
      ),
      FfStatus.success => (FluentIcons.completed, res.systemFillColorSuccess),
      FfStatus.warning => (FluentIcons.warning, res.systemFillColorCaution),
      FfStatus.error => (FluentIcons.error_badge, res.systemFillColorCritical),
    };
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 6),
              Text(label, style: theme.typography.caption),
            ],
          ),
        ),
      ),
    );
  }
}
