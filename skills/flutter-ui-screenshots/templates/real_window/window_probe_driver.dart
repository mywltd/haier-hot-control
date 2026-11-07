import 'dart:async';
import 'dart:io';

import 'package:window_manager/window_manager.dart';

import 'app/desktop_session.dart';

/// 真窗口取色的驱动：只在环境变量 WINDOW_PROBE_DIR 存在时运行（capture.ps1 会设）。
/// 在 main.dart 的 runApp 之后调用 `runWindowProbeDriver();`，用完删掉，不要提交。
///
/// capture.ps1 往目录里写 cmd_* 文件，这里照做后回写 done_*；窗口事件记到 driver.log。
Future<void> runWindowProbeDriver() async {
  final dir = Platform.environment['WINDOW_PROBE_DIR'];
  if (dir == null) {
    return;
  }
  final log = File('$dir${Platform.pathSeparator}driver.log');
  void write(String line) => log.writeAsStringSync(
        '${DateTime.now().toIso8601String()} $line\n',
        mode: FileMode.append,
        flush: true,
      );
  File path(String name) => File('$dir${Platform.pathSeparator}$name');
  Future<void> waitFor(String name) async {
    final f = path(name);
    while (!f.existsSync()) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    f.deleteSync();
  }

  windowManager.addListener(_EventLog(write));
  // 等启动卡片结束、主窗口放大居中。
  await Future<void>.delayed(const Duration(seconds: 3));
  path('ready').writeAsStringSync('1');
  write('ready focused=${await windowManager.isFocused()}');

  await waitFor('cmd_hide');
  await DesktopSession.instance.hideToTray();
  path('done_hide').writeAsStringSync('1');

  await waitFor('cmd_show');
  await DesktopSession.instance.showWindow();
  await Future<void>.delayed(const Duration(milliseconds: 300));
  write('shown focused=${await windowManager.isFocused()}');
  path('done_show').writeAsStringSync('1');

  await waitFor('cmd_exit');
  await DesktopSession.instance.quit();
}

class _EventLog with WindowListener {
  _EventLog(this.write);

  final void Function(String) write;

  @override
  void onWindowEvent(String eventName) => write('event $eventName');
}
