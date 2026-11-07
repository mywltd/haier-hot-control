import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';

import 'ff_tokens.dart';
import 'popup_surface.dart';

@immutable
class FfSearchItem<T> {
  const FfSearchItem({
    required this.value,
    required this.label,
    this.description = '',
    this.keywords = const [],
    this.icon = FluentIcons.search,
  });

  final T value;
  final String label;
  final String description;
  final List<String> keywords;
  final IconData icon;

  bool matches(String query) {
    final haystack = '$label $description ${keywords.join(' ')}'.toLowerCase();
    return query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .every(haystack.contains);
  }
}

/// 文案由宿主提供，组件不绑定样例页面或应用语言。
@immutable
class FfSearchLabels {
  const FfSearchLabels({
    required this.placeholder,
    required this.history,
    required this.suggestions,
    required this.results,
    required this.noResults,
    required this.clearHistory,
    required this.removeHistory,
    required this.clearText,
    required this.submit,
  });

  final String placeholder;
  final String history;
  final String suggestions;
  final String results;
  final String noResults;
  final String clearHistory;
  final String removeHistory;
  final String clearText;
  final String submit;
}

/// 可输入、键盘选择的搜索建议与历史；存储和导航由宿主回调负责。
class FfSearchBox<T> extends StatefulWidget {
  const FfSearchBox({
    super.key,
    required this.items,
    required this.labels,
    required this.onSelected,
    required this.history,
    required this.onHistoryAdded,
    required this.onHistoryRemoved,
    required this.onHistoryCleared,
    this.focusNode,
  });

  final List<FfSearchItem<T>> items;
  final FfSearchLabels labels;
  final ValueChanged<FfSearchItem<T>> onSelected;
  final List<String> history;
  final ValueChanged<String> onHistoryAdded;
  final ValueChanged<String> onHistoryRemoved;
  final VoidCallback onHistoryCleared;
  final FocusNode? focusNode;

  @override
  State<FfSearchBox<T>> createState() => _FfSearchBoxState<T>();
}

class _FfSearchBoxState<T> extends State<FfSearchBox<T>> {
  final _controller = TextEditingController();
  final _fallbackFocus = FocusNode();
  final _group = FocusNode(canRequestFocus: false);
  final _portal = OverlayPortalController();
  final _link = LayerLink();
  final _scroll = ScrollController();
  final _rowKeys = <int, GlobalKey>{};
  bool _open = false;
  int _selected = -1;

