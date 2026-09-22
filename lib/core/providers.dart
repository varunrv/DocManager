import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'crypto/vault_file_migration.dart';
import 'crypto/vault_key_repository.dart';
import 'database/app_database.dart';
import 'storage/encrypted_file_store.dart';
import 'storage/file_store.dart';
import '../features/backup/data/vault_backup_service.dart';
import '../features/categories/data/category_repository.dart';
import '../features/documents/data/document_repository.dart';
import '../features/people/data/person_repository.dart';
import '../features/settings/data/settings_repository.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final plainFileStoreProvider = Provider<FileStore>((ref) => createFileStore());

final fileStoreProvider = Provider<FileStore>((ref) {
  return EncryptedFileStore(ref.watch(plainFileStoreProvider));
});

final personRepositoryProvider = Provider<PersonRepository>((ref) {
  return PersonRepository(ref.watch(appDatabaseProvider));
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.watch(appDatabaseProvider));
});

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  return DocumentRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(fileStoreProvider),
  );
});

/// Must be overridden at app startup with an AsyncValue.guard call.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences not yet initialised');
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(sharedPreferencesProvider));
});

final vaultKeyRepositoryProvider = Provider<VaultKeyRepository>((ref) {
  return VaultKeyRepository();
});

final vaultBackupServiceProvider = Provider<VaultBackupService>((ref) {
  return VaultBackupService(
    db: ref.watch(appDatabaseProvider),
    documents: ref.watch(documentRepositoryProvider),
    people: ref.watch(personRepositoryProvider),
    categories: ref.watch(categoryRepositoryProvider),
    files: ref.watch(fileStoreProvider),
  );
});

Future<void> initializeVaultStorage({
  required SharedPreferences prefs,
  required AppDatabase db,
  required FileStore plainStore,
}) async {
  final keyRepo = VaultKeyRepository();
  await keyRepo.ensureLoaded();
  await VaultFileMigration(
    db: db,
    plainStore: plainStore,
    prefs: prefs,
  ).runIfNeeded();
}
