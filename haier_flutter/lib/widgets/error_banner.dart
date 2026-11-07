import 'package:fluent_ui/fluent_ui.dart';

/// 页面顶部的错误条；[error] 为 null 时不占位，保持后续组件位置稳定。
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.title, required this.error});

  final String title;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final error = this.error;
    if (error == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InfoBar(
        title: Text(title),
        content: Text(error),
        severity: InfoBarSeverity.error,
      ),
    );
  }
}
