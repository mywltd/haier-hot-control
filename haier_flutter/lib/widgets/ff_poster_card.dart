import 'dart:async';
import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import 'ff_poster_grid.dart';
import 'ff_tokens.dart';

/// 竖版封面与名称，悬停或键盘聚焦时展开。导航由调用方处理。
///
/// 图片构建器只放图片，标题和读屏标签由组件统一提供；预览图片可另传横向裁切。
/// [previewBuilder] 用于评分、简介等只读内容，整个展开面仍是同一个点击目标。
/// 在 [FfPosterGrid] 中可向上浮出网格，左右仍避让内容区边缘，并协调单一预览及滚轮。
class FfPosterCard extends StatefulWidget {
  const FfPosterCard({
    super.key,
    required this.title,
    required this.imageBuilder,
    required this.previewBuilder,
    required this.onPressed,
    this.subtitle,
    this.previewImageBuilder,
    this.posterAspectRatio = 2 / 3,
    this.expandedWidth = 320,
    this.expandedHeight = 440,
    this.previewLift = 16,
    this.hoverDelay = const Duration(milliseconds: 300),
  }) : assert(posterAspectRatio > 0),
       assert(expandedWidth > 0),
       assert(expandedHeight > 0),
       assert(previewLift >= 0);

  final String title;
  final String? subtitle;
  final WidgetBuilder imageBuilder;
  final WidgetBuilder? previewImageBuilder;
  final WidgetBuilder previewBuilder;
  final VoidCallback? onPressed;
  final double posterAspectRatio;
  final double expandedWidth;
  final double expandedHeight;

  /// 预览相对原卡片的上浮距离，也用于预留网格上方的浮动空间。
  final double previewLift;
  final Duration hoverDelay;

  @override
  State<FfPosterCard> createState() => _FfPosterCardState();
}

