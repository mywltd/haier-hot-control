import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';

/// 侧栏尺寸：72 宽；瓦片 64×58、间距 4、圆角 6；图标 20，文字 Caption。
const double kSidebarWidth = 72;
const double _tileHeight = 58;
const double _tileGap = 4;
const double _tileInset = (kSidebarWidth - 64) / 2;
const double _pillHeight = 16;

/// 侧栏的一项：页面入口（[onTap] 为 null）或动作按钮（如主题切换，不占选中下标）。
class NavEntry {
  const NavEntry({
    required this.label,
    required this.icon,
    this.fallbackIcon,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData? fallbackIcon;
  final VoidCallback? onTap;

  bool get isPage => onTap == null;
}

/// Store 式窄侧栏：标题栏在上，侧栏透出云母，右侧内容区叠一层半透明填充。
///
/// 通过 [NavigationPane.customPane] 接入，页面切换与转场仍由 [NavigationView] 负责。
/// [entries] 依次对应 [NavigationPane.items]；[footer] 里的页面项依次对应
/// [NavigationPane.footerItems]，动作项不占位置。
class NavSidebarPane extends NavigationPaneWidget {
  NavSidebarPane({
    required this.entries,
    this.footer = const [],
    this.immersive = false,
    this.onDismiss,
  });

  final List<NavEntry> entries;
  final List<NavEntry> footer;
  final bool immersive;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context, NavigationPaneWidgetData data) {
    final pane = data.pane;
    final pages = [...pane.items, ...pane.footerItems];
    // NavigationView 无条件消费 Esc；固定 customPane 没有可关闭的面板，
    // 改走 DismissIntent，让更内层的菜单、弹窗和文字工具栏先处理。
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape, includeRepeats: false):
            DismissIntent(),
      },
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              if (onDismiss != null) {
                onDismiss!();
                return null;
              }
              final focus = FocusManager.instance.primaryFocus;
              if (focus is! FocusScopeNode) focus?.unfocus();
              return null;
            },
          ),
        },
        child: Column(
          children: [
            ExcludeFocus(
              excluding: immersive,
              child: Offstage(
                offstage: immersive,
                child: data.titleBar ?? const SizedBox.shrink(),
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ExcludeFocus(
                    excluding: immersive,
                    child: Offstage(
                      offstage: immersive,
                      child: _Sidebar(
                        entries: entries,
                        footer: footer,
                        selected: pane.selected,
                        onSelect: (i) => pane.changeTo(pages[i]),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _ContentLayer(
                      immersive: immersive,
                      child: data.content,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 主体内容层：WinUI 内容区同款半透明填充 + 描边 + 左上圆角，让云母在主体里弱一些。
class _ContentLayer extends StatelessWidget {
  const _ContentLayer({required this.child, this.immersive = false});

  final Widget child;
  final bool immersive;

  @override
  Widget build(BuildContext context) {
    final res = FluentTheme.of(context).resources;
    final shape = RoundedRectangleBorder(
      side: immersive
          ? BorderSide.none
          : BorderSide(color: res.cardStrokeColorDefault),
      borderRadius: immersive
          ? BorderRadius.zero
          : const BorderRadiusDirectional.only(topStart: Radius.circular(8))
                .resolve(Directionality.of(context)),
    );
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: ShapeDecoration(shape: shape),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        child: ColoredBox(
          color: immersive ? Colors.black : res.layerFillColorDefault,
          child: child,
        ),
      ),
    );
  }
}

/// 侧栏中某个瓦片的位置：[group] 0 为顶部列表、1 为底部列表。
typedef _Slot = ({double top, int group});

class _Sidebar extends StatefulWidget {
  const _Sidebar({
    required this.entries,
    required this.footer,
    required this.selected,
    required this.onSelect,
  });

  final List<NavEntry> entries;
  final List<NavEntry> footer;
  final int? selected;
  final ValueChanged<int> onSelect;

  @override
  State<_Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<_Sidebar> {
  final _scrollController = ScrollController();
  bool _revealSelection = true;
  double? _viewportHeight;

  @override
  void didUpdateWidget(_Sidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected ||
        oldWidget.entries.length != widget.entries.length ||
        oldWidget.footer.length != widget.footer.length) {
      _revealSelection = true;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _reveal(_Slot? slot, double viewportHeight) {
    final resized = _viewportHeight != viewportHeight;
    _viewportHeight = viewportHeight;
    if (!_revealSelection && !resized) return;
    _revealSelection = false;
    if (slot == null || slot.group != 0 || viewportHeight <= 0) return;
    final selected = widget.selected;
    final animate = !resized && !MediaQuery.disableAnimationsOf(context);
    // 搜索跳转和窗口缩小也会改变可见范围，等滚动区域完成布局后再定位。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          selected != widget.selected ||
          !_scrollController.hasClients) {
        return;
      }
      final position = _scrollController.position;
      final bottom = slot.top + _tileHeight;
      final target =
          (slot.top < position.pixels
                  ? slot.top
                  : bottom > position.pixels + position.viewportDimension
                  ? bottom - position.viewportDimension
                  : position.pixels)
              .clamp(position.minScrollExtent, position.maxScrollExtent);
      if (target == position.pixels) return;
      if (animate) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: kSidebarWidth,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final footerHeight = (widget.footer.length * (_tileHeight + _tileGap))
              .clamp(0.0, constraints.maxHeight);
          final viewportHeight = constraints.maxHeight - footerHeight;
          final contentHeight =
              _tileGap + widget.entries.length * (_tileHeight + _tileGap);
          final maxScroll = (contentHeight - viewportHeight).clamp(
            0.0,
            double.infinity,
          );
          final topTiles = <Widget>[];
          final footerTiles = <Widget>[];
          final pageSlots = <_Slot>[];
          void place(NavEntry entry, _Slot slot, List<Widget> tiles) {
            final page = entry.isPage ? pageSlots.length : null;
            if (page != null) {
              pageSlots.add(slot);
            }
            tiles.add(
              Positioned(
                left: 0,
                right: 0,
                top: slot.top,
                height: _tileHeight,
                child: _NavTile(
                  entry: entry,
                  selected: page != null && page == widget.selected,
                  onPressed: entry.onTap ?? () => widget.onSelect(page!),
                ),
              ),
            );
          }

          for (var i = 0; i < widget.entries.length; i++) {
            place(widget.entries[i], (
              top: _tileGap + i * (_tileHeight + _tileGap),
              group: 0,
            ), topTiles);
          }
          for (var i = 0; i < widget.footer.length; i++) {
            place(widget.footer[i], (
              top: viewportHeight + i * (_tileHeight + _tileGap),
              group: 1,
            ), footerTiles);
          }

          final index = widget.selected;
          final slot = index != null && index >= 0 && index < pageSlots.length
              ? pageSlots[index]
              : null;
          _reveal(slot, viewportHeight);
          return Stack(
            children: [
              Positioned.fill(
                bottom: footerHeight,
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context)
                      .copyWith(scrollbars: contentHeight > viewportHeight),
                  child: SingleChildScrollView(
                    key: const ValueKey('sidebar-scroll'),
                    controller: _scrollController,
                    primary: false,
                    child: SizedBox(
                      height: contentHeight,
                      child: Stack(children: topTiles),
                    ),
                  ),
                ),
              ),
              ...footerTiles,
              // 指示条共用一个状态，保留顶部与底部之间先收缩再展开的动效。
              if (slot != null)
                ListenableBuilder(
                  listenable: _scrollController,
                  builder: (context, _) => _SelectionPill(
                    index: index!,
                    top:
                        slot.top +
                        (_tileHeight - _pillHeight) / 2 -
                        (slot.group == 0 && _scrollController.hasClients
                            // 视口放大时布局会校正滚动位置，指示条也按新范围定位。
                            ? _scrollController.offset.clamp(0.0, maxScroll)
                            : 0),
                    group: slot.group,
                    viewportHeight: viewportHeight,
                    totalHeight: constraints.maxHeight,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// 选中指示条，仿 Microsoft Store：
/// - 同组移动：朝向目标的一端先走、另一端滞后跟上，指示条先拉长再收回；
/// - 跨组移动（顶部 ↔ 底部）：原位置收缩消失，再在新位置展开。
class _SelectionPill extends StatefulWidget {
  const _SelectionPill({
    required this.index,
    required this.top,
    required this.group,
    required this.viewportHeight,
    required this.totalHeight,
  });

  /// 选中项下标；变化时才播放动画，窗口高度变化只挪位置。
  final int index;
  final double top;
  final int group;
  final double viewportHeight;
  final double totalHeight;

  @override
  State<_SelectionPill> createState() => _SelectionPillState();
}

class _SelectionPillState extends State<_SelectionPill>
    with SingleTickerProviderStateMixin {
  static const _stretch = Duration(milliseconds: 460);
  static const _swap = Duration(milliseconds: 380);

  // 前沿 0~62% 快速到位，后沿 18%~100% 缓慢跟上，形成拉扯感。
  static const _lead = Interval(0, 0.62, curve: Curves.easeOutCubic);
  static const _trail = Interval(0.18, 1, curve: Curves.easeInOutCubic);
  static const _shrink = Interval(0, 0.45, curve: Curves.easeInCubic);
  static const _grow = Interval(0.45, 1, curve: Curves.easeOutCubic);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    value: 1,
  );
  late double _fromTop = widget.top;
  late double _fromBottom = widget.top + _pillHeight;
  bool _crossGroup = false;
  late int _fromGroup = widget.group;

  @override
  void didUpdateWidget(_SelectionPill old) {
    super.didUpdateWidget(old);
    if (old.index == widget.index) {
      if (old.top != widget.top &&
          (!_crossGroup || _fromGroup == widget.group)) {
        // 滚动时让动画起点和终点一起移动，指示条始终跟随瓦片。
        _fromTop += widget.top - old.top;
        _fromBottom += widget.top - old.top;
      }
      return;
    }
    // 从当前看到的形状出发，动画中途被打断也不会跳。
    final current = _geometry(old.top);
    _fromGroup = _crossGroup && _controller.value < _grow.begin
        ? _fromGroup
        : old.group;
    _fromTop = current.top;
    _fromBottom = current.bottom;
    _crossGroup = _fromGroup != widget.group;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      return;
    }
    _controller
      ..duration = _crossGroup ? _swap : _stretch
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  ({double top, double bottom}) _geometry(double targetTop) {
    final t = _controller.value;
    final toTop = targetTop;
    final toBottom = targetTop + _pillHeight;
    if (_crossGroup) {
      if (t < _grow.begin) {
        final k = _shrink.transform(t);
        final center = (_fromTop + _fromBottom) / 2;
        final half = (_fromBottom - _fromTop) / 2 * (1 - k);
        return (top: center - half, bottom: center + half);
      }
      final k = _grow.transform(t);
      final center = toTop + _pillHeight / 2;
      final half = _pillHeight / 2 * k;
      return (top: center - half, bottom: center + half);
    }
    final lead = _lead.transform(t);
    final trail = _trail.transform(t);
    final down = toTop >= _fromTop;
    final topK = down ? trail : lead;
    final bottomK = down ? lead : trail;
    return (
      top: _fromTop + (toTop - _fromTop) * topK,
      bottom: _fromBottom + (toBottom - _fromBottom) * bottomK,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final color = theme.accentColor.defaultBrushFor(theme.brightness);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final g = _geometry(widget.top);
        final group = _crossGroup && _controller.value < _grow.begin
            ? _fromGroup
            : widget.group;
        final clipTop = group == 0 ? 0.0 : widget.viewportHeight;
        final clipBottom = group == 0
            ? widget.viewportHeight
            : widget.totalHeight;
        final top = g.top.clamp(clipTop, clipBottom);
        final bottom = g.bottom.clamp(clipTop, clipBottom);
        return Positioned(
          left: _tileInset - 1.5,
          top: top,
          width: 3,
          height: (bottom - top).clamp(0.0, double.infinity),
          child: IgnorePointer(
            child: DecoratedBox(
              key: const ValueKey('sidebar-selection-indicator'),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 侧栏瓦片：未选中灰字透明底；悬停加深底色、字变黑；选中白底 + 主题色图标文字。
/// 底色与字色都做过渡，切换选中项时不会闪。
class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.entry,
    required this.selected,
    required this.onPressed,
  });

  static const _fade = Duration(milliseconds: 150);

  final NavEntry entry;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final res = theme.resources;
    final dark = theme.brightness == Brightness.dark;
    return Semantics(
      button: true,
      selected: selected,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _tileInset),
        child: HoverButton(
          onPressed: onPressed,
          builder: (context, states) {
            final radius = BorderRadius.circular(6);
            // 暗色主题下卡片色太淡，用 10% 白区别于悬停。
            final selectedFill = dark
                ? const Color(0x1AFFFFFF)
                : res.cardBackgroundFillColorDefault;
            final (Color? subtle, Color fg) = selected
                ? (null, theme.accentColor.defaultBrushFor(theme.brightness))
                : states.isPressed
                ? (res.subtleFillColorTertiary, res.textFillColorSecondary)
                : states.isHovered
                ? (res.subtleFillColorSecondary, res.textFillColorPrimary)
                : (null, res.textFillColorSecondary);
            return FocusBorder(
              focused: states.isFocused,
              // 选中白底单独一层做淡入淡出；直接在白色和 Colors.transparent（透明黑）
              // 之间插值，过渡中途会变灰、闪一下。
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedOpacity(
                    opacity: selected ? 1 : 0,
                    duration: _fade,
                    curve: Curves.easeOut,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: selectedFill,
                        borderRadius: radius,
                      ),
                    ),
                  ),
                  AnimatedContainer(
                    duration: _fade,
                    curve: Curves.easeOut,
                    decoration: BoxDecoration(
                      // 透明时保持悬停色的色相，同样避免插值发灰。
                      color:
                          subtle ??
                          res.subtleFillColorSecondary.withValues(alpha: 0),
                      borderRadius: radius,
                    ),
                  ),
                  TweenAnimationBuilder<Color?>(
                    tween: ColorTween(end: fg),
                    duration: _fade,
                    curve: Curves.easeOut,
                    builder: (context, color, _) => Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        WindowsIcon(
                          entry.icon,
                          size: 20,
                          color: color,
                          fallbackIcon: entry.fallbackIcon,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          entry.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.caption?.copyWith(
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
