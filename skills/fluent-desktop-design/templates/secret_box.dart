import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// 本地保存的密码：Windows 上用 DPAPI 加密，只有当前 Windows 用户能解开；
/// 配置文件被拷到别的电脑或别的账户下也读不出明文。
abstract final class SecretBox {
  /// win32 包没导出这个常量；不弹任何系统提示框。
  static const _uiForbidden = 0x1;

  static bool get supported => Platform.isWindows;

  /// 加密后转 base64；空串原样返回。
  static String protect(String plain) {
    if (plain.isEmpty) {
      return '';
    }
    return base64Encode(_crypt(utf8.encode(plain), encrypt: true));
  }

  /// 解密失败（换了电脑 / 账户）返回 null。
  static String? unprotect(String encoded) {
    if (encoded.isEmpty) {
      return '';
    }
    try {
      return utf8.decode(_crypt(base64Decode(encoded), encrypt: false));
    } catch (_) {
      return null;
    }
  }

  static Uint8List _crypt(List<int> data, {required bool encrypt}) {
    return using((arena) {
      final input = arena<CRYPT_INTEGER_BLOB>();
      final output = arena<CRYPT_INTEGER_BLOB>();
      final buffer = arena<Uint8>(data.length);
      buffer.asTypedList(data.length).setAll(0, data);
      input.ref
        ..cbData = data.length
        ..pbData = buffer;
      final result = encrypt
          ? CryptProtectData(input, null, null, null, _uiForbidden, output)
          : CryptUnprotectData(input, null, null, null, _uiForbidden, output);
      if (!result.value) {
        throw StateError('DPAPI 调用失败：${result.error}');
      }
      try {
        return Uint8List.fromList(
          output.ref.pbData.asTypedList(output.ref.cbData),
        );
      } finally {
        LocalFree(HLOCAL(output.ref.pbData));
      }
    });
  }
}
