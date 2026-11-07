import 'package:fluent_ui/fluent_ui.dart';

/// 保留 Fluent 滑块的绘制和输入，用单一节点提供完整的读屏操作。
/// Flutter 3.47 的 OverlayPortal 在 MergeSemantics 中会产生脱离父节点的提示节点，
/// Windows AXTree 因而持续报错；数值提示的语义由此节点统一提供。
class FfSlider extends StatelessWidget {
  const FfSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.label,
    this.semanticLabel,
    this.onChangeStart,
    this.onChangeEnd,
    this.focusNode,
    this.autofocus = false,
    this.vertical = false,
    this.style,
    this.mouseCursor = MouseCursor.defer,
  }) : assert(min <= max),
       assert(value >= min && value <= max),
       assert(divisions == null || divisions > 0);

  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String? label;
  final String? semanticLabel;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool vertical;
  final SliderThemeData? style;
  final MouseCursor mouseCursor;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Semantics(
      label: semanticLabel,
      child: Overlay.wrap(
        alwaysSizeToContent: true,
        clipBehavior: Clip.none,
        child: Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: label,
          onChanged: onChanged,
          onChangeStart: onChangeStart,
          onChangeEnd: onChangeEnd,
          focusNode: focusNode,
          autofocus: autofocus,
          vertical: vertical,
          style: style,
          mouseCursor: mouseCursor,
        ),
      ),
    ),
  );
}
