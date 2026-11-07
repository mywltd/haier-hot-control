// 复制到新项目后，把 your_app 换成 pubspec.yaml 里的 name。
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:your_app/app/app.dart';
import 'package:your_app/app/shell_settings.dart';
import 'package:your_app/app/theme.dart';
import 'package:your_app/app/window_backdrop.dart';
import 'package:your_app/app/window_material.dart';

void main() {
  testWidgets('壳子：侧栏、切页、设置页在最小窗口下可用', (tester) async {
    // 窗口最小尺寸（window_bootstrap 的 kMainWindowMinSize），最容易溢出。
    tester.view.physicalSize = const Size(960, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // 固定成 Windows 11：设置页内容随系统版本变（Windows 10 多一张毛玻璃卡片），不固定的话结果取决于跑测试的机器。
    debugWindowsBuildOverride = 26100;
    addTearDown(() => debugWindowsBuildOverride = null);

    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();
    expect(find.text(kAppTitle), findsWidgets);
    expect(find.text('跟随系统'), findsOneWidget);

    await tester.tap(find.text('列表').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextBox).first, '不存在');
    await tester.pumpAndSettle();
    expect(find.text('没有匹配的条目'), findsOneWidget);

    await tester.tap(find.text('设置').first);
    await tester.pumpAndSettle();
    expect(find.text('关闭主窗口时'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('窗口材质：Windows 10 固定毛玻璃，Windows 11 可切换', (tester) async {
    tester.view.physicalSize = const Size(960, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => debugWindowsBuildOverride = null);
    ComboBox<WindowMaterial> materialBox() => tester
        .widget<ComboBox<WindowMaterial>>(find.byType(ComboBox<WindowMaterial>));

    debugWindowsBuildOverride = 19045; // Windows 10 22H2
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置').first);
    await tester.pumpAndSettle();
    expect(materialBox().onChanged, isNull, reason: '没有云母，下拉框禁用');
    expect(materialBox().value, WindowMaterial.acrylic);
    expect(find.text('毛玻璃效果'), findsOneWidget);
    expect(find.text('模糊方式'), findsOneWidget);

    debugWindowsBuildOverride = 26100; // Windows 11 24H2
    await ShellSettings.instance.setWindowMaterial(WindowMaterial.mica);
    await tester.pumpAndSettle();
    expect(materialBox().onChanged, isNotNull);
    expect(find.text('毛玻璃效果'), findsNothing);
    await ShellSettings.instance.setWindowMaterial(WindowMaterial.acrylic);
    await tester.pumpAndSettle();
    expect(find.text('毛玻璃效果'), findsOneWidget);
    expect(find.text('模糊方式'), findsNothing, reason: 'Windows 11 只能用亚克力');
    expect(tester.takeException(), isNull);
  });
}
