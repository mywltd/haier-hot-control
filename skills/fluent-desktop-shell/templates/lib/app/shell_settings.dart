import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'window_material.dart';

/// 点击窗口右上角关闭按钮后的行为。
enum CloseAction {
  ask('每次询问'),
  tray('最小化到托盘'),
  exit('退出程序');

  const CloseAction(this.label);

  final String label;
}

/// 壳子自己的设置：主题、关闭行为、窗口材质，保存在应用数据目录的 shell_settings.json。
///
/// 业务设置（服务器、账号等）另建自己的存储，不要往这里塞。
class ShellSettings extends ChangeNotifier {
  ShellSettings({this._directory});

  static final ShellSettings instance = ShellSettings();

  final Directory? _directory;
  File? _file;
  Future<void> _writes = Future.value();
  // 有只预览、还没写盘的改动（见 setAcrylic 的 persist）；退出时由 [flush] 补写。
  bool _unsaved = false;
  CloseAction _closeAction = CloseAction.ask;
  String _themeMode = 'system';
  WindowMaterial _windowMaterial = WindowMaterial.mica;
  AcrylicOptions _acrylic = const AcrylicOptions();

  CloseAction get closeAction => _closeAction;

  /// `system` / `light` / `dark`。
  String get themeMode => _themeMode;

  /// 用户选的材质；系统不支持云母时实际用毛玻璃，见 `planBackdrop`。
  WindowMaterial get windowMaterial => _windowMaterial;
  AcrylicOptions get acrylic => _acrylic;

  Future<void> load() async {
    final dir = _directory ?? await getApplicationSupportDirectory();
    final file = _file = File(
      '${dir.path}${Platform.pathSeparator}shell_settings.json',
    );
    if (!await file.exists()) {
      return;
    }
    try {
      final json = jsonDecode(await file.readAsString());
      if (json is Map) {
        _closeAction =
            CloseAction.values.asNameMap()[json['closeAction']] ??
            CloseAction.ask;
        final mode = json['themeMode'];
        if (mode is String && const {'system', 'light', 'dark'}.contains(mode)) {
          _themeMode = mode;
        }
        _windowMaterial =
            WindowMaterial.values.asNameMap()[json['windowMaterial']] ??
            WindowMaterial.mica;
        _acrylic = AcrylicOptions.fromJson(json['acrylic']);
        notifyListeners();
      }
    } catch (e) {
      developer.log('shell_settings.json 解析失败，使用默认值: $e', name: 'Shell');
    }
  }

  Future<void> setCloseAction(CloseAction action) {
    _closeAction = action;
    notifyListeners();
    return _persist();
  }

  Future<void> setThemeMode(String mode) {
    _themeMode = mode;
    notifyListeners();
    return _persist();
  }

  Future<void> setWindowMaterial(WindowMaterial material) {
    _windowMaterial = material;
    notifyListeners();
    return _persist();
  }

  /// [persist] 为 false 时只改内存、立即生效，用于拖动滑块时预览；松手后再写盘。
  Future<void> setAcrylic(AcrylicOptions options, {bool persist = true}) {
    _acrylic = options;
    notifyListeners();
    if (persist) {
      return _persist();
    }
    _unsaved = true;
    return Future.value();
  }

  /// 退出前调用：预览中途退出（比如取色器开着时从托盘退出）也不丢改动。
  Future<void> flush() => _unsaved ? _persist() : _writes;

  /// 写盘串行化：两次写同时进行会争用同一个 .tmp 文件。
  Future<void> _persist() {
    // 写的是整份当前设置，预览中的改动也一起写进去。
    _unsaved = false;
    final file = _file;
    if (file == null) {
      return Future.value();
    }
    return _writes = _writes.then((_) async {
      try {
        final tmp = File('${file.path}.tmp');
        await tmp.writeAsString(
          jsonEncode({
            'closeAction': _closeAction.name,
            'themeMode': _themeMode,
            'windowMaterial': _windowMaterial.name,
            'acrylic': _acrylic.toJson(),
          }),
          flush: true,
        );
        await tmp.rename(file.path);
      } catch (e, st) {
        developer.log('保存壳子设置失败: $e', name: 'Shell', stackTrace: st);
      }
    });
  }
}
