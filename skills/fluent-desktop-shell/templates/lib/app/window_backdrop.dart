import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ffi';
import 'dart:io';
import 'dart:ui' show Color, PlatformDispatcher;

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart' as acrylic;
import 'package:win32/win32.dart'
    show
        DWMWA_SYSTEMBACKDROP_TYPE,
        DWMWINDOWATTRIBUTE,
        DwmExtendFrameIntoClientArea,
        DwmSetWindowAttribute,
        HWND,
        MARGINS,
        OsVersion,
        WindowsException;
import 'package:win32_registry/win32_registry.dart';
import 'package:window_manager/window_manager.dart';

import 'window_material.dart';

/// 测试用：假装运行在指定 build 的 Windows 上（如 19045 = Windows 10 22H2）。
@visibleForTesting
int? debugWindowsBuildOverride;

int? _build;

/// 当前 Windows 的 build 号；不是 Windows 时为 0。
int get windowsBuild => debugWindowsBuildOverride ?? (_build ??= _readBuild());

int _readBuild() {
  if (!Platform.isWindows) {
    return 0;
  }
  try {
    return OsVersion.current.build;
  } catch (_) {
    return 0;
  }
}

const int _win10v1803 = 17134; // 亚克力模糊
const int _win10v1809 = 17763; // 深色窗口边框
const int _win10v20H1 = 18985; // 深色边框属性从 19 改为 20
const int _win11 = 22000; // 云母
const int _win11v22H2 = 22523; // DWMWA_SYSTEMBACKDROP_TYPE

/// 系统云母只有 Windows 11 才有；Windows 10 只能用毛玻璃。
bool get micaSupported => windowsBuild >= _win11;

/// 毛玻璃能否选模糊方式：只有 Windows 10 1803 起。
/// Windows 11 上普通模糊（ACCENT_ENABLE_BLURBEHIND）画出来是黑的，只能用亚克力；更早的 Windows 10 没有亚克力。
bool get blurStyleSelectable =>
    windowsBuild >= _win10v1803 && windowsBuild < _win11;

/// 测试用：假装系统开着 / 关了透明效果，不读注册表。
@visibleForTesting
bool? debugBackdropOpaqueOverride;

/// 系统要求窗口不透明：关了「透明效果」，或开了高对比度。
///
/// 这时毛玻璃换成纯色：不设 accent，由界面铺一层色调（[BackdropPlan.fill]）。accent 在这种设置下
/// 怎么画是未公开行为（可能露出 Flutter 透明的底而整窗发黑，Windows 10 上未实测），自己铺色结果确定。
/// 云母不用管，DWM 自己会换成纯色。
final ValueNotifier<bool> backdropOpaque = ValueNotifier(false);

/// 重读系统设置；启动、窗口重新激活、无障碍设置变化时调用。
void refreshBackdropOpaque() {
  backdropOpaque.value = debugBackdropOpaqueOverride ?? _systemWantsOpaque();
}

bool _systemWantsOpaque() {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) {
    return false;
  }
  if (PlatformDispatcher.instance.accessibilityFeatures.highContrast) {
    return true;
  }
  try {
    return CURRENT_USER.getInt(
          'EnableTransparency',
          path: r'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize',
        ) ==
        0;
  } catch (_) {
    return false;
  }
}

const int _accentBlur = 3; // ACCENT_ENABLE_BLURBEHIND
const int _accentAcrylic = 4; // ACCENT_ENABLE_ACRYLICBLURBEHIND

/// 设置 + 主题 + 系统版本算出的实际背景。相同的方案不会重复下发。
@immutable
class BackdropPlan {
  const BackdropPlan._(
    this.material,
    this.dark,
    this.accent,
    this.gradient, {
    this.fill,
  });

  /// 实际生效的材质：系统不支持云母时总是毛玻璃。
  final WindowMaterial material;
  final bool dark;

  /// 毛玻璃的 ACCENT_STATE：4 亚克力、3 普通模糊；云母、纯色为 0。
  final int accent;

  /// 毛玻璃色调，ACCENT_POLICY.GradientColor 的 0xAABBGGRR。
  final int gradient;

  /// 界面底下要铺的不透明底色，见 [backdropOpaque]；null 表示透明，露出云母 / 毛玻璃。
  final Color? fill;

  BackdropPlan _withAccent(int accent) =>
      BackdropPlan._(material, dark, accent, gradient, fill: fill);

