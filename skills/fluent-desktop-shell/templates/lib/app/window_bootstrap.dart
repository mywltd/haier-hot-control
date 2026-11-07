import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart' show Window;
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import 'desktop_session.dart';
import 'dwm_corners.dart';
import 'theme.dart';
import 'window_backdrop.dart';

/// 启动卡片与主窗口的大小（逻辑像素）。
const Size kSplashSize = Size(440, 320);
const Size kMainWindowSize = Size(1280, 720);
const Size kMainWindowMinSize = Size(960, 640);

bool get isDesktopWindow {
  if (kIsWeb) {
    return false;
  }
  return {
    TargetPlatform.windows,
    TargetPlatform.linux,
    TargetPlatform.macOS,
  }.contains(defaultTargetPlatform);
}

/// 在第一帧之前把窗口设成屏幕中央的启动卡片。
///
/// 原生窗口创建时是隐藏的，Flutter 画出第一帧后才显示（windows/runner/flutter_window.cpp），
/// 所以这里设的大小和位置在显示前就已生效，不会先出现在屏幕左上角。
Future<void> bootstrapDesktopWindow() async {
  if (!isDesktopWindow) {
    return;
  }

  await initBackdrop();
  if (defaultTargetPlatform == TargetPlatform.windows) {
    await Window.hideWindowControls();
  }

  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow();
  await windowManager.setTitleBarStyle(
    TitleBarStyle.hidden,
    windowButtonVisibility: false,
  );
  await windowManager.setTitle(kAppTitle);
  await windowManager.setResizable(false);
  await windowManager.setMaximizable(false);
  await _place(kSplashSize, await _workArea());
  if (defaultTargetPlatform == TargetPlatform.windows) {
    try {
      requestRoundCorners(await windowManager.getId());
    } catch (_) {}
  }
  await DesktopSession.bootstrap();
}

/// 启动卡片结束：恢复可调整大小，在启动卡片所在的屏幕上居中放大为主窗口。
///
/// 全程保持窗口可见：窗口隐藏时 Flutter 停止出帧，隐藏状态下改大小拿不到新尺寸的画面。
Future<void> enterMainWindow() async {
  if (!isDesktopWindow) {
    return;
  }
  final splash = await windowManager.getBounds();
  final work = await _workArea(splash.center);
  await windowManager.setResizable(true);
  await windowManager.setMaximizable(true);
  await windowManager.setMinimumSize(_fit(kMainWindowMinSize, work));
  await _place(kMainWindowSize, work);
}

/// 屏幕可用区域（不含任务栏）：优先取包含 [near] 的屏幕，否则主屏幕；取不到时为 null。
Future<Rect?> _workArea([Offset? near]) async {
  try {
    Rect area(Display d) =>
        (d.visiblePosition ?? Offset.zero) & (d.visibleSize ?? d.size);
    final displays = await screenRetriever.getAllDisplays();
    if (near != null) {
      for (final d in displays) {
        if (area(d).contains(near)) {
          return area(d);
        }
      }
    }
    return area(await screenRetriever.getPrimaryDisplay());
  } catch (_) {
    return null;
  }
}

/// 小屏幕上缩小，四周至少留 24 边距。
Size _fit(Size want, Rect? work) {
  if (work == null) {
    return want;
  }
  return Size(
    math.max(0, math.min(want.width, work.width - 48)),
    math.max(0, math.min(want.height, work.height - 48)),
  );
}

/// 在可用区域中央放置窗口；取不到屏幕信息时退回 window_manager 的居中。
Future<void> _place(Size want, Rect? work) async {
  if (work == null) {
    await windowManager.setSize(want);
    await windowManager.center();
    return;
  }
  final size = _fit(want, work);
  await windowManager.setBounds(
    Rect.fromCenter(
      center: work.center,
      width: size.width,
      height: size.height,
    ),
  );
}
