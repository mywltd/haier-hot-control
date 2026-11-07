import 'package:flutter/widgets.dart';

import 'energy_tracker.dart';
import 'haier_api.dart';

/// 全局会话/状态：登录、设备列表、当前设备。
class HaierState extends ChangeNotifier {
  /// 构造只准备内存数据；启动入口才读取本地记录，测试和预览不碰磁盘或网络。
  HaierState({HaierApi? api, bool demo = true}) : api = api ?? HaierApi() {
    if (demo) _loadDemo();
  }
  static final HaierState instance = HaierState();

  Future<void> initialize() async {
    await EnergyTracker.instance.load();
    notifyListeners();
  }

  /// 演示数据：未登录时填充界面，登录后被真实设备替换。
  void _loadDemo() {
    devices = [
      HaierDevice({
        'deviceId': 'DEMO_HEATPUMP_01',
        'deviceName': '主卧采暖',
        'productNameT': 'KD14 热泵',
        'deviceType': 'heatpump',
        'online': true,
      }),
      HaierDevice({
        'deviceId': 'DEMO_HEATPUMP_02',
        'deviceName': '客厅采暖',
        'productNameT': 'KD14 热泵',
        'deviceType': 'heatpump',
        'online': true,
      }),
    ];
    allSnapshots = {
      'DEMO_HEATPUMP_01': {
        'onOffStatus': 'true',
        'currentTemperature': '24.5',
        'targetTemperature': '45',
        'operationMode': '制热',
        'outWaterTemp': '42',
        'backWaterTemp': '38',
        'runPower': '3200',
        'energySaved': '128.6',
        'waterFlux': '12.4',
        'envTemperature': '6',
        'systemRunTime': '186',
        'electricHeatingStatus': 'false',
        'pumpHeatingStatus': 'true',
        'workStatus': '1',
      },
      'DEMO_HEATPUMP_02': {
        'onOffStatus': 'false',
        'currentTemperature': '21.0',
        'targetTemperature': '40',
        'operationMode': '制热',
        'outWaterTemp': '35',
        'backWaterTemp': '31',
        'runPower': '0',
        'energySaved': '96.2',
        'waterFlux': '0',
        'envTemperature': '5',
        'systemRunTime': '92',
        'electricHeatingStatus': 'false',
        'pumpHeatingStatus': 'false',
        'workStatus': '0',
      },
    };
  }

  final HaierApi api;
  List<HaierDevice> devices = [];
  String? currentDeviceId;
  Map<String, String> snapshot = {};
  Map<String, Map<String, String>> allSnapshots = {};
  bool loading = false;
  bool refreshing = false;
  bool sendingControl = false;
  int _session = 0;
  String? error;

  bool get isDemo => !api.isLoggedIn;
  bool get busy => loading || refreshing || sendingControl;

  HaierDevice? get currentDevice {
    if (currentDeviceId == null) return null;
    for (final d in devices) {
      if (d.id == currentDeviceId) return d;
    }
    return null;
  }

  /// 便捷取值
  String valueOf(String deviceId, String key, [String fallback = '--']) =>
      allSnapshots[deviceId]?[key] ?? fallback;

  double get currentEnergy {
    final v = double.tryParse(snapshot['energySaved'] ?? '');
    return v ?? 0;
  }

