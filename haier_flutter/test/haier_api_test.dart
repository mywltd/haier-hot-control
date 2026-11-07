import 'package:flutter_test/flutter_test.dart';
import 'package:haier_heat/haier/haier_api.dart';

void main() {
  test(
    '内置签名与既有接口签名向量一致',
    () {
      expect(
        HaierApi.sign(
          '1700000000000',
          '{ "username": "13800000000", "password": "test-password" }',
          '/api-gw/oauthserver/account/v1/login',
        ),
        '8e880cd22dc02cb52388ff9b8eeb6ecda4db0efda4829ab35653227ce1cda3fc',
      );
    },
    skip:
        const bool.hasEnvironment('HAIER_APP_ID') ||
        const bool.hasEnvironment('HAIER_APP_KEY'),
  );

  test(
    '显式清空签名配置时，登录在发起网络请求前给出配置提示',
    () async {
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
    },
    skip: HaierApi.appId.trim().isNotEmpty && HaierApi.appKey.trim().isNotEmpty,
  );
}
