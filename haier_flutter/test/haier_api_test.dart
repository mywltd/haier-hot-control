import 'package:flutter_test/flutter_test.dart';
import 'package:haier_heat/haier/haier_api.dart';

void main() {
  test('未配置签名凭据时，登录在发起网络请求前给出配置提示', () async {
    if (HaierApi.appId.trim().isNotEmpty && HaierApi.appKey.trim().isNotEmpty) {
      return;
    }
    final api = HaierApi();
    await expectLater(
      api.login('13800000000', 'test-password'),
      throwsA(
        isA<HaierException>().having(
          (error) => error.message,
          'message',
          contains('HAIER_APP_KEY'),
        ),
      ),
    );
    expect(api.isLoggedIn, isFalse);
  });
}
