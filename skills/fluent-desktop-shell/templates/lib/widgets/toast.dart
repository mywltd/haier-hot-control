import 'package:fluent_ui/fluent_ui.dart';

/// 页面内的轻量提示，可带一个操作按钮。
Future<void> showToast(
  BuildContext context,
  String message, {
  InfoBarSeverity severity = InfoBarSeverity.info,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  return displayInfoBar(
    context,
    builder: (context, close) {
      return InfoBar(
        title: Text(message),
        severity: severity,
        onClose: close,
        action: actionLabel == null
            ? null
            : Button(
                onPressed: () {
                  close();
                  onAction?.call();
                },
                child: Text(actionLabel),
              ),
      );
    },
  );
}