  @override
  bool operator ==(Object other) =>
      other is BackdropPlan &&
      other.material == material &&
      other.dark == dark &&
      other.accent == accent &&
      other.gradient == gradient &&
      other.fill == fill;

  @override
  int get hashCode => Object.hash(material, dark, accent, gradient, fill);

  @override
  String toString() =>
      'BackdropPlan(${material.name}, dark: $dark, accent: $accent, '
      'gradient: 0x${gradient.toRadixString(16).padLeft(8, '0')}, fill: $fill)';
}

/// [opaque] 默认取 [backdropOpaque]。
BackdropPlan planBackdrop({
  required WindowMaterial material,
  required AcrylicOptions acrylic,
  required bool dark,
  int? build,
  bool? opaque,
}) {
  final os = build ?? windowsBuild;
  if (material == WindowMaterial.mica && os >= _win11) {
    return BackdropPlan._(WindowMaterial.mica, dark, 0, 0);
  }
  if (opaque ?? backdropOpaque.value) {
    final fill = Color(0xFF000000 | acrylic.tintFor(dark: dark));
    return BackdropPlan._(WindowMaterial.acrylic, dark, 0, 0, fill: fill);
  }
  final accent =
      os >= _win11 || (acrylic.blur == AcrylicBlur.acrylic && os >= _win10v1803)
      ? _accentAcrylic
      : _accentBlur;
  final rgb = acrylic.tintFor(dark: dark);
  var alpha = (acrylic.opacity.clamp(0, 100) * 255 / 100).round();
  if (accent == _accentAcrylic && alpha == 0) {
    // 部分 Windows 10 上亚克力遇到全透明色调会显示异常；留 1/255，肉眼看不出差别。
    alpha = 1;
  }
  final abgr =
      alpha << 24 |
      (rgb & 0xFF) << 16 |
      (rgb >> 8 & 0xFF) << 8 |
      (rgb >> 16 & 0xFF);
  return BackdropPlan._(WindowMaterial.acrylic, dark, accent, abgr);
}

/// 拖动、缩放窗口期间用的方案。
///
/// Windows 10 1903 起亚克力在拖动时明显跟不上鼠标，期间临时换成普通模糊，松手后换回。
/// Windows 11 上实测不卡（与云母同为每次移动一帧），而且普通模糊是黑的，保持不变。
BackdropPlan planWhileDragging(BackdropPlan plan, {int? build}) {
  final os = build ?? windowsBuild;
  return os < _win11 && plan.accent == _accentAcrylic
      ? plan._withAccent(_accentBlur)
      : plan;
}

bool _micaReady = false;

/// 代替 `Window.initialize()`：flutter_acrylic 没初始化成功时 `setEffect` 永远不返回。
Future<void> initBackdrop() async {
  await acrylic.Window.initialize();
  _micaReady = true;
}

BackdropPlan? _wanted;
BackdropPlan? _applied;
Future<void> _queue = Future.value();
int? _hwnd;
_DragRelief? _dragRelief;

/// 测试用：代替真正下发（flutter_acrylic / user32）；返回 false 表示没生效，下次再试。
@visibleForTesting
Future<bool> Function(BackdropPlan plan)? debugBackdropApplier;

/// 测试用：清掉排队、已应用的方案和拖动监听。
@visibleForTesting
void debugResetBackdrop() {
  _wanted = null;
  _applied = null;
  _queue = Future.value();
  if (_dragRelief case final relief?) {
    windowManager.removeListener(relief);
  }
  _dragRelief = null;
  debugBackdropApplier = null;
  debugBackdropOpaqueOverride = null;
  backdropOpaque.value = false;
}

/// 应用窗口背景。依次执行，只应用最新一次请求；失败只记日志，下次请求时重试。
Future<void> applyBackdrop(BackdropPlan plan) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) {
    return Future.value();
  }
  _wanted = plan;
  if (windowsBuild < _win11) {
    _dragRelief ??= _DragRelief()..attach();
  }
  return _schedule();
}

Future<void> _schedule() => _queue = _queue.then((_) => _applyLatest());

Future<void> _applyLatest() async {
  final wanted = _wanted;
  if (wanted == null) {
    return;
  }
  final plan = _dragRelief?._dragging == true
      ? planWhileDragging(wanted)
      : wanted;
  if (plan == _applied) {
    return;
  }
  try {
    if (await (debugBackdropApplier ?? _applyNative)(plan)) {
      _applied = plan;
    }
  } catch (e, st) {
    developer.log('设置窗口背景失败: $e', name: 'Window', stackTrace: st);
  }
}

