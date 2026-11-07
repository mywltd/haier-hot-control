// Explicit visual check: flutter test tool/capture_ui_test.dart
// Uses in-memory demo data, real fonts and a simulated desktop backdrop.
// This explicit flutter_test entry point lives outside the default test suite.
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haier_heat/app/app.dart';
import 'package:haier_heat/app/desktop_window.dart';
import 'package:haier_heat/app/shell_settings.dart';
import 'package:haier_heat/app/window_backdrop.dart';
import 'package:haier_heat/app/window_material.dart';
import 'package:haier_heat/haier/haier_state.dart';

final _boundary = GlobalKey();
final _out = Directory('artifacts/ui');

Future<void> _font(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final file in files) {
    loader.addFont(
      Future.value(ByteData.sublistView(File(file).readAsBytesSync())),
    );
  }
  await loader.load();
}

Future<void> _shot(WidgetTester tester, String name) async {
  expect(tester.takeException(), isNull);
  await tester.runAsync(() async {
    final boundary =
        _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.25);
    try {
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File('${_out.path}/$name.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    _out.createSync(recursive: true);
    for (final family in ['Microsoft YaHei UI', 'Microsoft YaHei']) {
      await _font(family, [
        r'C:\Windows\Fonts\msyh.ttc',
        r'C:\Windows\Fonts\msyhbd.ttc',
      ]);
    }
    await _font('Segoe UI', [r'C:\Windows\Fonts\segoeui.ttf']);
    for (final family in ['SegoeIcons', 'FluentIcons']) {
      await (FontLoader('packages/fluent_ui/$family')
            ..addFont(rootBundle.load('packages/fluent_ui/fonts/$family.ttf')))
          .load();
    }
  });

  for (final brightness in Brightness.values) {
    for (final size in [const Size(960, 640), const Size(1280, 720)]) {
      testWidgets('${brightness.name} ${size.width}', (tester) async {
        final previousShadows = debugDisableShadows;
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        debugDisableShadows = false;
        debugDisableDesktopIntegration = true;
        debugResetBackdrop();
        debugWindowsBuildOverride = 26100;
        debugBackdropOpaqueOverride = false;
        debugBackdropApplier = (_) async => true;
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        final state = HaierState();
        final suffix = '${brightness.name}_${size.width.round()}';
        try {
          await ShellSettings.instance.setThemeMode('system');
          await ShellSettings.instance.setWindowMaterial(WindowMaterial.mica);
          await state.selectDevice(state.devices.first.id);
          await tester.pumpWidget(
            RepaintBoundary(
              key: _boundary,
              child: ColoredBox(
                color: brightness == Brightness.light
                    ? const Color(0xFFF1EDF4)
                    : const Color(0xFF25232A),
                child: App(state: state),
              ),
            ),
          );
          await tester.runAsync(
            () => precacheImage(
              const AssetImage('assets/app_icon.ico'),
              tester.element(find.byType(App)),
            ),
          );
          await tester.pumpAndSettle();
          await _shot(tester, 'devices_$suffix');
          for (final page in [
            ('控制', 'control'),
            ('账号', 'account'),
            ('设置', 'settings'),
          ]) {
            await tester.tap(find.text(page.$1).first);
            await tester.pumpAndSettle();
            await _shot(tester, '${page.$2}_$suffix');
            if (page.$2 == 'control') {
              await tester.drag(
                find.byType(ListView).last,
                const Offset(0, -560),
              );
              await tester.pumpAndSettle();
              await _shot(tester, 'energy_$suffix');
            }
          }
          if (size.width == 960) {
            await ShellSettings.instance.setWindowMaterial(
              WindowMaterial.acrylic,
            );
            await tester.pumpAndSettle();
            await _shot(tester, 'acrylic_win11_$suffix');
            debugWindowsBuildOverride = 19045;
            await ShellSettings.instance.setWindowMaterial(
              WindowMaterial.acrylic,
            );
            await tester.pumpAndSettle();
            await _shot(tester, 'acrylic_win10_$suffix');
          }
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          state.dispose();
          tester.view.reset();
          tester.platformDispatcher.clearPlatformBrightnessTestValue();
          debugDefaultTargetPlatformOverride = null;
          debugDisableShadows = previousShadows;
          debugDisableDesktopIntegration = false;
          debugWindowsBuildOverride = null;
          debugResetBackdrop();
        }
      });
    }
  }
}
