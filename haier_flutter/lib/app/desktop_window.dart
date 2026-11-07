import 'dart:ffi';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart' as native;

/// 由启动流程绑定当前窗口，widget 测试只构建界面时不触碰 nativeapi。
native.Window? _window;

native.Window? get maybeDesktopWindow => _window;

native.Window get desktopWindow => _window ?? (throw StateError('桌面窗口尚未初始化'));

Future<void> bindDesktopWindow() async {
  if (_window != null) return;
  // 首帧前窗口尚未激活，getCurrent() 会返回 null；由 runner 提供所属 HWND。
  final hwnd = await const MethodChannel('haier_heat/window')
      .invokeMethod<int>('getWindowHandle');
  if (hwnd != null && hwnd != 0) {
    _window = native.Window.createWithNativeWindow(
      Pointer<Void>.fromAddress(hwnd),
    );
  }
  if (_window == null) throw StateError('未找到 Flutter 原生窗口');
}

@visibleForTesting
bool debugDisableDesktopIntegration = false;

bool get desktopIntegrationEnabled => !debugDisableDesktopIntegration;

/// nativeapi 的同步关闭回调可能在 Dart FFI 栈内销毁 engine；交回平台消息循环。
Future<void> destroyDesktopWindow() =>
    const MethodChannel('haier_heat/window')
        .invokeMethod<void>('destroyWindow');
