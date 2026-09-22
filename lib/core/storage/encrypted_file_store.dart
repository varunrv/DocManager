import 'dart:typed_data';

import '../crypto/vault_crypto_service.dart';
import '../crypto/vault_key_holder.dart';
import 'file_store.dart';

/// Encrypts all blobs written to the underlying [FileStore].
class EncryptedFileStore implements FileStore {
  EncryptedFileStore(this._inner, {VaultCryptoService? crypto})
      : _crypto = crypto ?? VaultCryptoService();

  final FileStore _inner;
  final VaultCryptoService _crypto;

  @override
  Future<void> write(String key, Uint8List bytes) async {
    final encrypted = await _crypto.encrypt(
      bytes,
      VaultKeyHolder.instance.secretKey,
    );
    await _inner.write(key, encrypted);
  }

  @override
  Future<Uint8List> read(String key) async {
    final payload = await _inner.read(key);
    return _crypto.decrypt(payload, VaultKeyHolder.instance.secretKey);
  }

  @override
  Future<void> delete(String key) => _inner.delete(key);

  @override
  Future<int> totalBytes() => _inner.totalBytes();

  FileStore get inner => _inner;
}
