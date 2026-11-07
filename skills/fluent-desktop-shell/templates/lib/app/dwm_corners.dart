import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Windows 11：要求系统给窗口画圆角。不可调整大小的窗口默认可能是直角。
void requestRoundCorners(int hwnd) {
  final pref = calloc<Int32>()..value = DWMWCP_ROUND;
  try {
    DwmSetWindowAttribute(
      HWND(Pointer.fromAddress(hwnd)),
      DWMWA_WINDOW_CORNER_PREFERENCE,
      pref,
      sizeOf<Int32>(),
    );
  } on WindowsException {
    // Windows 10 没有这个属性，保持默认。
  } finally {
    calloc.free(pref);
  }
}
