import 'package:haier_heat/haier/haier_api.dart';

/// 纯内存云端替身，测试不调用真实登录或设备接口。
class FakeHaierApi extends HaierApi {
  final commands = <(String, Map<String, String>)>[];
  int requests = 0;
  final snapshots = <String, Map<String, String>>{
    'a': {
      'onOffStatus': 'true',
      'currentTemperature': '24.5',
      'targetTemperature': '45',
      'operationMode': '制热',
    },
    'b': {
      'onOffStatus': 'false',
      'currentTemperature': '21',
      'targetTemperature': '40',
      'operationMode': '制热',
    },
  };

  @override
  Future<void> login(String phone, String password) async {
    requests++;
    this.phone = phone;
    accessToken = 'test-session';
  }

  @override
  Future<List<HaierDevice>> devices() async {
    requests++;
    return [
      for (final id in ['a', 'b'])
        HaierDevice({
          'deviceId': id,
          'deviceName': '真实设备 ${id.toUpperCase()}',
          'productNameT': '热泵',
          'online': true,
        }),
    ];
  }

  @override
  Future<Map<String, String>> snapshot(String deviceId) async {
    requests++;
    return Map.of(snapshots[deviceId]!);
  }

  @override
  Future<void> control(String deviceId, Map<String, String> cmdArgs) async {
    requests++;
    commands.add((deviceId, Map.of(cmdArgs)));
    snapshots[deviceId]!.addAll(cmdArgs);
  }
}
