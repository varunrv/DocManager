import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'vault_key_holder.dart';

const _dekStorageKey = 'vault_dek_v1';

class VaultKeyRepository {
  VaultKeyRepository({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<void> ensureLoaded() async {
    if (VaultKeyHolder.instance.isReady) return;

    var encoded = await _storage.read(key: _dekStorageKey);
    if (encoded == null) {
      final keyBytes = _generateDek();
      encoded = base64Encode(keyBytes);
      await _storage.write(key: _dekStorageKey, value: encoded);
    }

    final keyBytes = base64Decode(encoded);
    VaultKeyHolder.instance.setKeyBytes(Uint8List.fromList(keyBytes));
  }

  Uint8List _generateDek() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
  }
}
