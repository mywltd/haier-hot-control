import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';

import 'ff_combo_box.dart';
import 'ff_flyout.dart';
import 'ff_player_chrome.dart';
import 'ff_slider.dart';

String ffPlaybackTime(Duration value) {
  final seconds = value.inSeconds.clamp(0, 359999);
  final minutes = (seconds ~/ 60 % 60).toString().padLeft(2, '0');
  final rest = (seconds % 60).toString().padLeft(2, '0');
  return seconds >= 3600
      ? '${seconds ~/ 3600}:$minutes:$rest'
      : '$minutes:$rest';
}

/// A/B/C 对应不同画面处理方式，不代表性能或质量档位。
enum SuperResolutionMode {
  off('关闭'),
  a('A · 恢复'),
  b('B · 柔和恢复'),
  c('C · 降噪');

  const SuperResolutionMode(this.label);
  final String label;
}

/// 只接收状态与回调；引擎、磁盘和窗口由调用方持有。
class FfPlayerControls extends StatefulWidget {
  const FfPlayerControls({
    super.key,
    required this.playing,
    required this.position,
    required this.duration,
    required this.volume,
    required this.onPlayPause,
    required this.onSeek,
    required this.onVolume,
    this.enabled = true,
    this.rate = 1,
    this.onRate,
    this.onMute,
    this.onExpand,
    this.expanded = false,
    this.onPageFullscreen,
    this.pageFullscreen = false,
    this.onSystemFullscreen,
    this.systemFullscreen = false,
    this.onPictureInPicture,
    this.pictureInPicture = false,
    this.superResolution = SuperResolutionMode.off,
    this.onSuperResolution,
    this.superResolutionMessage,
    this.playLabel = '播放',
    this.pauseLabel = '暂停',
    this.seekLabel = '播放进度',
    this.volumeLabel = '音量',
    this.expandLabel = '放大播放区域',
    this.collapseLabel = '还原播放区域',
  });

  final bool playing;
  final bool enabled;
  final Duration position;
  final Duration duration;
  final double volume;
  final double rate;
  final VoidCallback onPlayPause;
  final ValueChanged<Duration>? onSeek;
  final ValueChanged<double> onVolume;
  final ValueChanged<double>? onRate;
  final VoidCallback? onMute;
  final VoidCallback? onExpand;
  final bool expanded;
  final VoidCallback? onPageFullscreen;
  final bool pageFullscreen;
  final VoidCallback? onSystemFullscreen;
  final bool systemFullscreen;
  final VoidCallback? onPictureInPicture;
  final bool pictureInPicture;
  final SuperResolutionMode superResolution;
  final ValueChanged<SuperResolutionMode>? onSuperResolution;
  final String? superResolutionMessage;
  final String playLabel;
  final String pauseLabel;
  final String seekLabel;
  final String volumeLabel;
  final String expandLabel;
  final String collapseLabel;

  @override
  State<FfPlayerControls> createState() => _FfPlayerControlsState();
}

class _FfPlayerControlsState extends State<FfPlayerControls> {
  double? _drag;
  final _more = FlyoutController();
  final _menuLocks = <String, VoidCallback>{};

  void _holdMenu(String menu) =>
      _menuLocks.putIfAbsent(menu, () => FfPlayerChrome.keepVisible(context));

  void _releaseMenu(String menu) => _menuLocks.remove(menu)?.call();

  void _releaseMenus() {
    for (final release in _menuLocks.values) {
      release();
    }
    _menuLocks.clear();
  }

  @override
  void dispose() {
    _releaseMenus();
    _more.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(FfPlayerControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration || !widget.enabled) _drag = null;
  }

  Widget _button(String label, IconData icon, VoidCallback? action) => Tooltip(
    message: label,
    child: IconButton(icon: Icon(icon, size: 16), onPressed: action),
  );

