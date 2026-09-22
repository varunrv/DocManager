import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Holds the vault DEK in memory for the app process lifetime.
class VaultKeyHolder {
  VaultKeyHolder._();

  static final VaultKeyHolder instance = VaultKeyHolder._();

  SecretKey? _secretKey;

  bool get isReady => _secretKey != null;

  SecretKey get secretKey {
    final key = _secretKey;
    if (key == null) {
      throw StateError('Vault key is not loaded.');
    }
    return key;
  }

  void setKeyBytes(Uint8List keyBytes) {
    if (keyBytes.length != 32) {
      throw ArgumentError('Vault DEK must be 32 bytes.');
    }
    _secretKey = SecretKey(keyBytes);
  }

  Future<Uint8List> exportKeyBytes() async {
    return Uint8List.fromList(await secretKey.extractBytes());
  }
}