  /// 今日用电 (kWh)，无采样时返回 null。
  double? get todayKwh =>
      isDemo ? 1.8 : EnergyTracker.instance.todayUsage(currentEnergy);
  double? get totalKwh =>
      isDemo ? 12.6 : EnergyTracker.instance.totalUsage(currentEnergy);
  List<Map<String, dynamic>> get dailyKwh {
    if (!isDemo) {
      return EnergyTracker.instance.dailyUsage(currentEnergy, days: 7);
    }
    final now = DateTime.now();
    return List.generate(7, (i) {
      final day = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: 6 - i));
      return {
        'date': '${day.month}/${day.day}',
        'kwh': [1.5, 2.1, 1.8, 2.4, 1.2, 1.8, 1.8][i],
      };
    });
  }

  /// 记录电量采样（供日用电统计）。
  void _recordEnergy() {
    final v = double.tryParse(snapshot['energySaved'] ?? '');
    if (v != null) {
      EnergyTracker.instance.record(v);
    }
  }

  Future<bool> login(String phone, String password) async {
    if (loading) return false;
    loading = true;
    error = null;
    notifyListeners();
    try {
      await api.login(phone, password);
      // 切到真实会话时清空所有演示快照，避免同 ID 的演示值混进真实设备。
      _session++;
      devices = [];
      allSnapshots = {};
      snapshot = {};
      currentDeviceId = null;
      await fetchDevices();
      loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      error = '$e';
      loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchDevices() async {
    if (isDemo || refreshing) return;
    final session = _session;
    refreshing = true;
    error = null;
    notifyListeners();
    try {
      final next = await api.devices();
      if (session != _session) return;
      devices = next;
      allSnapshots.removeWhere((id, _) => !next.any((d) => d.id == id));
      if (!next.any((d) => d.id == currentDeviceId)) {
        currentDeviceId = null;
        snapshot = {};
      }
      error = null;
      await fetchAllSnapshots();
    } catch (e) {
      if (session == _session) error = '$e';
    } finally {
      if (session == _session) {
        refreshing = false;
        notifyListeners();
      }
    }
  }

  /// 拉取全部设备状态快照（用于列表预览）。
  Future<void> fetchAllSnapshots() async {
    final session = _session;
    for (final d in devices) {
      try {
        final next = await api.snapshot(d.id);
        if (session != _session) return;
        allSnapshots[d.id] = next;
        if (d.id == currentDeviceId) snapshot = Map.of(next);
      } catch (e) {
        if (session == _session) error = '部分设备状态未更新：$e';
      }
    }
    notifyListeners();
  }

  Future<void> selectDevice(String id) async {
    if (!devices.any((d) => d.id == id)) return;
    currentDeviceId = id;
    error = null;
    // 先用已有快照填充（演示/缓存），再拉实时数据
    snapshot = Map<String, String>.from(allSnapshots[id] ?? {});
    notifyListeners();
    await refreshSnapshot();
  }

  Future<void> refreshSnapshot() async {
    final id = currentDeviceId;
    if (id == null || isDemo || refreshing) return;
    refreshing = true;
    error = null;
    notifyListeners();
    final session = _session;
    try {
      final snap = await api.snapshot(id);
      if (session != _session) return;
      if (snap.isNotEmpty) {
        allSnapshots[id] = snap;
        if (id == currentDeviceId) {
          snapshot = snap;
          _recordEnergy();
        }
      }
    } catch (e) {
      if (session == _session) error = '$e';
    } finally {
      if (session == _session) {
        refreshing = false;
        notifyListeners();
      }
    }
  }

  Future<bool> control(Map<String, String> args) async {
    final id = currentDeviceId;
    if (id == null) return false;
    return controlDevice(id, args);
  }

  /// 快捷开关必须使用卡片自己的设备 ID，不能依赖控制页的当前选择。
  Future<bool> controlDevice(String id, Map<String, String> args) async {
    if (isDemo || busy || !devices.any((d) => d.id == id && d.online)) {
      return false;
    }
    final session = _session;
    sendingControl = true;
    error = null;
    notifyListeners();
    try {
      await api.control(id, args);
      if (session != _session) return false;
      final next = await api.snapshot(id);
      if (session != _session) return false;
      allSnapshots[id] = next;
      if (currentDeviceId == id) {
        snapshot = next;
        _recordEnergy();
      }
      return true;
    } catch (e) {
      if (session == _session) error = '$e';
      return false;
    } finally {
      if (session == _session) {
        sendingControl = false;
        notifyListeners();
      }
    }
  }

  Future<bool> setPower(bool on) =>
      control({'onOffStatus': on ? 'true' : 'false'});
  Future<bool> setTemp(int c) => control({'targetTemperature': '$c'});
  Future<bool> setMode(String mode) => control({'operationMode': mode});

  void logout() {
    _session++;
    api.accessToken = '';
    api.refreshToken = '';
    devices = [];
    currentDeviceId = null;
    snapshot = {};
    allSnapshots = {};
    loading = false;
    refreshing = false;
    sendingControl = false;
    error = null;
    _loadDemo();
    notifyListeners();
  }
}

class HaierScope extends InheritedNotifier<HaierState> {
  const HaierScope({
    super.key,
    required HaierState super.notifier,
    required super.child,
  });

  static HaierState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HaierScope>()!.notifier!;
}
