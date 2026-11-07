import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

/// 海尔智家 U+ 云接口 (参考 xxxifan/haier_win11_widgets / banto6/haier，签名已实测通过)。
class HaierApi {
  static const appId = String.fromEnvironment(
    'HAIER_APP_ID',
    defaultValue: 'MB-UZHSH-0001',
  );
  static const appKey = String.fromEnvironment('HAIER_APP_KEY');

  static const _loginUrl =
      'https://zj.haier.net/api-gw/oauthserver/account/v1/login';
  static const _refreshUrl =
      'https://zj.haier.net/api-gw/oauthserver/account/v1/refreshToken';
  static const _userInfoUrl = 'https://account-api.haier.net/v2/haier/userinfo';
  static const _devicesUrl =
      'https://uws.haier.net/uds/v1/protected/deviceinfos';
  static const _digitalModelUrl =
      'https://uws.haier.net/shadow/v1/devdigitalmodels';
  static const _gatewayUrl = 'https://uws.haier.net/gmsWS/wsag/assign';

  String phone = '';
  String accessToken = '';
  String refreshToken = '';

  bool get isLoggedIn => accessToken.isNotEmpty;

  /// sign = sha256(path + body去空白 + appId + appKey + timestamp)
  static String sign(String timestamp, String body, String path) {
    final compact = body.replaceAll(RegExp(r'\s'), '');
    final content = path + compact + appId + appKey + timestamp;
    return sha256Hex(content);
  }

