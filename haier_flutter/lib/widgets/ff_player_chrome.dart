import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';

import 'popup_surface.dart';

/// 视频上方的亚克力表面；模糊只采样画面，投影不混入半透明底色。
class FfPlayerSurface extends StatelessWidget {
  const FfPlayerSurface({super.key, required this.child});

  final Widget child;
  static const _radius = BorderRadius.all(Radius.circular(12));

  @override
  Widget build(BuildContext context) => PopupShadow(
    borderRadius: _radius,
    child: PopupSurface(
      borderRadius: _radius,
      tintOpacity: FluentTheme.of(context).brightness == Brightness.dark
          ? 0.55
          : 0.65,
      luminosityOpacity: 0.65,
      // 淡出会建立离屏层，src 避免背景在半透明合成时被重复叠加。
      blendMode: BlendMode.src,
      child: child,
    ),
  );
}

/// 只管理视频浮层的显隐；播放引擎、媒体信息和窗口操作由调用方提供。
class FfPlayerChrome extends StatefulWidget {
  const FfPlayerChrome({
    super.key,
    required this.child,
    required this.controls,
    required this.playing,
    this.autoHide = true,
    this.hideDelay = const Duration(seconds: 3),
    this.showTitleBar = false,
    this.title,
    this.episodeLabel,
    this.onDragWindow,
    this.onExit,
    this.exitLabel = '退出全屏',
    this.hideCursor = false,
    this.onRestoreVideoFocus,
  }) : assert(hideDelay > Duration.zero);

  final Widget child;
  final Widget controls;
  final bool playing;
  final bool autoHide;
  final Duration hideDelay;
  final bool showTitleBar;
  final String? title;
  final String? episodeLabel;
  final VoidCallback? onDragWindow;
  final VoidCallback? onExit;
  final String exitLabel;
  final bool hideCursor;
  final VoidCallback? onRestoreVideoFocus;

  /// 菜单可能位于根 Overlay；打开期间持有，关闭或卸载时释放。
  /// 自定义 controls 也可用这个入口保护自己的菜单或异步交互。
  static VoidCallback keepVisible(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_ChromeScope>()?.state.hold() ??
      () {};

  @override
  State<FfPlayerChrome> createState() => _FfPlayerChromeState();
}

class _FfPlayerChromeState extends State<FfPlayerChrome>
    with SingleTickerProviderStateMixin {
  final _regionFocus = FocusNode(debugLabel: '播放器活动区域');
  final _controlsFocus = FocusNode(debugLabel: '播放器浮动控件');
  final _titleFocus = FocusNode(debugLabel: '播放器浮动标题');
  final _hovered = <String>{};
  final _pointers = <int>{};
  late final AnimationController _animation;
  Timer? _timer;
  bool _visible = true;
  bool _keyboardNavigation = false;
  bool _accessibleNavigation = false;
  bool _reduceMotion = false;
  bool _dependenciesReady = false;
  int _holds = 0;

  bool get _canHide =>
      widget.autoHide &&
      widget.playing &&
      !_accessibleNavigation &&
      _hovered.isEmpty &&
      _pointers.isEmpty &&
      _holds == 0 &&
      !(_keyboardNavigation &&
          (_controlsFocus.hasFocus || _titleFocus.hasFocus));

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      value: 1,
      duration: const Duration(milliseconds: 180),
    );
    // 仅观察本播放器内的按键，先唤出控件，不消费任何快捷键或输入。
    FocusManager.instance.addEarlyKeyEventHandler(_onKey);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final accessible = MediaQuery.accessibleNavigationOf(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final changed = !_dependenciesReady || accessible != _accessibleNavigation;
    if (reduceMotion && !_reduceMotion) _animation.value = _visible ? 1 : 0;
    _accessibleNavigation = accessible;
    _reduceMotion = reduceMotion;
    _dependenciesReady = true;
    // 播放进度会重建上层主题，不能把每次依赖刷新当成用户活动。
    if (changed) _reveal();
  }

