import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database/app_database.dart';
import 'storage/file_store.dart';
import '../features/categories/data/category_repository.dart';
import '../features/documents/data/document_repository.dart';
import '../features/people/data/person_repository.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final fileStoreProvider = Provider<FileStore>((ref) => createFileStore());

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
