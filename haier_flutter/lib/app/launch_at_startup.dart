import 'dart:io';

import 'package:win32_registry/win32_registry.dart';

/// 写入当前用户的「开机启动」注册表项（HKCU\...\Run，无需管理员权限）。
class LaunchAtStartup {
  LaunchAtStartup._();

  static const _valueName = 'HaierHeat';
  static const _runKeyPath = r'Software\Microsoft\Windows\CurrentVersion\Run';
  static const _writeConfig = RegistryOpenConfig(
    access: RegistryAccess.readWrite,
    create: true,
  );

  static String get _command => '"${Platform.resolvedExecutable}"';

  static bool isEnabled() {
    if (!Platform.isWindows) {
      return false;
    }
    final key = CURRENT_USER.open(_runKeyPath);
    try {
      return key.getType(_valueName) != null;
    } finally {
      key.close();
    }
  }

  static void setEnabled(bool enabled) {
    if (!Platform.isWindows) {
      return;
    }
    final key = CURRENT_USER.open(_runKeyPath, config: _writeConfig);
    try {
      if (enabled) {
        key.setValue(_valueName, RegistryValue.string(_command));
      } else if (key.getType(_valueName) != null) {
        key.removeValue(_valueName);
      }
    } finally {
      key.close();
    }
  }
}
