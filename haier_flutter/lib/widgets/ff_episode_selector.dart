import 'package:fluent_ui/fluent_ui.dart';

import 'ff_responsive_grid.dart';

/// 分集标识只用于选择；片源与播放行为由调用方按 ID 关联。
@immutable
class FfEpisode {
  const FfEpisode(this.id, this.title, this.duration);

  /// 同组内唯一且稳定，不使用可能随排序变化的下标。
  final Object id;
  final String title;
  final String duration;
}

@immutable
class FfEpisodeGroup {
  const FfEpisodeGroup(this.id, this.title, this.episodes);

  /// 同一选集器内唯一且稳定。
  final Object id;
  final String title;
  final List<FfEpisode> episodes;
}

@immutable
class FfEpisodeSelection {
  const FfEpisodeSelection(this.groupId, this.episodeId);

  final Object groupId;
  final Object episodeId;

  @override
  bool operator ==(Object other) =>
      other is FfEpisodeSelection &&
      other.groupId == groupId &&
      other.episodeId == episodeId;

  @override
  int get hashCode => Object.hash(groupId, episodeId);
}

/// 按分组浏览分集；浏览分组与选择分集是独立操作，避免切组时误触播放。
///
/// [selection] 由调用方持有；点击分集通过 [onSelected] 通知调用方。
/// 返回详情时可传回原选择；数据重排按 ID 匹配，失效的选择不高亮其他项。
/// 父级提供有限宽度，组件按宽度折行，不创建内部滚动区。
class FfEpisodeSelector extends StatefulWidget {
  const FfEpisodeSelector({
    super.key,
    required this.groups,
    this.selection,
    this.onSelected,
    this.emptyLabel = '暂无分集',
  });

  final List<FfEpisodeGroup> groups;
  final FfEpisodeSelection? selection;
  final ValueChanged<FfEpisodeSelection>? onSelected;
  final String emptyLabel;

  @override
  State<FfEpisodeSelector> createState() => _FfEpisodeSelectorState();
}

class _FfEpisodeSelectorState extends State<FfEpisodeSelector> {
  Object? _groupId;

  FfEpisodeGroup? get _selectionGroup => widget.groups
      .where(
        (group) =>
            group.id == widget.selection?.groupId &&
            group.episodes.any(
              (episode) => episode.id == widget.selection?.episodeId,
            ),
      )
      .firstOrNull;

  void _validateGroups() {
    assert(
      widget.groups.map((group) => group.id).toSet().length ==
          widget.groups.length,
      'FfEpisodeGroup.id 必须唯一',
    );
    assert(
      widget.groups.every(
        (group) =>
            group.episodes.map((episode) => episode.id).toSet().length ==
            group.episodes.length,
      ),
      '同组 FfEpisode.id 必须唯一',
    );
  }

  @override
  void initState() {
    super.initState();
    _validateGroups();
    _groupId = _selectionGroup?.id ?? widget.groups.firstOrNull?.id;
  }

  @override
  void didUpdateWidget(FfEpisodeSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    _validateGroups();
    final selectedGroup = _selectionGroup;
    if (oldWidget.selection != widget.selection && selectedGroup != null) {
      _groupId = selectedGroup.id;
    }
    if (!widget.groups.any((group) => group.id == _groupId)) {
      _groupId = selectedGroup?.id ?? widget.groups.firstOrNull?.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.groups.isEmpty) return const SizedBox.shrink();
    final group = widget.groups.firstWhere((group) => group.id == _groupId);
    final theme = FluentTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.groups.length > 1)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in widget.groups)
                Tooltip(
                  message: option.title,
                  excludeFromSemantics: true,
                  child: ToggleButton(
                    key: ValueKey(option.id),
                    checked: option.id == group.id,
                    onChanged: (_) => setState(() => _groupId = option.id),
                    child: Text(option.title),
                  ),
                ),
            ],
          )
        else
          Text(group.title, style: theme.typography.bodyStrong),
        const SizedBox(height: 16),
        if (group.episodes.isEmpty)
          Text(
            widget.emptyLabel,
            style: theme.typography.body?.copyWith(
              color: theme.resources.textFillColorSecondary,
            ),
          )
        else
          FfResponsiveGrid(
            minItemWidth: MediaQuery.textScalerOf(context).scale(160),
            maxColumns: 6,
            gap: 8,
            children: [
              for (final episode in group.episodes)
                _episodeTile(context, group, episode),
            ],
          ),
      ],
    );
  }

  Widget _episodeTile(
    BuildContext context,
    FfEpisodeGroup group,
    FfEpisode episode,
  ) {
    final value = FfEpisodeSelection(group.id, episode.id);
    final selected = widget.selection == value;
    return Tooltip(
      message: '${episode.title} · ${episode.duration}',
      excludeFromSemantics: true,
      child: MergeSemantics(
        child: Semantics(
          selected: selected,
          child: ToggleButton(
            key: ValueKey(value),
            checked: selected,
            onChanged: widget.onSelected == null
                ? null
                : (_) => widget.onSelected!(value),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          episode.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox.square(
                        dimension: 16,
                        child: selected
                            ? const Icon(FluentIcons.check_mark, size: 12)
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    episode.duration,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
