import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';

/// 放在视频 Stack 内；替换消息时重新计时，离开播放器时一并移除。
class FfPlayerToast extends StatefulWidget {
  const FfPlayerToast({
    super.key,
    required this.message,
    this.severity = InfoBarSeverity.info,
    this.duration = const Duration(seconds: 4),
  });
  final String message;
  final InfoBarSeverity severity;
  final Duration duration;
  @override
  State<FfPlayerToast> createState() => _FfPlayerToastState();
}

class _FfPlayerToastState extends State<FfPlayerToast> {
  Timer? _timer;
  bool _visible = true;

  void _restart() {
    _timer?.cancel();
    _visible = true;
    _timer = Timer(widget.duration, () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didUpdateWidget(FfPlayerToast oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message != widget.message ||
        oldWidget.severity != widget.severity) {
      _restart();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 160),
      child: !_visible
          ? const SizedBox.shrink()
          : Semantics(
              liveRegion: true,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: InfoBar(
                  title: Text(widget.message),
                  severity: widget.severity,
                ),
              ),
            ),
    ),
  );
}
