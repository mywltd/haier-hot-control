import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart' show Window;
import 'package:screen_retriever/screen_retriever.dart' as screens;
import 'package:window_manager/window_manager.dart' as native;

import 'desktop_session.dart';
import 'desktop_window.dart';
import 'dwm_corners.dart';
import 'theme.dart';
import 'window_backdrop.dart';

const Size kSplashSize = Size(440, 320);
const Size kMainWindowSize = Size(1280, 720);
const Size kMainWindowMinSize = Size(960, 640);

bool get isDesktopWindow =>
    !kIsWeb &&
    desktopIntegrationEnabled &&
    defaultTargetPlatform == TargetPlatform.windows;

/// 第一帧前定位启动卡片；runner 在 Flutter 画好第一帧后显示窗口。
Future<void> bootstrapDesktopWindow() async {
  if (!isDesktopWindow) return;
  await bindDesktopWindow();
  await initBackdrop();
  final window = desktopWindow;
  window.titleBarStyle = native.TitleBarStyle.hidden;
  window.isWindowControlButtonsVisible = false;
  window.title = kAppTitle;
  window.isResizable = false;
  window.isMaximizable = false;
  _place(kSplashSize, _workArea());
  // nativeapi 设置隐藏标题栏时会恢复 WS_SYSMENU；最后再去掉系统按钮。
  await Window.hideWindowControls();
  requestRoundCorners(window.nativeObject.address);
  await DesktopSession.bootstrap();
}

/// 主界面在可见状态下放大，避免隐藏时 Flutter 停止出帧。
Future<void> enterMainWindow() async {
  if (!isDesktopWindow) return;
  final window = desktopWindow;
  final work = _workArea(window.bounds.toRect().center);
  window.isResizable = true;
  window.isMaximizable = true;
  window.minimumSize = _fit(kMainWindowMinSize, work).toNative();
  _place(kMainWindowSize, work);
  await Window.hideWindowControls();
}

Rect? _workArea([Offset? near]) {
  try {
    final manager = screens.DisplayManager.instance;
    final displays = manager.getAll();
    try {
      if (near != null) {
        for (final display in displays) {
          final area = display.workArea.toRect();
          if (area.contains(near)) return area;
        }
      }
      for (final display in displays) {
        if (display.isPrimary) return display.workArea.toRect();
      }
      return displays.isEmpty ? null : displays.first.workArea.toRect();
    } finally {
      for (final display in displays) {
        display.dispose();
      }
    }
  } catch (_) {
    return null;
  }
}

Size _fit(Size desired, Rect? work) => work == null
    ? desired
    : Size(
        math.max(0, math.min(desired.width, work.width - 48)),
        math.max(0, math.min(desired.height, work.height - 48)),
      );

void _place(Size desired, Rect? work) {
  final window = desktopWindow;
  if (work == null) {
    window.setSize(desired.toNative(), false);
    window.center();
    return;
  }
  final size = _fit(desired, work);
  window.bounds = Rect.fromCenter(
    center: work.center,
    width: size.width,
    height: size.height,
  ).toNative();
}
