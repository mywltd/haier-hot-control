import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/gestures.dart';

/// 铺满可用宽度的懒加载海报网格。父级需要提供有限宽高。
///
/// [minItemWidth] 决定列数，余量均分给所有列，不设置最大内容宽度。
/// [captionExtent] 是 1 倍文字下的标题区高度，会随系统文字缩放。
class FfPosterGrid extends StatefulWidget {
  const FfPosterGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.controller,
    this.minItemWidth = 168,
    this.posterAspectRatio = 2 / 3,
    this.captionExtent = 68,
    this.gap = 16,
    this.padding = const EdgeInsets.all(24),
  }) : assert(itemCount >= 0),
       assert(minItemWidth > 0),
       assert(posterAspectRatio > 0),
       assert(captionExtent >= 0),
       assert(gap >= 0);

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final ScrollController? controller;
  final double minItemWidth;
  final double posterAspectRatio;
  final double captionExtent;
  final double gap;
  final EdgeInsets padding;

  @override
  State<FfPosterGrid> createState() => _FfPosterGridState();
}

class _FfPosterGridState extends State<FfPosterGrid>
    with WidgetsBindingObserver {
  final _ownedController = ScrollController();
  late final _entry = OverlayEntry(builder: _buildGrid);
  VoidCallback? _dismissActive;

  ScrollController get _controller => widget.controller ?? _ownedController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(FfPosterGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    _entry.markNeedsBuild();
  }

  @override
  void didChangeMetrics() => _dismissActive?.call();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _entry.remove();
    _entry.dispose();
    _ownedController.dispose();
    super.dispose();
  }

  void _activate(VoidCallback dismiss) {
    if (_dismissActive == dismiss) return;
    _dismissActive?.call();
    _dismissActive = dismiss;
  }

  void _release(VoidCallback dismiss) {
    if (_dismissActive == dismiss) _dismissActive = null;
  }

  Rect _boundsIn(RenderBox ancestor) {
    final box = context.findRenderObject()! as RenderBox;
    return box.localToGlobal(Offset.zero, ancestor: ancestor) & box.size;
  }

  Widget _buildGrid(BuildContext context) => PosterGridScope(
    activate: _activate,
    release: _release,
    boundsIn: _boundsIn,
    scroll: (event) {
      // 展开卡片遮住了底层 Scrollable，滚轮仍应滚动原来的影库。
      GestureBinding.instance.pointerSignalResolver.register(event, (_) {
        _dismissActive?.call();
        if (_controller.hasClients) {
          _controller.position.pointerScroll(event.scrollDelta.dy);
        }
      });
    },
    child: NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification) _dismissActive?.call();
        return false;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = math.max(
            0.0,
            constraints.maxWidth - widget.padding.horizontal,
          );
          final columns = math.max(
            1,
            ((width + widget.gap) / (widget.minItemWidth + widget.gap)).floor(),
          );
          final itemWidth = math.max(
            0.0,
            (width - widget.gap * (columns - 1)) / columns,
          );
          return GridView.builder(
            controller: _controller,
            primary: false,
            padding: widget.padding,
            itemCount: widget.itemCount,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: widget.gap,
              mainAxisSpacing: widget.gap,
              mainAxisExtent:
                  itemWidth / widget.posterAspectRatio +
                  MediaQuery.textScalerOf(context).scale(widget.captionExtent),
            ),
            itemBuilder: widget.itemBuilder,
          );
        },
      ),
    ),
  );

  @override
  Widget build(BuildContext context) =>
      Overlay(clipBehavior: Clip.hardEdge, initialEntries: [_entry]);
}

/// 网格内部协调预览与滚动；不导出到公共入口。
class PosterGridScope extends InheritedWidget {
  const PosterGridScope({
    super.key,
    required this.activate,
    required this.release,
    required this.boundsIn,
    required this.scroll,
    required super.child,
  });

  final ValueChanged<VoidCallback> activate;
  final ValueChanged<VoidCallback> release;
  final Rect Function(RenderBox ancestor) boundsIn;
  final ValueChanged<PointerScrollEvent> scroll;

  static PosterGridScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PosterGridScope>();

  @override
  bool updateShouldNotify(PosterGridScope oldWidget) =>
      activate != oldWidget.activate ||
      release != oldWidget.release ||
      boundsIn != oldWidget.boundsIn ||
      scroll != oldWidget.scroll;
}