class _FfPosterCardState extends State<FfPosterCard>
    with SingleTickerProviderStateMixin {
  OverlayEntry? _entry;
  final _focus = FocusNode(debugLabel: 'FfPosterCard');
  late final _animation = AnimationController(vsync: this)
    ..addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        _removePreview();
      }
    });
  Timer? _timer;
  PosterGridScope? _scope;
  bool _highlight = false;
  bool _hovered = false;
  bool _closing = false;
  bool _refreshScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scope = PosterGridScope.maybeOf(context);
    _animation.duration = FfTokens.duration(context, FfTokens.standard);
    _animation.reverseDuration = FfTokens.duration(context, FfTokens.fast);
    _schedulePreviewRefresh();
  }

  @override
  void didUpdateWidget(FfPosterCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedulePreviewRefresh();
    if (widget.onPressed == null) {
      _timer?.cancel();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _dismiss();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scope?.release(_dismiss);
    _removePreview();
    _animation.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _open() {
    _timer?.cancel();
    if (!mounted || widget.onPressed == null) return;
    _scope?.activate(_dismiss);
    _closing = false;
    if (_entry == null) {
      // 根浮层让突出网格的部分同时获得绘制和命中区域；只取消裁剪无法接收鼠标。
      final overlay = Overlay.of(context, rootOverlay: true);
      final overlayBox = overlay.context.findRenderObject()! as RenderBox;
      final box = context.findRenderObject()! as RenderBox;
      final anchor =
          box.localToGlobal(Offset.zero, ancestor: overlayBox) & box.size;
      final overlayBounds = Offset.zero & overlayBox.size;
      final gridBounds = _scope?.boundsIn(overlayBox) ?? overlayBounds;
      // 只给顶部增加浮动余量，左右和底部仍避开侧栏、滚动区外的其他内容。
      final bounds = Rect.fromLTRB(
        gridBounds.left,
        gridBounds.top - widget.previewLift,
        gridBounds.right,
        gridBounds.bottom,
      ).intersect(overlayBounds);
      // 每次展开固定锚点；滚动或改变窗口大小时关闭，避免浮层追着列表漂移。
      // 独立 OverlayEntry 不会把懒加载卡片的语义树挂到另一个绘制分支。
      _entry = OverlayEntry(
        builder: (_) => InheritedTheme.captureAll(
          context,
          _preview(context, anchor, bounds),
        ),
      );
      overlay.insert(_entry!);
    }
    _animation.forward();
    setState(() {});
  }

  void _dismiss() {
    _timer?.cancel();
    if (!mounted) return;
    _scope?.release(_dismiss);
    _closing = true;
    _animation.value = 0;
    _removePreview();
    setState(() {});
  }

  void _removePreview() {
    final entry = _entry;
    _entry = null;
    entry?.remove();
    entry?.dispose();
  }

  void _schedulePreviewRefresh() {
    if (_entry == null || _refreshScheduled) return;
    _refreshScheduled = true;
    // GridView 可能在布局期间更新卡片，兄弟浮层必须留到本帧之后刷新。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshScheduled = false;
      if (mounted) _entry?.markNeedsBuild();
    });
  }

  void _leave() {
    _hovered = false;
    _timer?.cancel();
    if (_focus.hasFocus) return;
    // 从原卡片进入展开区域时留一个交接窗口，避免边界反复开合。
    _timer = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      _closing = true;
      _scope?.release(_dismiss);
      _animation.reverse();
      setState(() {});
    });
  }

  void _enter({bool preview = false}) {
    _hovered = true;
    _timer?.cancel();
    if (widget.onPressed == null) return;
    // 尚未展开的悬浮也要参与协调，滚动时才能取消这次延迟打开。
    _scope?.activate(_dismiss);
    if (preview) {
      _open();
    } else {
      _timer = Timer(widget.hoverDelay, _open);
    }
  }

  void _activate() {
    _dismiss();
    widget.onPressed?.call();
  }

  Widget _caption(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.bodyStrong,
          ),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.caption?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _preview(BuildContext context, Rect anchor, Rect bounds) {
    final resources = FluentTheme.of(context).resources;
    final width = math.min(
      widget.expandedWidth,
      math.max(0.0, bounds.width - 16),
    );
    final height = math.min(
      widget.expandedHeight,
      math.max(0.0, bounds.height - 16),
    );
    final target = Rect.fromLTWH(
      (anchor.center.dx - width / 2).clamp(
        bounds.left + 8,
        math.max(bounds.left + 8, bounds.right - width - 8),
      ),
      (anchor.top - widget.previewLift).clamp(
        bounds.top + 8,
        math.max(bounds.top + 8, bounds.bottom - height - 8),
      ),
      width,
      height,
    );
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final t = FfTokens.curve.transform(_animation.value);
        final rect = Rect.lerp(anchor, target, t)!;
        return Positioned.fromRect(
          rect: rect,
          child: IgnorePointer(
            ignoring: _closing,
            child: TapRegion(
              onTapOutside: (_) => _dismiss(),
              child: ExcludeSemantics(
                // 预览是同一入口的视觉展开，稳定保留原卡片的读屏按钮，
                // 避免关闭浮层时把语义节点在两个分支之间来回移动。
                excluding: true,
                // 尺寸变化时表面保持实心，避免底层海报透出形成双重图像。
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => _enter(preview: true),
                  onExit: (_) => _leave(),
                  child: Listener(
                    onPointerSignal: (event) {
                      if (event is PointerScrollEvent) _scope?.scroll(event);
                    },
                    child: GestureDetector(
                      onTap: _activate,
                      behavior: HitTestBehavior.opaque,
                      child: Semantics(
                        button: true,
                        label: widget.title,
                        onTap: _activate,
                        child: FocusBorder(
                          focused: _highlight,
                          child: PhysicalModel(
                            color: resources.solidBackgroundFillColorBase,
                            elevation: 12 * t,
                            shadowColor: FluentTheme.of(context).shadowColor,
                            borderRadius: BorderRadius.circular(8),
                            clipBehavior: Clip.antiAlias,
                            child: OverflowBox(
                              alignment: Alignment.topCenter,
                              minWidth: width,
                              maxWidth: width,
                              minHeight: height,
                              maxHeight: height,
                              child: SizedBox(
                                width: width,
                                height: height,
                                child: DecoratedBox(
                                  position: DecorationPosition.foreground,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: resources.cardStrokeColorDefault,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: child,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ExcludeSemantics(
              child: (widget.previewImageBuilder ?? widget.imageBuilder)(
                context,
              ),
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: height * .85),
            child: SingleChildScrollView(
              primary: false,
              child: Listener(
                onPointerSignal: (event) {
                  if (event is PointerScrollEvent) _scope?.scroll(event);
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: FluentTheme.of(context).typography.subtitle,
                      ),
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: FluentTheme.of(context).typography.caption
                              ?.copyWith(
                                color: resources.textFillColorSecondary,
                              ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      widget.previewBuilder(context),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resources = FluentTheme.of(context).resources;
    return FocusableActionDetector(
      focusNode: _focus,
      enabled: widget.onPressed != null,
      onShowFocusHighlight: (value) {
        setState(() => _highlight = value);
        _entry?.markNeedsBuild();
      },
      onFocusChange: (focused) {
        if (focused) {
          _open();
        } else if (!_hovered) {
          _dismiss();
        }
      },
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _activate();
            return null;
          },
        ),
        DismissIntent: CallbackAction<DismissIntent>(
          onInvoke: (_) {
            _dismiss();
            _focus.unfocus();
            return null;
          },
        ),
      },
      child: MouseRegion(
        cursor: widget.onPressed == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        onEnter: (_) => _enter(),
        onExit: (_) => _leave(),
        child: GestureDetector(
          onTap: widget.onPressed == null ? null : _activate,
          child: ExcludeSemantics(
            excluding: false,
            child: Semantics(
              container: true,
              button: true,
              enabled: widget.onPressed != null,
              onTap: widget.onPressed == null ? null : _activate,
              label: [widget.title, ?widget.subtitle].join('，'),
              excludeSemantics: true,
              child: FocusBorder(
                focused: _highlight && _entry == null,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: resources.cardBackgroundFillColorDefault,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: resources.cardStrokeColorDefault),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AspectRatio(
                          aspectRatio: widget.posterAspectRatio,
                          child: widget.imageBuilder(context),
                        ),
                        _caption(context),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
