// 临时截图测试：用真实字体把界面渲染成 PNG，输出到 %TEMP%\ui_shots。
// 用法见 SKILL.md。复制到 test/zz_scratch_ui_shots_test.dart，用完删除，不要提交。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// TODO: 换成要截图的应用入口。
import 'package:your_app/app/app.dart';
import 'package:your_app/app/window_backdrop.dart';

/// TODO: 要截的侧栏页面（标签文字 → 文件名）。
const _pages = [('首页', 'home'), ('设置', 'settings')];
// TODO: WindBellEcho 使用 assets/tray_icon.ico；通用外壳使用下面的路径。
const _appIcon = 'assets/app_icon.ico';

/// 逻辑尺寸 × 缩放：1180×740 @125% ≈ 常见 1080p 笔记本上的窗口。
const _logical = Size(1180, 740);
const _dpr = 1.25;

final _out = Directory('${Directory.systemTemp.path}\\ui_shots');
final _boundary = GlobalKey();

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(
      Future.value(ByteData.sublistView(File(f).readAsBytesSync())),
    );
  }
  await loader.load();
}

Future<void> _loadAssetFont(String family, String asset) async {
  await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
}

/// 整个窗口截图。
Future<void> _shot(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final b =
        _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await b.toImage(pixelRatio: _dpr);
    try {
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File('${_out.path}\\$name.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

/// 局部放大截图（3 倍），看侧栏、按钮状态等细节。[rect] 为逻辑像素。
Future<void> _crop(WidgetTester tester, String name, Rect rect) async {
  const scale = 3.0;
  await tester.runAsync(() async {
    final b =
        _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final full = await b.toImage(pixelRatio: scale);
    try {
      final src = Rect.fromLTWH(
        rect.left * scale,
        rect.top * scale,
        rect.width * scale,
        rect.height * scale,
      );
      final recorder = ui.PictureRecorder();
      Canvas(recorder)
          .drawImageRect(full, src, Offset.zero & src.size, Paint());
      final picture = recorder.endRecording();
      try {
        final image = await picture.toImage(
          src.width.round(),
          src.height.round(),
        );
        try {
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          File('${_out.path}\\$name.png')
              .writeAsBytesSync(png!.buffer.asUint8List());
        } finally {
          image.dispose();
        }
      } finally {
        picture.dispose();
      }
    } finally {
      full.dispose();
    }
  });
}

/// 透明窗口在测试里没有云母，垫一层近似的渐变底色，否则看不出层次。
Widget _framed(Brightness brightness, Widget app) {
  final colors = brightness == Brightness.light
      ? const [Color(0xFFF3EAEE), Color(0xFFEDE6EF)]
      : const [Color(0xFF221E24), Color(0xFF1C1B22)];
  return RepaintBoundary(
    key: _boundary,
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors),
              ),
            ),
          ),
          app,
        ],
      ),
    ),
  );
}

Future<void> _capture(WidgetTester tester, Brightness brightness) async {
  final suffix = brightness.name;
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  tester.view.physicalSize = _logical * _dpr;
  tester.view.devicePixelRatio = _dpr;
  addTearDown(tester.view.reset);
  final previousPlatform = debugDefaultTargetPlatformOverride;
  final previousShadows = debugDisableShadows;
  final previousBuild = debugWindowsBuildOverride;
  // MethodChannel mock 不覆盖 user32 FFI；每个测试重建材质队列并跳过原生下发。
  debugResetBackdrop();
  debugBackdropApplier = (_) async => true;
  debugWindowsBuildOverride = 26100;
  debugBackdropOpaqueOverride = false;
  debugDisableShadows = false;
  // Windows 平台：WindowsIcon 才会用 Segoe 图标，标题栏按钮才会显示。必须在测试结束前还原。
  debugDefaultTargetPlatformOverride = TargetPlatform.windows;
  try {
    // TODO: 业务应用在这里准备内存数据；WindBellEcho 调 AppContext.debugCreate()。
    // 不调用 main()、bootstrap()、load() 或 startServices()，避免读取真实配置或连接后台。
    await tester.pumpWidget(_framed(brightness, const App()));
    // 图片第一次解码是异步的，不预先加载的话第一张截图里没有标题栏图标。
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage(_appIcon),
        tester.element(find.byType(App)),
      );
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _shot(tester, '${_pages.first.$2}_$suffix');

    // 悬停态：鼠标移到第二个侧栏项上，放大截取侧栏。
    final mouse = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text(_pages.last.$1).first));
    await tester.pumpAndSettle();
    await _crop(tester, 'sidebar_$suffix', const Rect.fromLTWH(0, 0, 160, 330));
    await mouse.removePointer();
    await tester.pumpAndSettle();

    for (final (label, name) in _pages.skip(1)) {
      await tester.tap(find.text(label).first);
      // 动画中间帧：按需打开。
      // await tester.pump(); await tester.pump(const Duration(milliseconds: 120));
      // await _shot(tester, '${name}_120ms_$suffix');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _shot(tester, '${name}_$suffix');
    }
  } finally {
    try {
      // 先卸载监听者，再还原共享的材质状态，避免清理时触发下一次下发。
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    } finally {
      debugResetBackdrop();
      debugWindowsBuildOverride = previousBuild;
      debugDefaultTargetPlatformOverride = previousPlatform;
      debugDisableShadows = previousShadows;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    _out.createSync(recursive: true);
    // 测试环境没有这些插件：返回 null，避免 MissingPluginException。
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in [
      'window_manager',
      'com.alexmercerind/flutter_acrylic',
      'tray_manager',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(channel),
        (_) async => null,
      );
    }
    // 默认测试字体是方块；换成系统里的雅黑 / Segoe UI 和 fluent_ui 自带的图标字体。
    const fonts = r'C:\Windows\Fonts';
    await _loadFont('Microsoft YaHei UI', [
      '$fonts\\msyh.ttc',
      '$fonts\\msyhbd.ttc',
    ]);
    await _loadFont('Microsoft YaHei', [
      '$fonts\\msyh.ttc',
      '$fonts\\msyhbd.ttc',
    ]);
    await _loadFont('Segoe UI', ['$fonts\\segoeui.ttf']);
    await _loadAssetFont(
      'packages/fluent_ui/SegoeIcons',
      'packages/fluent_ui/fonts/SegoeIcons.ttf',
    );
    await _loadAssetFont(
      'packages/fluent_ui/FluentIcons',
      'packages/fluent_ui/fonts/FluentIcons.ttf',
    );
  });

  testWidgets('light', (tester) => _capture(tester, Brightness.light));
  testWidgets('dark', (tester) => _capture(tester, Brightness.dark));
}