Future<bool> _applyNative(BackdropPlan plan) async {
  if (plan.material == WindowMaterial.mica) {
    if (!_micaReady) {
      return false;
    }
    // flutter_acrylic 切到云母前会先清掉毛玻璃（accent policy）。
    await acrylic.Window.setEffect(
      effect: acrylic.WindowEffect.mica,
      dark: plan.dark,
    );
    return true;
  }
  // 不走 flutter_acrylic：它在 Windows 11 22H2+ 把亚克力换成系统材质，色调、不透明度都调不了。
  final hwnd = HWND(Pointer.fromAddress(_hwnd ??= await windowManager.getId()));
  if (_applied?.material != WindowMaterial.acrylic) {
    _clearMica(hwnd);
  }
  _setDarkFrame(hwnd, plan.dark);
  _setAccent(hwnd, plan.accent, plan.gradient);
  return true;
}

/// 撤掉云母：系统材质设为无，边框扩展还原成 window_manager 隐藏标题栏时的 0。
void _clearMica(HWND hwnd) {
  final os = windowsBuild;
  if (os < _win11) {
    return;
  }
  if (os >= _win11v22H2) {
    _setInt(hwnd, DWMWA_SYSTEMBACKDROP_TYPE, 1); // DWMSBT_NONE
  } else {
    _setInt(hwnd, const DWMWINDOWATTRIBUTE(1029), 0); // 早期 Windows 11 的未公开云母开关
  }
  final margins = calloc<MARGINS>();
  try {
    DwmExtendFrameIntoClientArea(hwnd, margins);
  } on WindowsException {
    // 保持原样。
  } finally {
    calloc.free(margins);
  }
}

/// 窗口边框跟随亮 / 暗主题，否则深色毛玻璃外面是一圈浅色边框。
void _setDarkFrame(HWND hwnd, bool dark) {
  final os = windowsBuild;
  if (os < _win10v1809) {
    return;
  }
  _setInt(hwnd, DWMWINDOWATTRIBUTE(os >= _win10v20H1 ? 20 : 19), dark ? 1 : 0);
}

void _setInt(HWND hwnd, DWMWINDOWATTRIBUTE attribute, int value) {
  final p = calloc<Int32>()..value = value;
  try {
    DwmSetWindowAttribute(hwnd, attribute, p, sizeOf<Int32>());
  } on WindowsException {
    // 系统没有这个属性。
  } finally {
    calloc.free(p);
  }
}

final class _AccentPolicy extends Struct {
  @Int32()
  external int accentState;

  @Uint32()
  external int accentFlags;

  @Uint32()
  external int gradientColor;

  @Uint32()
  external int animationId;
}

final class _CompositionData extends Struct {
  @Int32()
  external int attribute;

  external Pointer<_AccentPolicy> data;

  @Size()
  external int size;
}

/// 未公开的 user32!SetWindowCompositionAttribute，Windows 10 起一直可用。
final _setWindowCompositionAttribute = DynamicLibrary.open('user32.dll')
    .lookupFunction<
      Int32 Function(Pointer, Pointer<_CompositionData>),
      int Function(Pointer, Pointer<_CompositionData>)
    >('SetWindowCompositionAttribute');

void _setAccent(HWND hwnd, int accent, int gradient) {
  final policy = calloc<_AccentPolicy>()
    ..ref.accentState = accent
    // 2：使用 GradientColor 作色调。
    ..ref.accentFlags = 2
    ..ref.gradientColor = gradient;
  final data = calloc<_CompositionData>()
    ..ref.attribute = 19 // WCA_ACCENT_POLICY
    ..ref.data = policy
    ..ref.size = sizeOf<_AccentPolicy>();
  try {
    _setWindowCompositionAttribute(hwnd, data);
  } finally {
    calloc.free(data);
    calloc.free(policy);
  }
}

/// 跟踪窗口是否正在被拖动 / 缩放，见 [planWhileDragging]。
///
/// window_manager 在 WM_MOVING / WM_SIZING 时发 move / resize，WM_EXITSIZEMOVE 时发 moved / resized。
class _DragRelief with WindowListener {
  bool _dragging = false;

  void attach() => windowManager.addListener(this);

  void _set(bool dragging) {
    if (_dragging == dragging) {
      return;
    }
    _dragging = dragging;
    unawaited(_schedule());
  }

  @override
  void onWindowMove() => _set(true);

  @override
  void onWindowMoved() => _set(false);

  @override
  void onWindowResize() => _set(true);

  @override
  void onWindowResized() => _set(false);
}
