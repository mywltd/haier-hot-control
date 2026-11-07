import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';

import '../app/shell_settings.dart';

/// 点关闭按钮时询问：退出程序 / 最小化到托盘 / 取消（不关闭）。
///
/// 勾选「记住我的选择」后写入 [settings]，之后不再询问；可在设置页改回「每次询问」。
Future<CloseAction?> showClosePrompt(
  BuildContext context,
  ShellSettings settings,
) async {
  final result = await showDialog<(CloseAction, bool)>(
    context: context,
    builder: (context) => const _ClosePromptDialog(),
  );
  if (result == null) {
    return null;
  }
  final (action, remember) = result;
  if (remember) {
    unawaited(settings.setCloseAction(action));
  }
  return action;
}

class _ClosePromptDialog extends StatefulWidget {
  const _ClosePromptDialog();

  @override
  State<_ClosePromptDialog> createState() => _ClosePromptDialogState();
}

class _ClosePromptDialogState extends State<_ClosePromptDialog> {
  bool _remember = false;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return ContentDialog(
      // 三个按钮在默认 368 宽里太挤。
      constraints: const BoxConstraints(maxWidth: 440),
      title: const Text('关闭窗口'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('要退出程序，还是最小化到托盘继续运行？最小化后直播服务和展示页不会中断。'),
          const SizedBox(height: 16),
          Checkbox(
            checked: _remember,
            onChanged: (v) => setState(() => _remember = v ?? false),
            content: const Text('记住我的选择，不再询问'),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 28),
            child: Text(
              '之后可在「设置」页改回每次询问。',
              style: theme.typography.caption?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
            ),
          ),
        ],
      ),
      actions: [
        Button(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        Button(
          onPressed: () =>
              Navigator.pop(context, (CloseAction.exit, _remember)),
          child: const Text('退出程序'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, (CloseAction.tray, _remember)),
          child: const Text('最小化到托盘'),
        ),
      ],
    );
  }
}
