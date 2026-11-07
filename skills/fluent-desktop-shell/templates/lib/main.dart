import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'app/shell_settings.dart';
import 'app/window_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 窗口先设成屏幕中央的启动卡片（第一帧画出后才显示）。出错也要继续 runApp。
  try {
    await bootstrapDesktopWindow();
  } catch (e, st) {
    developer.log('窗口初始化失败: $e', name: 'Bootstrap', stackTrace: st);
  }
  // 只读本地配置，要快：主题要在第一帧前确定。
  await ShellSettings.instance.load();
  runApp(App(startup: _startup()));
}

/// 慢的初始化（登录、连接、拉数据）放这里，启动卡片最多等 3 秒，超时后在后台继续。
Future<void> _startup() async {}
