import 'dart:async';
import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import 'ff_carousel_spotlight.dart';
import 'ff_focus_dismissal.dart';

/// 图片由调用方提供；点击行为可以跳转页面，也可以打开应用内的详情。
@immutable
class FfCarouselItem {
  const FfCarouselItem({
    required this.id,
    required this.title,
    required this.description,
    required this.imageBuilder,
    this.eyebrow,
    this.actionLabel,
    this.onPressed,
  });

  /// 同一轮播内唯一且稳定，用于数据增删、排序后保留当前内容。
  final Object id;
  final String title;
  final String description;

  /// 提供填满约束的 Image / 自绘图片。不要返回带共享 GlobalKey 的实例。
  final WidgetBuilder imageBuilder;
  final String? eyebrow;
  final String? actionLabel;
  final VoidCallback? onPressed;
}

/// 可替换或继承以提供应用自己的本地化文案。
class FfCarouselLabels {
  const FfCarouselLabels({
    this.previous = '上一张',
    this.next = '下一张',
    this.pause = '暂停自动轮播',
    this.play = '继续自动轮播',
    this.open = '查看详情',
  });

  final String previous;
  final String next;
  final String pause;
  final String play;
  final String open;
  String position(int index, int count) => '第 ${index + 1} 张，共 $count 张';
  String select(int index, String title) => '转到第 ${index + 1} 张：$title';
}

/// 翻页箭头的位置；分页点、页码和自动播放开关始终留在底部。
enum FfCarouselArrowPlacement { bottom, sides }

/// Store 风格的循环轮播。图、标题和简介随同一页移动，并按页偏移同步缩放。
///
/// 父级提供有限宽度；[height] 是图片区域高度，控制栏另外占 48 像素。
/// 空列表不占空间，单项隐藏控制栏且禁止滚动。默认不自动播放。
class FfCarousel extends StatefulWidget {
  const FfCarousel({
    super.key,
    required this.items,
    this.height = 340,
    this.viewportFraction = 0.9,
    this.initialIndex = 0,
    this.autoPlay = false,
    this.interval = const Duration(seconds: 6),
    this.duration = const Duration(milliseconds: 680),
    this.arrowPlacement = FfCarouselArrowPlacement.bottom,
    this.spotlight = true,
    this.onIndexChanged,
    this.labels = const FfCarouselLabels(),
  }) : assert(height >= 240),
       assert(viewportFraction > 0.5 && viewportFraction <= 1),
       assert(initialIndex >= 0);

  final List<FfCarouselItem> items;
  final double height;
  final double viewportFraction;
  final int initialIndex;
  final bool autoPlay;

  /// 每张停稳后的阅读时间，不包含过渡时长。
  final Duration interval;
  final Duration duration;
  final FfCarouselArrowPlacement arrowPlacement;

  /// 鼠标在图片上移动时显示柔和高光；减少动画或高对比度模式下自动关闭。
  final bool spotlight;
  final ValueChanged<int>? onIndexChanged;
  final FfCarouselLabels labels;

  @override
  State<FfCarousel> createState() => _FfCarouselState();
}

class _FfCarouselState extends State<FfCarousel> with WidgetsBindingObserver {
  late PageController _controller;
  late List<Object> _ids;
  late int _index;
  int? _target;
  int _navigation = 0;
  Timer? _timer;
  final _focus = FocusNode(debugLabel: 'FfCarousel');
  final _pointers = <int>{};
  bool _hovered = false;
  bool _focused = false;
  bool _touchInteraction = false;
  bool _paused = false;
  bool _scrolling = false;
  bool _reduceMotion = false;
  bool _accessibleNavigation = false;
  bool _visible = true;
  bool _foreground = true;

  int get _count => widget.items.length;
  bool get _sideArrows =>
      _count > 1 && widget.arrowPlacement == FfCarouselArrowPlacement.sides;
  bool get _showSideArrows =>
      _hovered || _focused || _touchInteraction || _accessibleNavigation;
  int get _origin => math.max(1, _count) * 1000;
  double get _page =>
      _controller.hasClients && _controller.position.hasContentDimensions
      ? _controller.page ?? _controller.initialPage.toDouble()
      : _controller.initialPage.toDouble();

  @override
  void initState() {
    super.initState();
    _validateTiming();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _index = _count == 0 ? 0 : widget.initialIndex % _count;
    _resetController();
  }

