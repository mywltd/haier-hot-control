import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haier_heat/app/app.dart';
import 'package:haier_heat/app/desktop_window.dart';
import 'package:haier_heat/app/shell_settings.dart';
import 'package:haier_heat/app/theme.dart';
import 'package:haier_heat/app/window_backdrop.dart';
import 'package:haier_heat/app/window_material.dart';
import 'package:haier_heat/haier/haier_state.dart';
import 'package:haier_heat/shell/close_prompt.dart';
import 'package:haier_heat/shell/nav_sidebar.dart';
import 'package:haier_heat/widgets/ff_combo_box.dart';

import 'support/fake_haier_api.dart';

void main() {
  setUp(() async {
    debugDisableDesktopIntegration = true;
    debugResetBackdrop();
    debugWindowsBuildOverride = 26100;
    debugBackdropOpaqueOverride = false;
    debugBackdropApplier = (_) async => true;
    await ShellSettings.instance.setThemeMode('system');
    await ShellSettings.instance.setWindowMaterial(WindowMaterial.mica);
    await ShellSettings.instance.setAcrylic(const AcrylicOptions());
    await ShellSettings.instance.setCloseAction(CloseAction.ask);
  });
  tearDown(() {
    debugDisableDesktopIntegration = false;
    debugWindowsBuildOverride = null;
    debugResetBackdrop();
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    HaierState? state,
    Brightness brightness = Brightness.light,
  }) async {
    // 材质队列要在当前 widget 测试的 FakeAsync zone 内重建。
    final applier = debugBackdropApplier;
    final opaque = debugBackdropOpaqueOverride;
    debugResetBackdrop();
    debugBackdropApplier = applier;
    debugBackdropOpaqueOverride = opaque;
    tester.view.physicalSize = const Size(960, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.platformBrightnessTestValue = brightness;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(App(state: state ?? HaierState()));
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    testWidgets('最小窗口：${brightness.name} 主题下四个页面、独立滚动与切页可用', (tester) async {
      await pumpApp(tester, brightness: brightness);
      expect(find.text(kAppTitle), findsOneWidget);
      expect(kSidebarWidth, 72);
      expect(tester.widget<TitleBar>(find.byType(TitleBar)).height, 48);
      expect(find.text('演示模式'), findsOneWidget);
      expect(find.text('主卧采暖'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('查看控制').first);
      await tester.pumpAndSettle();
      expect(find.text('温度与运行'), findsOneWidget);
      await tester.drag(find.byType(ListView).last, const Offset(0, -480));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('账号').first);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('设置').first);
      await tester.pumpAndSettle();
      expect(find.text('窗口材质'), findsOneWidget);
      expect(find.text('关闭主窗口时'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('账号').first);
      await tester.pumpAndSettle();
      expect(find.byType(PasswordBox), findsOneWidget);
      await tester.tap(find.text('登录').last);
      await tester.pumpAndSettle();
      expect(find.text('请输入 11 位手机号和密码。'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('跟随系统').first);
      await tester.pumpAndSettle();
      expect(
        FluentTheme.of(tester.element(find.byType(ScaffoldPage))).brightness,
        brightness == Brightness.light ? Brightness.dark : Brightness.light,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('窗口材质：Windows 10 固定毛玻璃，Windows 11 可切换', (tester) async {
    debugWindowsBuildOverride = 19045;
    await pumpApp(tester);
    await tester.tap(find.text('设置').first);
    await tester.pumpAndSettle();
    FfComboBox<WindowMaterial> materialBox() =>
        tester.widget(find.byType(FfComboBox<WindowMaterial>));
    expect(materialBox().onChanged, isNull);
    expect(materialBox().value, WindowMaterial.acrylic);
    expect(find.text('毛玻璃效果'), findsOneWidget);
    expect(find.text('模糊方式'), findsOneWidget);
    expect(tester.takeException(), isNull);

    debugWindowsBuildOverride = 26100;
    await ShellSettings.instance.setWindowMaterial(WindowMaterial.mica);
    await tester.pumpAndSettle();
    expect(materialBox().onChanged, isNotNull);
    expect(find.text('毛玻璃效果'), findsNothing);
    await ShellSettings.instance.setWindowMaterial(WindowMaterial.acrylic);
    await tester.pumpAndSettle();
    expect(find.text('毛玻璃效果'), findsOneWidget);
    expect(find.text('模糊方式'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('系统关闭透明效果时铺纯色，保留当前页面和输入', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await ShellSettings.instance.setWindowMaterial(WindowMaterial.acrylic);
      final plans = <BackdropPlan>[];
      debugBackdropApplier = (plan) async {
        plans.add(plan);
        return true;
      };
      await pumpApp(tester);
      await tester.tap(find.text('账号').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('login-phone')),
        '13800138000',
      );
      debugBackdropOpaqueOverride = true;
      refreshBackdropOpaque();
      await tester.pumpAndSettle();
      expect(plans.last.fill, isNotNull);
      expect(find.text('13800138000'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('登录后进入设备页，卡片开关使用对应设备 ID', (tester) async {
    final api = FakeHaierApi();
    final state = HaierState(api: api);
    await pumpApp(tester, state: state);
    await tester.tap(find.text('登录账号'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('login-phone')),
      '13800138000',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('login-password')),
        matching: find.byType(TextBox),
      ),
      'test-password',
    );
    await tester.tap(find.text('登录').last);
    await tester.pumpAndSettle();
    expect(find.text('真实设备 A'), findsOneWidget);
    expect(find.text('主卧采暖'), findsNothing);
    await state.selectDevice('a');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('device-power-b')));
    await tester.pumpAndSettle();
    expect(api.commands.single.$1, 'b');
    expect(api.commands.single.$2, {'onOffStatus': 'true'});
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('关闭确认可取消，也可记住托盘选择', (tester) async {
    await pumpApp(tester);
    final context = tester.element(find.byType(ScaffoldPage));
    final result = showClosePrompt(context, ShellSettings.instance);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text('最小化到托盘').last);
    await tester.pumpAndSettle();
    expect(await result, CloseAction.tray);
    expect(ShellSettings.instance.closeAction, CloseAction.tray);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('温度只在点击应用后发送，控件有可访问标签', (tester) async {
    final semantics = tester.ensureSemantics();
    final api = FakeHaierApi();
    final state = HaierState(api: api);
    await state.login('13800138000', 'test-password');
    await state.selectDevice('a');
    await pumpApp(tester, state: state);
    await tester.tap(find.text('控制').first);
    await tester.pumpAndSettle();
    final slider = find.byKey(const ValueKey('target-temperature'));
    await tester.drag(slider, const Offset(45, 0));
    await tester.pumpAndSettle();
    expect(api.commands, isEmpty);
    expect(find.bySemanticsLabel(RegExp('目标温度')), findsWidgets);
    final value = tester.widget<Slider>(slider).value.round();
    await tester.tap(find.text('应用温度'));
    await tester.pumpAndSettle();
    expect(api.commands.single.$1, 'a');
    expect(api.commands.single.$2, {'targetTemperature': '$value'});
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
    semantics.dispose();
  });
}
