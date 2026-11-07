import 'package:fluent_ui/fluent_ui.dart';

import 'ff_combo_box.dart';
import 'ff_empty_state.dart';
import 'ff_tokens.dart';
import 'text_utils.dart';

enum FfCommentSort { newest, popular }

/// 展示数据与操作状态由调用方提供；ID 在当前讨论区内唯一且稳定。
@immutable
class FfComment {
  const FfComment({
    required this.id,
    required this.author,
    required this.content,
    required this.timeLabel,
    this.likes = 0,
    this.liked = false,
    this.replyToAuthor,
  }) : assert(likes >= 0);

  final Object id;
  final String author;
  final String content;
  final String timeLabel;
  final int likes;
  final bool liked;
  final String? replyToAuthor;
}

/// 同一讨论串中的回复平铺，回复对象用作者名表达，避免逐层缩窄正文。
@immutable
class FfCommentThread {
  const FfCommentThread(this.comment, {this.replies = const []});

  final FfComment comment;
  final List<FfComment> replies;
}

/// 父级提供有限宽度和滚动区域；组件不持有业务数据或调用网络。
///
/// [threads] 按调用方给定的顺序显示，排序回调不修改原列表。
/// [controller] 归调用方所有，只有提交成功后才应由调用方清空草稿。
class FfCommentSection extends StatefulWidget {
  const FfCommentSection({
    super.key,
    required this.threads,
    required this.controller,
    this.sort = FfCommentSort.newest,
    this.onSortChanged,
    this.onLike,
    this.onReply,
    this.replyTo,
    this.onCancelReply,
    this.onSubmit,
    this.submitting = false,
    this.maxLength = 1000,
    this.description,
    this.notice,
  }) : assert(maxLength > 0);

  final List<FfCommentThread> threads;
  final TextEditingController controller;
  final FfCommentSort sort;
  final ValueChanged<FfCommentSort>? onSortChanged;
  final ValueChanged<Object>? onLike;
  final ValueChanged<Object>? onReply;
  final FfComment? replyTo;
  final VoidCallback? onCancelReply;
  final ValueChanged<String>? onSubmit;
  final bool submitting;
  final int maxLength;
  final String? description;
  final String? notice;

  @override
  State<FfCommentSection> createState() => _FfCommentSectionState();
}

class _FfCommentSectionState extends State<FfCommentSection> {
  final _expanded = <Object>{};
  final _composerKey = GlobalKey();
  final _focus = FocusNode();