  List<Widget> _windowButtons({bool activeOnly = false, VoidCallback? close}) =>
      [
        if (widget.onPictureInPicture != null &&
            (!activeOnly || widget.pictureInPicture))
          _button(
            widget.pictureInPicture ? '退出画中画' : '画中画',
            widget.pictureInPicture
                ? FluentIcons.back_to_window
                : FluentIcons.mini_expand,
            () {
              close?.call();
              widget.onPictureInPicture!();
            },
          ),
        if (widget.onPageFullscreen != null &&
            (!activeOnly || widget.pageFullscreen))
          _button(
            widget.pageFullscreen ? '退出页面全屏' : '页面全屏',
            widget.pageFullscreen
                ? FluentIcons.back_to_window
                : FluentIcons.fit_page,
            () {
              close?.call();
              widget.onPageFullscreen!();
            },
          ),
        if (widget.onSystemFullscreen != null &&
            (!activeOnly || widget.systemFullscreen))
          _button(
            widget.systemFullscreen ? '退出全屏' : '全屏',
            widget.systemFullscreen
                ? FluentIcons.back_to_window
                : FluentIcons.full_screen,
            () {
              close?.call();
              widget.onSystemFullscreen!();
            },
          ),
        if (widget.onExpand != null && (!activeOnly || widget.expanded))
          _button(
            widget.expanded ? widget.collapseLabel : widget.expandLabel,
            widget.expanded ? FluentIcons.chevron_down : FluentIcons.chevron_up,
            () {
              close?.call();
              widget.onExpand!();
            },
          ),
      ];

  Widget _ratePicker({VoidCallback? close}) => Tooltip(
    message: '播放速度',
    child: FfComboBox<double>(
      onOpen: () => _holdMenu('rate'),
      onClose: () => _releaseMenu('rate'),
      value: widget.rate,
      items: [
        for (final value in {
          0.5,
          1.0,
          1.25,
          1.5,
          2.0,
          widget.rate,
        }.toList()..sort())
          ComboBoxItem(value: value, child: Text('$value×')),
      ],
      onChanged: widget.enabled
          ? (value) {
              if (value != null) {
                close?.call();
                widget.onRate?.call(value);
              }
            }
          : null,
    ),
  );

  Widget _enhancementPicker({VoidCallback? close}) => Tooltip(
    message: widget.superResolutionMessage ?? 'Anime4K 超分',
    child: FfComboBox<SuperResolutionMode>(
      onOpen: () => _holdMenu('enhancement'),
      onClose: () => _releaseMenu('enhancement'),
      value: widget.superResolution,
      selectedItemBuilder: (_) => [
        for (final mode in SuperResolutionMode.values)
          Text(
            '超分：${mode == SuperResolutionMode.off ? '关' : mode.name.toUpperCase()}',
          ),
      ],
      items: [
        for (final mode in SuperResolutionMode.values)
          ComboBoxItem(value: mode, child: Text(mode.label)),
      ],
      onChanged: widget.enabled
          ? (value) {
              if (value != null) {
                close?.call();
                widget.onSuperResolution?.call(value);
              }
            }
          : null,
    ),
  );