  FocusNode get _focus => widget.focusNode ?? _fallbackFocus;
  String get _query => _controller.text.trim();
  bool get _historyVisible => _query.isEmpty && widget.history.isNotEmpty;
  List<FfSearchItem<T>> get _matches =>
      widget.items.where((item) => item.matches(_query)).take(8).toList();
  int get _count =>
      _historyVisible ? math.min(8, widget.history.length) : _matches.length;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
    _controller.addListener(_onText);
  }

  @override
  void didUpdateWidget(covariant FfSearchBox<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      (oldWidget.focusNode ?? _fallbackFocus).removeListener(_onFocus);
      _focus.addListener(_onFocus);
    }
    if (_selected >= _count) _selected = _count - 1;
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _fallbackFocus.dispose();
    _controller.dispose();
    _group.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (_focus.hasFocus) _show();
  }

  void _onText() {
    setState(() => _selected = -1);
    if (_focus.hasFocus) _show();
  }

  void _show() {
    if (!_open) setState(() => _open = true);
    _portal.show();
  }

  void _dismiss({bool unfocus = false}) {
    if (_open) setState(() => _open = false);
    if (unfocus) _group.unfocus();
  }

  void _choose(FfSearchItem<T> item) {
    widget.onHistoryAdded(_query.isEmpty ? item.label : _query);
    _dismiss(unfocus: true);
    widget.onSelected(item);
  }

  void _recall(String query) {
    _controller.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    _focus.requestFocus();
    _show();
  }

  void _submit() {
    // Enter 确认中文候选时不能同时触发页面跳转。
    if (!_controller.value.composing.isCollapsed) return;
    if (_historyVisible && _selected >= 0) {
      _recall(widget.history[_selected]);
      return;
    }
    final matches = _matches;
    if (matches.isNotEmpty && (_query.isNotEmpty || _selected >= 0)) {
      _choose(matches[_selected < 0 ? 0 : _selected]);
    } else {
      if (_query.isNotEmpty) widget.onHistoryAdded(_query);
      _focus.requestFocus();
      _show();
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (!_controller.value.composing.isCollapsed) return KeyEventResult.ignored;
    if (_focus.hasFocus &&
        (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
      if (event is KeyDownEvent) _submit();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_open) {
        _dismiss();
      } else {
        _group.unfocus();
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.tab) {
      _dismiss();
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
        event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _show();
      final count = _count;
      if (count == 0) return KeyEventResult.handled;
      final down = event.logicalKey == LogicalKeyboardKey.arrowDown;
      setState(
        () => _selected = _selected < 0
            ? (down ? 0 : count - 1)
            : (_selected + (down ? 1 : -1)) % count,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_open) return;
        final row = _rowKeys[_selected]?.currentContext;
        if (row != null) {
          Scrollable.ensureVisible(
            row,
            duration: FfTokens.duration(context, FfTokens.fast),
            alignment: .5,
          );
        }
      });
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _iconButton(String label, IconData icon, VoidCallback action) =>
      Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: IconButton(
          onPressed: action,
          icon: Semantics(label: label, child: Icon(icon, size: 14)),
        ),
      );

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: _group,
    onKeyEvent: _onKey,
    onFocusChange: (focused) {
      if (!focused) _dismiss();
    },
    child: LayoutBuilder(
      builder: (context, constraints) => OverlayPortal(
        controller: _portal,
        overlayChildBuilder: (context) => Positioned(
          left: 0,
          top: 0,
          width: constraints.maxWidth,
          child: CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomLeft,
            followerAnchor: Alignment.topLeft,
            offset: const Offset(0, 4),
            child: TapRegion(
              groupId: this,
              child: TextFieldTapRegion(child: _popup(context)),
            ),
          ),
        ),
        child: CompositedTransformTarget(
          link: _link,
          child: TapRegion(
            groupId: this,
            onTapOutside: (_) => _dismiss(unfocus: true),
            child: TextBox(
              key: const Key('titlebar-search-input'),
              controller: _controller,
              focusNode: _focus,
              placeholder: widget.labels.placeholder,
              onTap: _show,
              onTapOutside: (_) {},
              onSubmitted: (_) => _submit(),
              textInputAction: TextInputAction.search,
              padding: const EdgeInsetsDirectional.only(
                start: 12,
                end: 4,
                top: 5,
                bottom: 5,
              ),
              suffix: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_controller.text.isNotEmpty)
                    _iconButton(
                      widget.labels.clearText,
                      FluentIcons.cancel,
                      () {
                        _controller.clear();
                        _focus.requestFocus();
                      },
                    ),
                  _iconButton(
                    widget.labels.submit,
                    FluentIcons.search,
                    _submit,
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _popup(BuildContext context) {
    final theme = FluentTheme.of(context);
    final labels = widget.labels;
    final history = _historyVisible;
    final matches = _matches;
    final count = history ? math.min(8, widget.history.length) : matches.length;
    const radius = BorderRadius.all(Radius.circular(8));
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: _open ? 1 : 0),
      duration: FfTokens.duration(context, FfTokens.fast),
      curve: FfTokens.curve,
      onEnd: () {
        // 减少动画时 onEnd 会在布局中同步触发，移除 Overlay 要等本帧结束。
        if (_open) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_open) _portal.hide();
        });
      },
      builder: (context, progress, child) => IgnorePointer(
        ignoring: !_open,
        child: ExcludeFocus(
          excluding: !_open,
          child: ExcludeSemantics(
            excluding: !_open,
            child: Opacity(
              opacity: progress,
              child: PopupShadow(
                borderRadius: radius,
                child: ClipRect(
                  child: Align(
                    alignment: Alignment.topCenter,
                    heightFactor: progress,
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      child: PopupSurface(
        key: const Key('titlebar-search-popup'),
        borderRadius: radius,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: math.max(
              80,
              math.min(416, MediaQuery.sizeOf(context).height - 64),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        history
                            ? labels.history
                            : (_query.isEmpty
                                  ? labels.suggestions
                                  : labels.results),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.caption?.copyWith(
                          color: theme.resources.textFillColorSecondary,
                        ),
                      ),
                    ),
                    if (history)
                      HyperlinkButton(
                        onPressed: widget.onHistoryCleared,
                        child: Text(
                          labels.clearHistory,
                          style: theme.typography.caption,
                        ),
                      ),
                  ],
                ),
              ),
              if (count == 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Text(labels.noResults, style: theme.typography.body),
                )
              else
                Flexible(
                  child: ListView.builder(
                    controller: _scroll,
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                    itemCount: count,
                    itemBuilder: (context, index) {
                      final query = history ? widget.history[index] : null;
                      final item = history ? null : matches[index];
                      return _row(
                        context,
                        index,
                        label: query ?? item!.label,
                        description: item?.description,
                        icon: history ? FluentIcons.history : item!.icon,
                        onPressed: () =>
                            history ? _recall(query!) : _choose(item!),
                        trailing: history
                            ? _iconButton(
                                '${labels.removeHistory} $query',
                                FluentIcons.cancel,
                                () => widget.onHistoryRemoved(query!),
                              )
                            : null,
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    int index, {
    required String label,
    required String? description,
    required IconData icon,
    required VoidCallback onPressed,
    Widget? trailing,
  }) {
    final theme = FluentTheme.of(context);
    final selected = index == _selected;
    return HoverButton(
      key: _rowKeys.putIfAbsent(index, GlobalKey.new),
      onPressed: onPressed,
      builder: (context, states) => Semantics(
        selected: selected,
        child: FocusBorder(
          focused: states.isFocused,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 8, 8),
            decoration: BoxDecoration(
              color: selected || states.isHovered
                  ? theme.resources.subtleFillColorSecondary
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: theme.resources.textFillColorSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (description != null && description.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.caption?.copyWith(
                            color: theme.resources.textFillColorSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
