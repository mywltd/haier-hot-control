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
      final decoration = InfoBarTheme.of(context).decoration?.call(severity);
      return InfoBar(
        title: Text(message),
        severity: severity,
        // 内联提示的半透明底色会透出浮层自身的阴影和后方控件。
        // 浮动的普通提示改用主题实心表面，保留描边、圆角与其他状态色。
        style: severity == InfoBarSeverity.info && decoration is BoxDecoration
            ? InfoBarThemeData(
                decoration: (_) => decoration.copyWith(
                  color: FluentTheme.of(context)
                      .resources
                      .systemFillColorSolidAttentionBackground,
                ),
              )
            : null,
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