  static String sha256Hex(String input) {
    final bytes = utf8.encode(input);
    final digest = _sha256(bytes);
    return digest.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static String sequenceId() {
    final now = DateTime.now();
    final ts =
        '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
    return ts + (100000 + Random().nextInt(900000)).toString();
  }

  Map<String, String> _headers(String url, String body) {
    if (appId.trim().isEmpty || appKey.trim().isEmpty) {
      throw HaierException(
        '请先配置 HAIER_APP_ID / HAIER_APP_KEY，并通过 '
        '--dart-define-from-file=config/haier.local.json 重新运行应用。',
      );
    }
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    final uri = Uri.parse(url);
    return {
      'accessToken': accessToken,
      'appId': appId,
      'appKey': appKey,
      'clientId': phone.isEmpty ? '13800000000' : phone,
      'sequenceId': sequenceId(),
      'sign': sign(ts, body, uri.path),
      'timestamp': ts,
      'timezone': '+8',
      'language': 'zh-CN',
      'Content-Type': 'application/json',
    };
  }

  Future<Map<String, dynamic>> _post(
    String url,
    Map<String, dynamic> payload,
  ) async {
    final body = jsonEncode(payload);
    final resp = await http.post(
      Uri.parse(url),
      headers: _headers(url, body),
      body: body,
    );
    return _decode(resp);
  }

  Future<Map<String, dynamic>> _get(String url) async {
    final resp = await http.get(Uri.parse(url), headers: _headers(url, ''));
    return _decode(resp);
  }

  Map<String, dynamic> _decode(http.Response resp) {
    final obj = jsonDecode(utf8.decode(resp.bodyBytes));
    if (obj is Map<String, dynamic>) {
      final rc = obj['retCode'];
      if (rc != null && rc != '00000') {
        throw HaierException('${obj['retInfo'] ?? '接口异常'} ($rc)');
      }
      return obj;
    }
    return {'_raw': obj};
  }

  // ---------------------------------------------------------------- 登录

  Future<void> login(String phone, String password) async {
    this.phone = phone;
    final obj = await _post(_loginUrl, {
      'username': phone,
      'password': password,
    });
    final info = (obj['data']?['tokenInfo'] as Map?) ?? {};
    final token = info['accountToken'] as String? ?? '';
    if (token.isEmpty) throw HaierException('登录失败：未返回 token');
    accessToken = token;
    refreshToken = info['refreshToken'] as String? ?? '';
  }

  Future<void> refresh() async {
    if (refreshToken.isEmpty) return;
    final obj = await _post(_refreshUrl, {'refreshToken': refreshToken});
    final info = (obj['data']?['tokenInfo'] as Map?) ?? {};
    final token = info['accountToken'] as String?;
    if (token != null && token.isNotEmpty) {
      accessToken = token;
      refreshToken = info['refreshToken'] as String? ?? refreshToken;
    }
  }

  Future<Map<String, dynamic>> userInfo() async {
    final resp = await http.get(
      Uri.parse(_userInfoUrl),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    return jsonDecode(utf8.decode(resp.bodyBytes));
  }

  // ---------------------------------------------------------------- 设备

  Future<List<HaierDevice>> devices() async {
    final obj = await _get(_devicesUrl);
    final list = (obj['deviceinfos'] as List?) ?? [];
    final devs = list
        .map((e) => HaierDevice(e as Map<String, dynamic>))
        .toList();
    devs.sort((a, b) => a.name.compareTo(b.name));
    return devs;
  }

  /// 数字模型属性 (含当前值)。
  Future<List<Map<String, dynamic>>> attributes(String deviceId) async {
    final obj = await _post(_digitalModelUrl, {
      'deviceInfoList': [
        {'deviceId': deviceId},
      ],
    });
    final detail = (obj['detailInfo'] as Map?) ?? {};
    var model = detail[deviceId];
    if (model is String) model = jsonDecode(model);
    final attrs = (model is Map ? model['attributes'] as List? : null) ?? [];
    return attrs.cast<Map<String, dynamic>>();
  }

  Future<Map<String, String>> snapshot(String deviceId) async {
    final attrs = await attributes(deviceId);
    final map = <String, String>{};
    for (final a in attrs) {
      if (a.containsKey('value')) map['${a['name']}'] = '${a['value']}';
    }
    return map;
  }

  // ---------------------------------------------------------------- 控制

  /// 经 WebSocket 网关下发 BatchCmdReq。
  Future<void> control(String deviceId, Map<String, String> cmdArgs) async {
    final gw = await _post(_gatewayUrl, {
      'clientId': phone,
      'token': accessToken,
    });
    var addr = (gw['agAddr'] as String?) ?? '';
    if (addr.isEmpty) throw HaierException('获取网关失败');
    addr = addr
        .replaceFirst('http://', 'wss://')
        .replaceFirst('https://', 'wss://');
    final wsUrl = Uri.parse(
      '$addr/userag?token=$accessToken&agClientId=$accessToken',
    );

    final ws = await WebSocket.connect(wsUrl.toString());
    final sn = List.generate(
      32,
      (_) => 'abcdef1234567890'[Random().nextInt(16)],
    ).join();
    ws.add(
      jsonEncode({
        'agClientId': accessToken,
        'topic': 'BatchCmdReq',
        'content': {
          'trace': sn,
          'sn': sn,
          'data': [
            {
              'sn': sn,
              'index': 0,
              'delaySeconds': 0,
              'subSn': '$sn:0',
              'deviceId': deviceId,
              'cmdArgs': cmdArgs,
            },
          ],
        },
      }),
    );

    // 等待响应
    await for (final msg in ws.timeout(
      const Duration(seconds: 12),
      onTimeout: (sink) {
        sink.close();
      },
    )) {
      if (msg is! String) continue;
      final obj = jsonDecode(msg);
      final content = obj['content'] as Map? ?? {};
      String gotSn = '${content['sn'] ?? ''}';
      final data = content['data'];
      if (gotSn.isEmpty && data is List && data.isNotEmpty) {
        gotSn = '${data[0]['sn'] ?? ''}';
      }
      if (gotSn == sn && obj['topic'] != 'BatchCmdReq') {
        await ws.close();
        return;
      }
    }
    await ws.close();
  }
}

class HaierDevice {
  HaierDevice(this.raw);
  final Map<String, dynamic> raw;

  String get id => '${raw['deviceId'] ?? ''}';
  String get name => '${raw['deviceName'] ?? id}';
  String get type => '${raw['deviceType'] ?? ''}';
  String get productCode => '${raw['productCodeT'] ?? ''}';
  String get productName => '${raw['productNameT'] ?? ''}';
  bool get online => raw['online'] == true;
}

class HaierException implements Exception {
  HaierException(this.message);
  final String message;
  @override
  String toString() => message;
}

// 纯 Dart SHA-256 (避免额外依赖)
List<int> _sha256(List<int> bytes) {
  const k = <int>[
    0x428a2f98,
    0x71374491,
    0xb5c0fbcf,
    0xe9b5dba5,
    0x3956c25b,
    0x59f111f1,
    0x923f82a4,
    0xab1c5ed5,
    0xd807aa98,
    0x12835b01,
    0x243185be,
    0x550c7dc3,
    0x72be5d74,
    0x80deb1fe,
    0x9bdc06a7,
    0xc19bf174,
    0xe49b69c1,
    0xefbe4786,
    0x0fc19dc6,
    0x240ca1cc,
    0x2de92c6f,
    0x4a7484aa,
    0x5cb0a9dc,
    0x76f988da,
    0x983e5152,
    0xa831c66d,
    0xb00327c8,
    0xbf597fc7,
    0xc6e00bf3,
    0xd5a79147,
    0x06ca6351,
    0x14292967,
    0x27b70a85,
    0x2e1b2138,
    0x4d2c6dfc,
    0x53380d13,
    0x650a7354,
    0x766a0abb,
    0x81c2c92e,
    0x92722c85,
    0xa2bfe8a1,
    0xa81a664b,
    0xc24b8b70,
    0xc76c51a3,
    0xd192e819,
    0xd6990624,
    0xf40e3585,
    0x106aa070,
    0x19a4c116,
    0x1e376c08,
    0x2748774c,
    0x34b0bcb5,
    0x391c0cb3,
    0x4ed8aa4a,
    0x5b9cca4f,
    0x682e6ff3,
    0x748f82ee,
    0x78a5636f,
    0x84c87814,
    0x8cc70208,
    0x90befffa,
    0xa4506ceb,
    0xbef9a3f7,
    0xc67178f2,
  ];
  var h = <int>[
    0x6a09e667,
    0xbb67ae85,
    0x3c6ef372,
    0xa54ff53a,
    0x510e527f,
    0x9b05688c,
    0x1f83d9ab,
    0x5be0cd19,
  ];
  final msg = <int>[...bytes, 0x80];
  while ((msg.length % 64) != 56) {
    msg.add(0);
  }
  final bitLen = bytes.length * 8;
  for (var i = 7; i >= 0; i--) {
    msg.add((bitLen >> (8 * i)) & 0xff);
  }
  for (var off = 0; off < msg.length; off += 64) {
    final w = List<int>.filled(64, 0);
    for (var i = 0; i < 16; i++) {
      w[i] =
          (msg[off + 4 * i] << 24) |
          (msg[off + 4 * i + 1] << 16) |
          (msg[off + 4 * i + 2] << 8) |
          msg[off + 4 * i + 3];
    }
    for (var i = 16; i < 64; i++) {
      final s0 = _rotr(w[i - 15], 7) ^ _rotr(w[i - 15], 18) ^ (w[i - 15] >> 3);
      final s1 = _rotr(w[i - 2], 17) ^ _rotr(w[i - 2], 19) ^ (w[i - 2] >> 10);
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xffffffff;
    }
    var a = h[0],
        b = h[1],
        c = h[2],
        d = h[3],
        e = h[4],
        f = h[5],
        g = h[6],
        hh = h[7];
    for (var i = 0; i < 64; i++) {
      final sum1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
      final ch = (e & f) ^ ((~e & 0xffffffff) & g);
      final t1 = (hh + sum1 + ch + k[i] + w[i]) & 0xffffffff;
      final sum0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final t2 = (sum0 + maj) & 0xffffffff;
      hh = g;
      g = f;
      f = e;
      e = (d + t1) & 0xffffffff;
      d = c;
      c = b;
      b = a;
      a = (t1 + t2) & 0xffffffff;
    }
    h = [
      (h[0] + a) & 0xffffffff,
      (h[1] + b) & 0xffffffff,
      (h[2] + c) & 0xffffffff,
      (h[3] + d) & 0xffffffff,
      (h[4] + e) & 0xffffffff,
      (h[5] + f) & 0xffffffff,
      (h[6] + g) & 0xffffffff,
      (h[7] + hh) & 0xffffffff,
    ];
  }
  return h
      .expand(
        (x) => [(x >> 24) & 0xff, (x >> 16) & 0xff, (x >> 8) & 0xff, x & 0xff],
      )
      .toList();
}

int _rotr(int x, int n) => ((x >> n) | (x << (32 - n))) & 0xffffffff;
