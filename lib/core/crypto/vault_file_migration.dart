import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';
import '../storage/file_store.dart';
import 'vault_crypto_service.dart';
import 'vault_key_holder.dart';

const _kEncryptionMigratedKey = 'encryption_migrated_v1';

class VaultFileMigration {
  VaultFileMigration({
    required AppDatabase db,
    required FileStore plainStore,
    required SharedPreferences prefs,
    VaultCryptoService? crypto,
  })  : _db = db,
        _plain = plainStore,
        _prefs = prefs,
        _crypto = crypto ?? VaultCryptoService();

  final AppDatabase _db;
  final FileStore _plain;
  final SharedPreferences _prefs;
  final VaultCryptoService _crypto;

  bool get isMigrated => _prefs.getBool(_kEncryptionMigratedKey) ?? false;

  Future<void> runIfNeeded() async {
    if (isMigrated) return;

    final rows = await _db.select(_db.documents).get();
    final keys = <String>{};
    for (final row in rows) {
      keys.add(row.storageKey);
      final thumb = row.thumbnailKey;
      if (thumb != null) keys.add(thumb);
    }

    final key = VaultKeyHolder.instance.secretKey;
    for (final storageKey in keys) {
      try {
        final raw = await _plain.read(storageKey);
        if (_looksEncrypted(raw)) continue;
        final encrypted = await _crypto.encrypt(raw, key);
        await _plain.write(storageKey, encrypted);
      } catch (_) {
        // Missing file — skip.
      }
    }

    await _prefs.setBool(_kEncryptionMigratedKey, true);
  }

  bool _looksEncrypted(Uint8List bytes) {
    return bytes.length >=
        VaultCryptoService.nonceLength + VaultCryptoService.macLength + 1;
  }
}
