import 'package:fluent_ui/fluent_ui.dart';
import 'package:system_theme/system_theme.dart';

/// 先取得系统色再显示第一帧，避免启动时先蓝后变色。
Future<AccentColor> loadSystemAccent() async {
  final color = SystemAccentColor(Colors.blue);
  try {
    await color.load();
    return fluentAccent(color);
  } catch (error) {
    debugPrint('读取 Windows 强调色失败，使用默认色：$error');
    return Colors.blue;
  } finally {
    // load 会隐式订阅；持续监听由 App 统一持有，避免留下第二份监听。
    color.dispose();
  }
}

Stream<AccentColor> get systemAccentChanges =>
    SystemTheme.onChange.map(fluentAccent);

/// 保留 Windows 给出的完整色阶，让亮暗主题和悬停状态各自取合适的颜色。
AccentColor fluentAccent(SystemAccentColor color) => AccentColor.swatch({
  'darkest': color.darkest,
  'darker': color.darker,
  'dark': color.dark,
  'normal': color.accent,
  'light': color.light,
  'lighter': color.lighter,
  'lightest': color.lightest,
});
