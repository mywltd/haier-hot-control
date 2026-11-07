import 'package:flutter/foundation.dart';

/// 窗口背景材质。系统云母只有 Windows 11 才有；Windows 10 固定用毛玻璃。
enum WindowMaterial {
  mica('系统云母'),
  acrylic('毛玻璃');

  const WindowMaterial(this.label);

  final String label;
}

/// 毛玻璃的模糊方式。
enum AcrylicBlur {
  /// 亚克力（ACCENT_ENABLE_ACRYLICBLURBEHIND）：模糊更重。Windows 10 上拖动窗口会卡，
  /// 拖动期间临时换成普通模糊，见 `planWhileDragging`。
  acrylic('亚克力'),

  /// 普通模糊（ACCENT_ENABLE_BLURBEHIND）：更通透。只有 Windows 10 可选，Windows 11 上它是黑的。
  blur('普通模糊');

  const AcrylicBlur(this.label);

  final String label;
}

/// 毛玻璃参数：模糊方式、色调、不透明度。不透明度越高，越接近纯色背景。
@immutable
class AcrylicOptions {
  const AcrylicOptions({
    this.blur = AcrylicBlur.acrylic,
    this.tint,
    this.opacity = defaultOpacity,
  });

  static const int defaultOpacity = 75;

  /// 跟随主题时的色调，取 Windows 11 的窗口底色（同 `solidBackgroundFillColorBase`）。
  static const int lightTint = 0xF3F3F3;
  static const int darkTint = 0x202020;

  final AcrylicBlur blur;

  /// 0xRRGGBB；null 表示跟随亮 / 暗主题。
  final int? tint;

  /// 0 ~ 100。
  final int opacity;

  bool get isDefault => this == const AcrylicOptions();

  int tintFor({required bool dark}) => tint ?? (dark ? darkTint : lightTint);

  AcrylicOptions copyWith({AcrylicBlur? blur, int? opacity}) {
    return AcrylicOptions(
      blur: blur ?? this.blur,
      tint: tint,
      opacity: opacity ?? this.opacity,
    );
  }

  /// [tint] 为 null 时改回跟随主题。
  AcrylicOptions withTint(int? tint) {
    return AcrylicOptions(blur: blur, tint: tint, opacity: opacity);
  }

  Map<String, dynamic> toJson() => {
    'blur': blur.name,
    if (tint != null) 'tint': _hex(tint!),
    'opacity': opacity,
  };

  /// 字段缺失或不合法时取默认值，不抛出。
  static AcrylicOptions fromJson(Object? json) {
    if (json is! Map) {
      return const AcrylicOptions();
    }
    final opacity = json['opacity'];
    return AcrylicOptions(
      blur: AcrylicBlur.values.asNameMap()[json['blur']] ?? AcrylicBlur.acrylic,
      tint: _parseHex(json['tint']),
      // 手改的文件里可能有 1e400（解析成 Infinity），round() 会抛出。
      opacity: opacity is num && opacity.isFinite
          ? opacity.round().clamp(0, 100)
          : defaultOpacity,
    );
  }

  static String _hex(int rgb) =>
      '#${(rgb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  static int? _parseHex(Object? value) {
    if (value is! String) {
      return null;
    }
    final match = RegExp(r'^#?([0-9a-fA-F]{6})$').firstMatch(value.trim());
    return match == null ? null : int.parse(match.group(1)!, radix: 16);
  }

  @override
  bool operator ==(Object other) =>
      other is AcrylicOptions &&
      other.blur == blur &&
      other.tint == tint &&
      other.opacity == opacity;

  @override
  int get hashCode => Object.hash(blur, tint, opacity);
}
