import 'package:fluent_ui/fluent_ui.dart';

import 'text_utils.dart';

/// 统计卡：标签（Caption 次要色）/ 数值（Subtitle）/ 说明（Body 次要色）。
///
/// 状态类数值传 [icon] + [iconColor]（取 systemFillColorSuccess / Caution / Neutral），
/// 不要只靠颜色表达状态。几张并排时用 Row + Expanded，间距 12。
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.caption,
    this.icon,
    this.fallbackIcon,
    this.iconColor,
  });

  final String label;
  final String value;
  final String caption;
  final IconData? icon;
  final IconData? fallbackIcon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final secondary = theme.resources.textFillColorSecondary;
    final shown = ellipsize(value);
    Widget valueText = Text(
      shown,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.typography.subtitle,
    );
    if (shown != value) {
      valueText = Tooltip(message: value, child: valueText);
    }
    return Card(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.typography.caption?.copyWith(color: secondary)),
          const SizedBox(height: 6),
          Row(
            children: [
              if (icon != null) ...[
                WindowsIcon(
                  icon!,
                  size: 18,
                  color: iconColor,
                  fallbackIcon: fallbackIcon,
                ),
                const SizedBox(width: 8),
              ],
              Flexible(child: valueText),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.body?.copyWith(color: secondary),
          ),
        ],
      ),
    );
  }
}