  @override
  void didUpdateWidget(FfPlayerChrome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.showTitleBar) _hovered.remove('title');
    if (oldWidget.playing != widget.playing ||
        oldWidget.autoHide != widget.autoHide ||
        oldWidget.hideDelay != widget.hideDelay ||
        oldWidget.showTitleBar != widget.showTitleBar ||
        oldWidget.title != widget.title ||
        oldWidget.episodeLabel != widget.episodeLabel) {
      _reveal();
    }
  }

  void _reveal() {
    if (!mounted) return;
    if (!_visible) {
      // Tab 的焦点遍历发生在下一帧前，立刻恢复控件的焦点资格。
      _controlsFocus.descendantsAreFocusable = true;
      _titleFocus.descendantsAreFocusable = true;
      setState(() => _visible = true);
    }
    if (_reduceMotion) {
      _animation.value = 1;
    } else {
      _animation.forward();
    }
    _timer?.cancel();
    if (_canHide) {
      _timer = Timer(widget.hideDelay, () {
        if (!mounted || !_canHide) return;
        if (_controlsFocus.hasFocus || _titleFocus.hasFocus) {
          widget.onRestoreVideoFocus?.call();
        }
        setState(() => _visible = false);
        if (_reduceMotion) {
          _animation.value = 0;
        } else {
          _animation.reverse();
        }
      });
    }
  }

  KeyEventResult _onKey(KeyEvent event) {
    if (_regionFocus.hasFocus && event is KeyDownEvent) {
      _keyboardNavigation = true;
      _reveal();
    }
    return KeyEventResult.ignored;
  }

  void _pointerActivity() {
    _keyboardNavigation = false;
    _reveal();
  }

  void _hover(String area, bool hovered) {
    hovered ? _hovered.add(area) : _hovered.remove(area);
    _reveal();
  }

  VoidCallback hold() {
    _holds++;
    _reveal();
    var released = false;
    return () {
      if (released) return;
      released = true;
      _holds--;
      // 菜单也可能在子树卸载时释放，下一次微任务再触发界面更新。
      scheduleMicrotask(() {
        if (mounted) _reveal();
      });
    };
  }

  @override
  void dispose() {
    _timer?.cancel();
    FocusManager.instance.removeEarlyKeyEventHandler(_onKey);
    _animation.dispose();
    _regionFocus.dispose();
    _controlsFocus.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  Widget _floating({
    required String area,
    required FocusNode focus,
    required Widget child,
    required double direction,
  }) => MouseRegion(
    onEnter: (_) => _hover(area, true),
    onExit: (_) => _hover(area, false),
    child: Focus(
      focusNode: focus,
      canRequestFocus: false,
      descendantsAreFocusable: _visible,
      onFocusChange: (focused) {
        if (focused || _visible) _reveal();
      },
      child: ExcludeSemantics(
        excluding: !_visible,
        child: IgnorePointer(
          ignoring: !_visible,
          child: AnimatedBuilder(
            animation: _animation,
            child: child,
            builder: (context, child) => Offstage(
              offstage: _animation.isDismissed,
              child: FadeTransition(
                opacity: _animation,
                child: Transform.translate(
                  offset: Offset(0, (1 - _animation.value) * 8 * direction),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _titleBar() {
    final theme = FluentTheme.of(context);
    final title = widget.title?.trim();
    final episode = widget.episodeLabel?.trim();
    return FfPlayerSurface(
      child: Row(
        children: [
          Expanded(
            child: MouseRegion(
              cursor: widget.onDragWindow == null
                  ? MouseCursor.defer
                  : SystemMouseCursors.move,
              child: GestureDetector(
                key: const ValueKey('player-title-drag'),
                behavior: HitTestBehavior.opaque,
                onPanStart: widget.onDragWindow == null
                    ? null
                    : (_) => widget.onDragWindow!(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Tooltip(
                        message: title == null || title.isEmpty
                            ? '正在播放'
                            : title,
                        child: Text(
                          title == null || title.isEmpty ? '正在播放' : title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.bodyStrong,
                        ),
                      ),
                      if (episode != null && episode.isNotEmpty)
                        Text(
                          episode,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.caption?.copyWith(
                            color: theme.resources.textFillColorSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (widget.onExit != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Tooltip(
                message: widget.exitLabel,
                child: IconButton(
                  icon: const Icon(FluentIcons.back_to_window, size: 16),
                  onPressed: widget.onExit,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _ChromeScope(
    state: this,
    child: Focus(
      focusNode: _regionFocus,
      canRequestFocus: false,
      child: MouseRegion(
        cursor: !_visible && widget.hideCursor
            ? SystemMouseCursors.none
            : MouseCursor.defer,
        onEnter: (_) => _pointerActivity(),
        onHover: (_) => _pointerActivity(),
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) {
            _pointers.add(event.pointer);
            _pointerActivity();
          },
          onPointerMove: (_) => _pointerActivity(),
          onPointerUp: (event) {
            _pointers.remove(event.pointer);
            _pointerActivity();
          },
          onPointerCancel: (event) {
            _pointers.remove(event.pointer);
            _reveal();
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final inset = constraints.maxWidth < 600 ? 8.0 : 20.0;
              return Stack(
                fit: StackFit.expand,
                children: [
                  widget.child,
                  Positioned(
                    top: inset,
                    left: inset,
                    right: inset,
                    child: ExcludeFocus(
                      excluding: !widget.showTitleBar,
                      child: Offstage(
                        offstage: !widget.showTitleBar,
                        child: _floating(
                          area: 'title',
                          focus: _titleFocus,
                          direction: -1,
                          child: _titleBar(),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: inset,
                    left: inset,
                    right: inset,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1100),
                        child: _floating(
                          area: 'controls',
                          focus: _controlsFocus,
                          direction: 1,
                          child: widget.controls,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}

class _ChromeScope extends InheritedWidget {
  const _ChromeScope({required this.state, required super.child});
  final _FfPlayerChromeState state;
  @override
  bool updateShouldNotify(_ChromeScope oldWidget) => state != oldWidget.state;
}
