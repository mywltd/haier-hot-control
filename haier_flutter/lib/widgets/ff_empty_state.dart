import 'package:fluent_ui/fluent_ui.dart';

class FfEmptyState extends StatelessWidget {
  const FfEmptyState({
    super.key,
    required this.title,
    required this.description,
    this.icon = FluentIcons.search,
    this.action,
  });

  final String title;
  final String description;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: theme.resources.textFillColorTertiary),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.typography.bodyStrong,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: theme.typography.caption,
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