  Future<void> _showMore() async {
    final theme = FluentTheme.of(context);
    final screen = MediaQuery.sizeOf(context);
    var volume = widget.volume;
    _holdMenu('more');
    try {
      await _more.showFlyout(
        barrierColor: Colors.transparent,
        builder: (context) => FluentTheme(
          data: theme,
          child: FfFlyoutContent(
            constraints: BoxConstraints(
              maxWidth: math.min(360, screen.width - 24),
              maxHeight: math.min(400, screen.height - 40),
            ),
            padding: const EdgeInsets.all(12),
            child: StatefulBuilder(
              builder: (context, update) {
                void close() => Flyout.of(context).close();
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(widget.volumeLabel),
                      Row(
                        children: [
                          _button(
                            volume == 0 ? '取消静音' : '静音',
                            volume == 0
                                ? FluentIcons.volume0
                                : FluentIcons.volume2,
                            widget.enabled
                                ? () {
                                    close();
                                    if (widget.onMute != null) {
                                      widget.onMute!();
                                    } else {
                                      widget.onVolume(volume == 0 ? 100 : 0);
                                    }
                                  }
                                : null,
                          ),
                          Expanded(
                            child: FfSlider(
                              semanticLabel: widget.volumeLabel,
                              value: volume.clamp(0, 100),
                              max: 100,
                              label: '${volume.round()}%',
                              onChanged: widget.enabled
                                  ? (value) {
                                      update(() => volume = value);
                                      widget.onVolume(value);
                                    }
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (widget.onRate != null) _ratePicker(close: close),
                          if (widget.onSuperResolution != null)
                            _enhancementPicker(close: close),
                        ],
                      ),
                      if (widget.superResolutionMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(widget.superResolutionMessage!),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _windowButtons(close: close),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
    } finally {
      // 父浮层关闭会直接卸载其中的下拉框，不一定再发出 onClose。
      _releaseMenus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final max = widget.duration.inMilliseconds.toDouble().clamp(
      1.0,
      double.infinity,
    );
    final position = (_drag ?? widget.position.inMilliseconds.toDouble()).clamp(
      0.0,
      max,
    );
    final canSeek =
        widget.enabled &&
        widget.onSeek != null &&
        widget.duration > Duration.zero;
    return FfPlayerSurface(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FfSlider(
              semanticLabel: widget.seekLabel,
              value: position,
              max: max,
              label: ffPlaybackTime(Duration(milliseconds: position.round())),
              onChanged: canSeek
                  ? (value) => setState(() => _drag = value)
                  : null,
              // 拖动期间只预览，松手才跳转；禁用途中松手也不能提交。
              onChangeEnd: canSeek
                  ? (value) {
                      if (!widget.enabled || widget.onSeek == null) return;
                      setState(() => _drag = null);
                      widget.onSeek!(Duration(milliseconds: value.round()));
                    }
                  : null,
            ),
            const SizedBox(height: 4),
            LayoutBuilder(
              builder: (context, constraints) {
                final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
                final width = constraints.maxWidth / scale;
                final pickers = width >= 660;
                final volume = width >= 1000;
                return Row(
                  children: [
                    _button(
                      widget.playing ? widget.pauseLabel : widget.playLabel,
                      widget.playing ? FluentIcons.pause : FluentIcons.play,
                      widget.enabled ? widget.onPlayPause : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${ffPlaybackTime(Duration(milliseconds: position.round()))} / ${ffPlaybackTime(widget.duration)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (volume) ...[
                      _button(
                        widget.volume == 0 ? '取消静音' : '静音',
                        widget.volume == 0
                            ? FluentIcons.volume0
                            : FluentIcons.volume2,
                        widget.enabled
                            ? widget.onMute ??
                                  () => widget.onVolume(
                                    widget.volume == 0 ? 100 : 0,
                                  )
                            : null,
                      ),
                      SizedBox(
                        width: 92,
                        child: FfSlider(
                          semanticLabel: widget.volumeLabel,
                          value: widget.volume.clamp(0, 100),
                          max: 100,
                          label: '${widget.volume.round()}%',
                          onChanged: widget.enabled ? widget.onVolume : null,
                        ),
                      ),
                    ],
                    if (pickers && widget.onRate != null) ...[
                      const SizedBox(width: 8),
                      _ratePicker(),
                    ],
                    if (pickers && widget.onSuperResolution != null) ...[
                      const SizedBox(width: 8),
                      _enhancementPicker(),
                    ],
                    ..._windowButtons(activeOnly: width < 480),
                    // 小窗里仍保留全部操作和明确的退出按钮，不靠隐藏功能避免溢出。
                    FlyoutTarget(
                      controller: _more,
                      child: _button('更多播放选项', FluentIcons.more, _showMore),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