  @override
  void didUpdateWidget(FfCommentSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldCounts = {
      for (final thread in oldWidget.threads)
        thread.comment.id: thread.replies.length,
    };
    final ids = widget.threads.map((thread) => thread.comment.id).toSet();
    _expanded.removeWhere((id) => !ids.contains(id));
    for (final thread in widget.threads) {
      final oldCount = oldCounts[thread.comment.id];
      if (oldCount != null && thread.replies.length > oldCount) {
        _expanded.add(thread.comment.id);
      }
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _reply(FfComment comment) {
    widget.onReply!(comment.id);
    // 先定位整块编辑区再聚焦，避免光标的自动滚动盖过回复对象。
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await Scrollable.ensureVisible(
        _composerKey.currentContext!,
        duration: FfTokens.duration(context, FfTokens.standard),
        curve: FfTokens.curve,
      );
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final count = widget.threads.fold<int>(
      0,
      (total, thread) => total + 1 + thread.replies.length,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 8,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('讨论区 ($count)', style: theme.typography.subtitle),
            InfoLabel(
              label: '评论排序',
              child: FfComboBox<FfCommentSort>(
                value: widget.sort,
                items: const [
                  ComboBoxItem(value: FfCommentSort.newest, child: Text('最新')),
                  ComboBoxItem(value: FfCommentSort.popular, child: Text('最热')),
                ],
                onChanged: widget.onSortChanged == null
                    ? null
                    : (value) {
                        if (value != null) widget.onSortChanged!(value);
                      },
              ),
            ),
          ],
        ),
        if (widget.description != null) ...[
          const SizedBox(height: 8),
          Text(widget.description!, style: theme.typography.caption),
        ],
        const SizedBox(height: 16),
        Column(
          key: _composerKey,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.replyTo != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Text('回复 '),
                    Expanded(child: NameText(widget.replyTo!.author)),
                    const SizedBox(width: 8),
                    Button(
                      onPressed: widget.submitting
                          ? null
                          : widget.onCancelReply,
                      child: const Text('取消回复'),
                    ),
                  ],
                ),
              ),
            InfoLabel(
              label: '评论内容',
              child: TextBox(
                controller: widget.controller,
                focusNode: _focus,
                placeholder: '说说你的看法…',
                minLines: 3,
                maxLines: 5,
                maxLength: widget.maxLength,
                enabled: widget.onSubmit != null && !widget.submitting,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: widget.controller,
                builder: (context, value, _) {
                  final text = value.text.trim();
                  final valid =
                      text.isNotEmpty &&
                      value.text.characters.length <= widget.maxLength &&
                      value.composing.isCollapsed;
                  return FilledButton(
                    onPressed:
                        valid && !widget.submitting && widget.onSubmit != null
                        ? () => widget.onSubmit!(text)
                        : null,
                    child: Text(
                      widget.submitting
                          ? '提交中…'
                          : widget.replyTo == null
                          ? '发表评论'
                          : '发表回复',
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        if (widget.notice != null) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(widget.notice!, style: theme.typography.caption),
          ),
        ],
        const SizedBox(height: 24),
        if (widget.threads.isEmpty)
          const FfEmptyState(
            title: '暂无评论',
            description: '分享你的第一条观影感受。',
            icon: FluentIcons.comment,
          ),
        for (final thread in widget.threads)
          Padding(
            key: ValueKey(thread.comment.id),
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _comment(thread.comment),
                  if (thread.replies.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Button(
                        onPressed: () => setState(() {
                          if (!_expanded.add(thread.comment.id)) {
                            _expanded.remove(thread.comment.id);
                          }
                        }),
                        child: Text(
                          '${_expanded.contains(thread.comment.id) ? '收起' : '展开'} ${thread.replies.length} 条回复',
                        ),
                      ),
                    ),
                    if (_expanded.contains(thread.comment.id))
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: 16),
                        child: Column(
                          children: [
                            for (final reply in thread.replies)
                              Padding(
                                key: ValueKey(reply.id),
                                padding: const EdgeInsets.only(top: 16),
                                child: _comment(reply),
                              ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _comment(FfComment comment) {
    final theme = FluentTheme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: theme.resources.subtleFillColorSecondary,
              shape: BoxShape.circle,
            ),
            child: const Icon(FluentIcons.contact, size: 16),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NameText(comment.author, style: theme.typography.bodyStrong),
              const SizedBox(height: 4),
              Text(
                comment.timeLabel,
                style: theme.typography.caption?.copyWith(
                  color: theme.resources.textFillColorSecondary,
                ),
              ),
              if (comment.replyToAuthor != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('回复 '),
                    Expanded(child: NameText(comment.replyToAuthor!)),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Text(
                comment.content,
                style: theme.typography.body?.copyWith(height: 1.6),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ToggleButton(
                    checked: comment.liked,
                    onChanged: widget.onLike == null
                        ? null
                        : (_) => widget.onLike!(comment.id),
                    child: Semantics(
                      label:
                          '${comment.liked ? '取消点赞' : '点赞'} ${comment.author}的评论，${comment.likes} 赞',
                      excludeSemantics: true,
                      child: Text(
                        '${comment.liked ? '已赞' : '赞'} ${comment.likes}',
                      ),
                    ),
                  ),
                  Button(
                    onPressed: widget.onReply == null || widget.submitting
                        ? null
                        : () => _reply(comment),
                    child: Semantics(
                      label: '回复 ${comment.author}的评论',
                      excludeSemantics: true,
                      child: const Text('回复'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
