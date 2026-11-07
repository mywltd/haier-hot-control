import 'package:flutter_test/flutter_test.dart';
import 'package:haier_heat/haier/haier_state.dart';

import 'support/fake_haier_api.dart';

void main() {
  test('浏览演示设备和尝试控制不会发起网络请求', () async {
    final api = FakeHaierApi();
    final state = HaierState(api: api);
    await state.selectDevice(state.devices.first.id);
    await state.refreshSnapshot();
    await state.fetchDevices();
    expect(await state.setPower(false), isFalse);
    expect(api.requests, 0);
    expect(state.dailyKwh.length, 7);
    state.dispose();
  });

  test('登录替换演示快照，退出清理会话及当前设备', () async {
    final api = FakeHaierApi();
    final state = HaierState(api: api);
    await state.selectDevice(state.devices.first.id);
    expect(await state.login('13800138000', 'test-password'), isTrue);
    expect(state.allSnapshots.keys, unorderedEquals(['a', 'b']));
    expect(state.currentDeviceId, isNull);
    await state.selectDevice('a');
    expect(await state.setTemp(50), isTrue);
    expect(state.snapshot['targetTemperature'], '50');
    state.logout();
    expect(state.isDemo, isTrue);
    expect(state.currentDeviceId, isNull);
    expect(state.allSnapshots.containsKey('a'), isFalse);
    expect(state.error, isNull);
    state.dispose();
  });
}