  void _validateTiming() {
    assert(widget.interval > Duration.zero, 'interval 必须大于零');
    assert(widget.duration >= Duration.zero, 'duration 不得为负');
  }

  void _resetController() {
    _ids = widget.items.map((item) => item.id).toList();
    assert(_ids.toSet().length == _ids.length, 'FfCarouselItem.id 必须唯一');
    _controller = PageController(
      initialPage: _count <= 1 ? 0 : _origin + _index,
      viewportFraction: _count <= 1 ? 1 : widget.viewportFraction,
      keepPage: false,
    );
    _navigation++;
    _target = null;
    _scrolling = false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced && !_reduceMotion && _controller.hasClients) {
      // 系统在过渡中切换到减少动画时，下一帧直接停到目标页。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _reduceMotion && _controller.hasClients) {
          _controller.jumpToPage(_target ?? _page.round());
        }
      });
    }
    _reduceMotion = reduced;
    _accessibleNavigation = MediaQuery.accessibleNavigationOf(context);
    _visible =
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.isCurrentOf(context) ?? true);
    _schedule();
  }

  @override
  void didUpdateWidget(FfCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _validateTiming();
    final changed =
        _ids.length != _count ||
        _ids.indexed.any((entry) => entry.$2 != widget.items[entry.$1].id);
    if (changed || oldWidget.viewportFraction != widget.viewportFraction) {
      final currentId = _ids.isEmpty ? null : _ids[_index];
      final preserved = widget.items.indexWhere((item) => item.id == currentId);
      _index = preserved >= 0
          ? preserved
          : _index.clamp(0, math.max(0, _count - 1));
      final previous = _controller;
      _resetController();
      // PageView 在本次重建时解除旧控制器，随后才能释放它。
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    }
    if (oldWidget.autoPlay != widget.autoPlay) _paused = false;
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _schedule();
  }

  bool get _canPlay =>
      widget.autoPlay &&
      _count > 1 &&
      !_paused &&
      !_hovered &&
      !_focused &&
      _pointers.isEmpty &&
      !_scrolling &&
      !_reduceMotion &&
      !_accessibleNavigation &&
      _visible &&
      _foreground;

  void _schedule() {
    _timer?.cancel();
    _timer = null;
    if (_canPlay) {
      // 单次计时：停稳或恢复后重新给予完整阅读时间，不追赶后台漏掉的轮次。
      _timer = Timer(widget.interval, () => _move(1));
    }
  }

  Future<void> _move(int delta) =>
      _animateTo((_target ?? _page.round()) + delta);

  Future<void> _select(int index) {
    final current = _target ?? _page.round();
    var delta = (index - current % _count + _count) % _count;
    if (delta > _count / 2) delta -= _count;
    return _animateTo(current + delta);
  }

  Future<void> _animateTo(int page) async {
    if (_count <= 1 || !_controller.hasClients) return;
    _timer?.cancel();
    final navigation = ++_navigation;
    _target = page;
    if (_reduceMotion || widget.duration == Duration.zero) {
      _controller.jumpToPage(page);
    } else {
      await _controller.animateToPage(
        page,
        duration: widget.duration,
        curve: const Cubic(0.22, 0.75, 0.18, 1),
      );
    }
    if (!mounted || navigation != _navigation) return;
    _target = null;
    _schedule();
  }

  bool _onScroll(ScrollNotification event) {
    if (event.depth != 0) return false;
    if (event is ScrollStartNotification) {
      _scrolling = true;
      if (event.dragDetails != null) {
        _navigation++;
        _target = null;
      }
      _schedule();
    } else if (event is ScrollEndNotification) {
      _scrolling = false;
      // 只在停稳且离中段很远时重定位到等价页，支持长期向任一方向循环。
      final page = _page.round();
      if (_count > 1 && (page < _count * 2 || page > _origin * 2)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              !_scrolling &&
              _target == null &&
              _controller.hasClients) {
            _controller.jumpToPage(_origin + _index);
          }
        });
      }
      _schedule();
    }
    return false;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || _count < 2) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowLeft) {
      _focus.requestFocus();
      _move((key == LogicalKeyboardKey.arrowRight) != rtl ? 1 : -1);
    } else if (key == LogicalKeyboardKey.home ||
        key == LogicalKeyboardKey.end) {
      _focus.requestFocus();
      _select(key == LogicalKeyboardKey.home ? 0 : _count - 1);
    } else if ((key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.space) &&
        _focus.hasPrimaryFocus) {
      if (!_scrolling) widget.items[_index].onPressed?.call();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  void _releaseKeyboardFocus() {
    if (_focus.hasFocus) _focus.unfocus();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_count == 0) return const SizedBox.shrink();
    final carousel = MouseRegion(
      onEnter: (_) {
        setState(() {
          _hovered = true;
          _touchInteraction = false;
        });
        _schedule();
      },
      onExit: (_) {
        setState(() => _hovered = false);
        _schedule();
      },
      child: Focus(
        focusNode: _focus,
        onKeyEvent: _onKey,
        onFocusChange: (value) {
          setState(() => _focused = value);
          _schedule();
        },
        child: Listener(
          onPointerDown: (event) {
            if (event.kind == PointerDeviceKind.touch ||
                event.kind == PointerDeviceKind.stylus ||
                event.kind == PointerDeviceKind.invertedStylus) {
              setState(() => _touchInteraction = true);
            }
            _pointers.add(event.pointer);
            _schedule();
          },
          onPointerUp: (event) {
            _pointers.remove(event.pointer);
            _schedule();
          },
          onPointerCancel: (event) {
            _pointers.remove(event.pointer);
            _schedule();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FocusBorder(
                focused: _focus.hasPrimaryFocus,
                child: SizedBox(
                  height: widget.height,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      NotificationListener<ScrollNotification>(
                        onNotification: _onScroll,
                        child: ScrollConfiguration(
                          behavior: ScrollConfiguration.of(context).copyWith(
                            scrollbars: false,
                            dragDevices: {
                              PointerDeviceKind.mouse,
                              PointerDeviceKind.touch,
                              PointerDeviceKind.stylus,
                              PointerDeviceKind.invertedStylus,
                              PointerDeviceKind.trackpad,
                            },
                          ),
                          child: PageView.builder(
                            key: ObjectKey(_controller),
                            controller: _controller,
                            itemCount: _count == 1 ? 1 : null,
                            physics: _count == 1
                                ? const NeverScrollableScrollPhysics()
                                : const PageScrollPhysics(),
                            onPageChanged: (page) {
                              final index = page % _count;
                              if (index == _index) return;
                              setState(() => _index = index);
                              widget.onIndexChanged?.call(index);
                            },
                            itemBuilder: (context, physical) {
                              final item = widget.items[physical % _count];
                              return AnimatedBuilder(
                                animation: _controller,
                                child: RepaintBoundary(
                                  child: item.imageBuilder(context),
                                ),
                                builder: (context, image) {
                                  final offset = (_page - physical).clamp(
                                    -1.0,
                                    1.0,
                                  );
                                  final current = offset.abs() < 0.5;
                                  return ExcludeSemantics(
                                    excluding: !current,
                                    child: ExcludeFocus(
                                      excluding: !current,
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: _count > 1 ? 6 : 0,
                                          vertical: 4,
                                        ),
                                        child: _CarouselCard(
                                          item: item,
                                          image: image!,
                                          offset: _reduceMotion ? 0 : offset,
                                          labels: widget.labels,
                                          position: widget.labels.position(
                                            physical % _count,
                                            _count,
                                          ),
                                          onPressed: () {
                                            if (_scrolling) return;
                                            if (current) {
                                              item.onPressed?.call();
                                            } else {
                                              _animateTo(physical);
                                            }
                                          },
                                          actionable:
                                              !current ||
                                              item.onPressed != null,
                                          reserveArrowSpace: _sideArrows,
                                          spotlight: widget.spotlight,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                      if (_sideArrows) ...[
                        PositionedDirectional(
                          start: 12,
                          top: (widget.height - 36) / 2,
                          child: _revealingArrow(context, previous: true),
                        ),
                        PositionedDirectional(
                          end: 12,
                          top: (widget.height - 36) / 2,
                          child: _revealingArrow(context, previous: false),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (_count > 1) _controls(context),
            ],
          ),
        ),
      ),
    );
    // 内部指针与未消费的 Esc 复用统一入口，独立使用轮播时也保留快捷键优先级。
    // 外部点击由 TapRegion 观察，不抢占其他控件的手势。
    return TapRegion(
      onTapOutside: (_) => _releaseKeyboardFocus(),
      child: FfFocusDismissal(child: carousel),
    );
  }

  Widget _command(
    String label,
    IconData icon,
    VoidCallback onPressed, {
    ButtonStyle? style,
  }) => Tooltip(
    message: label,
    excludeFromSemantics: true,
    child: MergeSemantics(
      child: Semantics(
        label: label,
        child: IconButton(
          icon: Icon(icon, size: 12),
          onPressed: onPressed,
          style: style,
        ),
      ),
    ),
  );

  Widget _revealingArrow(BuildContext context, {required bool previous}) {
    final visible = _showSideArrows;
    // 透明时不占鼠标点击区；读屏操作与 Tab 入口仍保留，聚焦后立即可见。
    return Semantics(
      label: visible
          ? null
          : (previous ? widget.labels.previous : widget.labels.next),
      button: visible ? null : true,
      onTap: visible ? null : () => _move(previous ? -1 : 1),
      excludeSemantics: !visible,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: _reduceMotion || _focused || _accessibleNavigation
              ? Duration.zero
              : const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: _arrow(context, previous: previous),
        ),
      ),
    );
  }

  Widget _arrow(BuildContext context, {required bool previous}) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final resources = FluentTheme.of(context).resources;
    final base = resources.solidBackgroundFillColorBase;
    final button = _command(
      previous ? widget.labels.previous : widget.labels.next,
      previous != rtl ? FluentIcons.chevron_left : FluentIcons.chevron_right,
      () => _move(previous ? -1 : 1),
      style: _sideArrows
          ? ButtonStyle(
              padding: const WidgetStatePropertyAll(EdgeInsets.zero),
              shape: WidgetStatePropertyAll(
                CircleBorder(
                  side: BorderSide(color: resources.controlStrokeColorDefault),
                ),
              ),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.isPressed) {
                  return Color.alphaBlend(
                    resources.subtleFillColorTertiary,
                    base,
                  );
                }
                if (states.isHovered) {
                  return Color.alphaBlend(
                    resources.subtleFillColorSecondary,
                    base,
                  );
                }
                // 图片明暗不固定，用主题底色承托箭头，避免落在亮图上看不清。
                return base.withValues(alpha: .9);
              }),
              foregroundColor: WidgetStateProperty.resolveWith(
                (states) => states.isPressed
                    ? resources.textFillColorSecondary
                    : resources.textFillColorPrimary,
              ),
            )
          : null,
    );
    return _sideArrows ? SizedBox.square(dimension: 36, child: button) : button;
  }

  Widget _controls(BuildContext context) {
    final theme = FluentTheme.of(context);
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          if (!_sideArrows) _arrow(context, previous: true),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final slots = math.min(5, constraints.maxWidth ~/ 32);
                final start = math.max(
                  0,
                  math.min(_index - slots ~/ 2, _count - slots),
                );
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (
                      var i = start;
                      i < math.min(start + slots, _count);
                      i++
                    )
                      Semantics(
                        key: ValueKey(i),
                        selected: i == _index,
                        child: Tooltip(
                          message: widget.labels.select(
                            i,
                            widget.items[i].title,
                          ),
                          excludeFromSemantics: true,
                          child: HoverButton(
                            semanticLabel: widget.labels.select(
                              i,
                              widget.items[i].title,
                            ),
                            onPressed: () => _select(i),
                            builder: (context, states) => FocusBorder(
                              focused: states.isFocused,
                              child: SizedBox(
                                width: 32,
                                height: 32,
                                child: Center(
                                  child: AnimatedContainer(
                                    duration: _reduceMotion
                                        ? Duration.zero
                                        : const Duration(milliseconds: 180),
                                    curve: Curves.easeOut,
                                    width: i == _index ? 22 : 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4),
                                      color: i == _index
                                          ? theme.accentColor.defaultBrushFor(
                                              theme.brightness,
                                            )
                                          : theme
                                                .resources
                                                .textFillColorTertiary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          Semantics(
            label: widget.labels.position(_index, _count),
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '${(_index + 1).toString().padLeft(2, '0')} / ${_count.toString().padLeft(2, '0')}',
                style: theme.typography.caption?.copyWith(
                  color: theme.resources.textFillColorSecondary,
                ),
              ),
            ),
          ),
          if (!_sideArrows) _arrow(context, previous: false),
          if (widget.autoPlay && !_reduceMotion && !_accessibleNavigation)
            _command(
              _paused ? widget.labels.play : widget.labels.pause,
              _paused ? FluentIcons.play : FluentIcons.pause,
              () {
                setState(() => _paused = !_paused);
                _schedule();
              },
            ),
        ],
      ),
    );
  }
}

class _CarouselCard extends StatelessWidget {
  const _CarouselCard({
    required this.item,
    required this.image,
    required this.offset,
    required this.labels,
    required this.position,
    required this.onPressed,
    required this.actionable,
    required this.reserveArrowSpace,
    required this.spotlight,
  });

  final FfCarouselItem item;
  final Widget image;
  final double offset;
  final FfCarouselLabels labels;
  final String position;
  final VoidCallback onPressed;
  final bool actionable;
  final bool reserveArrowSpace;
  final bool spotlight;

  @override
  Widget build(BuildContext context) {
    final distance = offset.abs();
    final typography = FluentTheme.of(context).typography;
    return Transform.scale(
      scale: 1 - 0.065 * distance,
      child: HoverButton(
        semanticLabel:
            '$position，${item.title}。${item.description}${item.onPressed == null ? '' : '。${item.actionLabel ?? labels.open}'}',
        onPressed: actionable ? onPressed : null,
        cursor: actionable
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        builder: (context, states) => FocusBorder(
          focused: states.isFocused,
          style: FocusThemeData(borderRadius: BorderRadius.circular(12)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ExcludeSemantics(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: Color(0xFF182434)),
                  FfCarouselSpotlight(
                    enabled: spotlight,
                    foreground: Stack(
                      fit: StackFit.expand,
                      children: [
                        // 图片有自己的配色；遮罩保证白字对比度，不改变外层 Fluent 资源色。
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Color(0xD90B1020),
                                Color(0x550B1020),
                                Color(0x150B1020),
                              ],
                              stops: [0, 0.6, 1],
                            ),
                          ),
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Color(0x660B1020)],
                            ),
                          ),
                        ),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final compact = constraints.maxWidth < 600;
                            final short = constraints.maxHeight < 300;
                            final padding = compact || short ? 24.0 : 36.0;
                            // 整页模式下也要给两侧箭头留空，避免按钮挡住标题和行动提示。
                            final horizontalPadding = reserveArrowSpace
                                ? 56.0
                                : padding;
                            return Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: horizontalPadding,
                                vertical: padding,
                              ),
                              child: Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: Transform.translate(
                                  offset: Offset(-offset * 18, 0),
                                  child: Transform.scale(
                                    scale: 1 - 0.12 * distance,
                                    alignment: AlignmentDirectional.centerStart
                                        .resolve(Directionality.of(context)),
                                    child: SizedBox(
                                      width: math.min(
                                        440,
                                        constraints.maxWidth -
                                            horizontalPadding * 2,
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (item.eyebrow != null &&
                                              !short) ...[
                                            Text(
                                              item.eyebrow!,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: typography.caption
                                                  ?.copyWith(
                                                    color: Colors.white,
                                                    letterSpacing: 1.6,
                                                  ),
                                            ),
                                            const SizedBox(height: 12),
                                          ],
                                          Flexible(
                                            flex: short ? 1 : 3,
                                            child: Text(
                                              item.title,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: typography.title?.copyWith(
                                                color: Colors.white,
                                                fontSize: compact || short
                                                    ? 26
                                                    : 34,
                                                height: 1.25,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Flexible(
                                            flex: short ? 1 : 2,
                                            child: Text(
                                              item.description,
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                              style: typography.body?.copyWith(
                                                color: const Color(0xEFFFFFFF),
                                                height: 1.6,
                                              ),
                                            ),
                                          ),
                                          if (item.onPressed != null) ...[
                                            SizedBox(height: short ? 16 : 22),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 9,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: states.isHovered
                                                    ? const Color(0xFFFFFFFF)
                                                    : const Color(0xEFFFFFFF),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      item.actionLabel ??
                                                          labels.open,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: typography
                                                          .bodyStrong
                                                          ?.copyWith(
                                                            color: const Color(
                                                              0xFF152238,
                                                            ),
                                                          ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  const Icon(
                                                    FluentIcons.chevron_right,
                                                    size: 10,
                                                    color: Color(0xFF152238),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    child: Transform.scale(
                      scale: 1.04 + 0.045 * distance,
                      child: image,
                    ),
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
