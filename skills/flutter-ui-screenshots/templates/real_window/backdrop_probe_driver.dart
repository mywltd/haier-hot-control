import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:window_manager/window_manager.dart';

import 'app/desktop_session.dart';
import 'app/shell_settings.dart';
import 'app/theme.dart';
import 'app/window_backdrop.dart';
import 'app/window_material.dart';

/// 窗口材质探针的驱动：只在环境变量 BACKDROP_PROBE_DIR 存在时运行（backdrop_probe.ps1 会设）。
/// 在演示工程 main.dart 的 `runApp(...)` 之后调用 `runBackdropProbeDriver();`，用完删掉，不要提交。
///
/// 脚本写 cmd_N.json，这里照做后写 done_N。改设置走 ShellSettings，与设置页同一条路径。
/// PROBE_WINDOWS_BUILD（如 19045）在第一帧前生效，用来在 Windows 11 上走 Windows 10 的代码分支。
void runBackdropProbeDriver() {
  final env = Platform.environment;
  final dir = env['BACKDROP_PROBE_DIR'];
  if (dir == null) {
    return;
  }
  final build = int.tryParse(env['PROBE_WINDOWS_BUILD'] ?? '');
  if (build != null) {
    // ignore: invalid_use_of_visible_for_testing_member
    debugWindowsBuildOverride = build;
  }
  unawaited(_drive(dir));
}

Future<void> _drive(String dir) async {
  final log = File('$dir${Platform.pathSeparator}driver.log');
  void write(String line) => log.writeAsStringSync(
    '${DateTime.now().toIso8601String()} $line\n',
    mode: FileMode.append,
    flush: true,
  );
  File path(String name) => File('$dir${Platform.pathSeparator}$name');
  final settings = ShellSettings.instance;
  windowManager.addListener(_EventLog(write));

  // 等启动卡片结束、主窗口放大居中。
  await Future<void>.delayed(const Duration(seconds: 3));
  write(
    'ready build=$windowsBuild mica=$micaSupported '
    'material=${settings.windowMaterial.name} acrylic=${settings.acrylic.toJson()}',
  );
  path('ready').writeAsStringSync('1');

  for (var n = 1; ; n++) {
    final cmd = path('cmd_$n.json');
    while (!cmd.existsSync()) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    final json = jsonDecode(cmd.readAsStringSync()) as Map<String, dynamic>;
    cmd.deleteSync();
    switch (json['op']) {
      case 'material':
        await settings.setWindowMaterial(
          WindowMaterial.values.byName(json['value'] as String),
        );
        write('cmd $n material ${settings.windowMaterial.name}');
      case 'acrylic':
        final value = Map<String, dynamic>.from(json['value'] as Map);
        final merged = {...settings.acrylic.toJson(), ...value};
        await settings.setAcrylic(
          AcrylicOptions.fromJson(merged),
          persist: json['persist'] != false,
        );
        write('cmd $n acrylic ${settings.acrylic.toJson()}');
      case 'theme':
        // 按侧栏的主题按钮：同一个 AppThemeController，App 会重算窗口背景。
        final theme = _findThemeController();
        theme?.toggle();
        write('cmd $n theme -> ${theme?.mode.name ?? 'AppThemeScope 未找到'}');
      case 'hide':
        await DesktopSession.instance.hideToTray();
        write('cmd $n hide');
      case 'show':
        await DesktopSession.instance.showWindow();
        await Future<void>.delayed(const Duration(milliseconds: 300));
        write('cmd $n show focused=${await windowManager.isFocused()}');
      case 'exit':
        write('cmd $n exit');
        path('done_$n').writeAsStringSync('1');
        await DesktopSession.instance.quit();
        return;
    }
    // 窗口背景在下一帧之后才下发（App 用 post-frame 回调），给它一点时间再让脚本截图。
    await Future<void>.delayed(const Duration(milliseconds: 150));
    path('done_$n').writeAsStringSync('1');
  }
}

AppThemeController? _findThemeController() {
  AppThemeController? found;
  void visit(Element e) {
    if (found != null) {
      return;
    }
    final w = e.widget;
    if (w is AppThemeScope) {
      found = w.notifier;
      return;
    }
    e.visitChildren(visit);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(visit);
  return found;
}

class _EventLog with WindowListener {
  _EventLog(this.write);

  final void Function(String) write;
  String? _last;

  @override
  void onWindowEvent(String eventName) {
    // move / resize 每次 WM_MOVING / WM_SIZING 都发，连续的只记一次。
    if (eventName == _last && (eventName == 'move' || eventName == 'resize')) {
      return;
    }
    _last = eventName;
    write('event $eventName');
  }
}
