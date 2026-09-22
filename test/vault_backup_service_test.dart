import 'dart:typed_data';

import 'package:docket/core/database/app_database.dart';
import 'package:docket/core/errors.dart';
import 'package:docket/core/storage/file_store.dart';
import 'package:docket/features/backup/data/vault_backup_service.dart';
import 'package:docket/features/backup/domain/backup_import.dart';
import 'package:docket/features/categories/data/category_repository.dart';
import 'package:docket/features/documents/data/document_repository.dart';
import 'package:docket/features/people/data/person_repository.dart';
import 'package:docket/features/people/domain/person.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryFileStore implements FileStore {
  final Map<String, Uint8List> _files = {};

  @override
  Future<void> write(String key, Uint8List bytes) async {
    _files[key] = Uint8List.fromList(bytes);
  }

  @override
  Future<Uint8List> read(String key) async {
    final bytes = _files[key];
    if (bytes == null) {
      throw const AppException('The file is missing from local storage.');
    }
    return Uint8List.fromList(bytes);
  }

  @override
  Future<void> delete(String key) async {
    _files.remove(key);
  }

  @override
  Future<int> totalBytes() async {
    return _files.values.fold<int>(0, (sum, bytes) => sum + bytes.length);
  }
}

void main() {
  late AppDatabase db;
  late _MemoryFileStore files;
  late DocumentRepository documents;
  late PersonRepository people;
  late CategoryRepository categories;
  late VaultBackupService backup;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    files = _MemoryFileStore();
    documents = DocumentRepository(db, files);
    people = PersonRepository(db);
    categories = CategoryRepository(db);
    backup = VaultBackupService(
      db: db,
      documents: documents,
      people: people,
      categories: categories,
      files: files,
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> renameSelf(String name) async {
    final self = await people.getSelf();
    await people.update(self.copyWith(displayName: name));
  }

  Future<(String selfDocId, String spouseDocId, Person spouse)> seedVault() async {
    await renameSelf('Varun');
    final spouse = await people.add(
      displayName: 'Priya',
      relationship: PersonRelationship.spouse,
    );
    final cats = await categories.getAll();
    final identity = cats.firstWhere((c) => c.id == 'category-identity');
    final self = await people.getSelf();

    final selfDoc = await documents.add(
      personId: self.id,
      title: 'Aadhaar',
      categoryId: identity.id,
      tags: const ['aadhaar'],
      notes: 'mine',
      originalFileName: 'aadhaar.jpg',
      mimeType: 'image/jpeg',
      bytes: Uint8List.fromList('self-bytes'.codeUnits),
    );
    final spouseDoc = await documents.add(
      personId: spouse.id,
      title: 'Passport',
      categoryId: identity.id,
      tags: const ['passport'],
      notes: 'hers',
      originalFileName: 'passport.pdf',
      mimeType: 'application/pdf',
      bytes: Uint8List.fromList('spouse-bytes'.codeUnits),
    );
    return (selfDoc.id, spouseDoc.id, spouse);
  }

  test('export only selected documents', () async {
    final (selfDocId, spouseDocId, _) = await seedVault();
    const password = 'backup-pass-123';

    final archiveBytes = await backup.exportVault(
      password,
      documentIds: {selfDocId},
    );
    final preview = await backup.previewImport(archiveBytes, password);

    expect(preview.manifest.documents, hasLength(1));
    expect(preview.manifest.documents.single.title, 'Aadhaar');
    expect(preview.manifest.people, hasLength(1));
    expect(preview.manifest.people.single.displayName, 'Varun');
    expect(preview.people.single.documentCount, 1);
    // spouse doc id must not be in backup
    expect(
      preview.manifest.documents.any((d) => d.id == spouseDocId),
      isFalse,
    );
  });

  test('export blocks Me docs when self name is still Me', () async {
    final cats = await categories.getAll();
    final identity = cats.firstWhere((c) => c.id == 'category-identity');
    final self = await people.getSelf();
    expect(isPlaceholderSelfName(self.displayName), isTrue);

    final doc = await documents.add(
      personId: self.id,
      title: 'PAN',
      categoryId: identity.id,
      tags: const [],
      notes: '',
      originalFileName: 'pan.pdf',
      mimeType: 'application/pdf',
      bytes: Uint8List.fromList([1, 2, 3]),
    );

    expect(
      () => backup.exportVault('backup-pass-123', documentIds: {doc.id}),
      throwsA(isA<AppException>()),
    );
  });

  test('import merges onto existing person without wiping vault', () async {
    final (selfDocId, spouseDocId, spouse) = await seedVault();
    const password = 'backup-pass-123';

    final archiveBytes = await backup.exportVault(
      password,
      documentIds: {selfDocId, spouseDocId},
    );

    // Local vault still has both docs — import should not wipe them.
    final beforeCount = (await documents.getAll()).length;
    expect(beforeCount, 2);

    final result = await backup.importVault(
      archiveBytes,
      password,
      decisions: [
        PersonImportDecision(
          backupPersonId: (await people.getSelf()).id,
          action: PersonImportAction.mergeExisting,
          targetLocalPersonId: (await people.getSelf()).id,
        ),
        PersonImportDecision(
          backupPersonId: spouse.id,
          action: PersonImportAction.mergeExisting,
          targetLocalPersonId: spouse.id,
        ),
      ],
    );

    expect(result.documentsSkipped, 2); // same ids already present
    expect(result.documentsAdded, 0);
    expect(await documents.getAll(), hasLength(2));
  });

  test('import createNew person and skip another', () async {
    final (selfDocId, spouseDocId, spouse) = await seedVault();
    const password = 'backup-pass-123';
    final archiveBytes = await backup.exportVault(
      password,
      documentIds: {selfDocId, spouseDocId},
    );

    // Wipe only docs to simulate receiving on a device that has Me but not spouse docs
    await documents.delete(selfDocId);
    await documents.delete(spouseDocId);
    await people.delete(spouse.id);
    expect(await documents.getAll(), isEmpty);

    final self = await people.getSelf();
    final preview = await backup.previewImport(archiveBytes, password);
    final backupSpouse =
        preview.manifest.people.firstWhere((p) => !p.isSelf);

    final result = await backup.importVault(
      archiveBytes,
      password,
      decisions: [
        PersonImportDecision(
          backupPersonId: preview.manifest.people.firstWhere((p) => p.isSelf).id,
          action: PersonImportAction.mergeExisting,
          targetLocalPersonId: self.id,
          newDisplayName: 'Varun',
          updateLocalMeName: true,
        ),
        PersonImportDecision(
          backupPersonId: backupSpouse.id,
          action: PersonImportAction.createNew,
          newDisplayName: 'Priya Kumar',
          newRelationship: PersonRelationship.spouse,
        ),
      ],
    );

    expect(result.documentsAdded, 2);
    expect(result.peopleCreated, 1);
    expect(result.peopleSkipped, 0);

    final restored = await documents.getAll();
    expect(restored, hasLength(2));
    expect(
      restored.any((d) => d.title == 'Passport'),
      isTrue,
    );
    final peopleList = await people.getAll();
    expect(
      peopleList.any((p) => p.displayName == 'Priya Kumar'),
      isTrue,
    );
  });

  test('import skip person leaves their docs out', () async {
    final (selfDocId, spouseDocId, spouse) = await seedVault();
    const password = 'backup-pass-123';
    final archiveBytes = await backup.exportVault(
      password,
      documentIds: {selfDocId, spouseDocId},
    );

    await documents.delete(selfDocId);
    await documents.delete(spouseDocId);
    await people.delete(spouse.id);

    final self = await people.getSelf();
    final preview = await backup.previewImport(archiveBytes, password);
    final backupSelf = preview.manifest.people.firstWhere((p) => p.isSelf);
    final backupSpouse = preview.manifest.people.firstWhere((p) => !p.isSelf);

    final result = await backup.importVault(
      archiveBytes,
      password,
      decisions: [
        PersonImportDecision(
          backupPersonId: backupSelf.id,
          action: PersonImportAction.mergeExisting,
          targetLocalPersonId: self.id,
        ),
        PersonImportDecision(
          backupPersonId: backupSpouse.id,
          action: PersonImportAction.skip,
        ),
      ],
    );

    expect(result.documentsAdded, 1);
    expect(result.peopleSkipped, 1);
    final restored = await documents.getAll();
    expect(restored, hasLength(1));
    expect(restored.single.title, 'Aadhaar');
    expect(restored.single.personId, self.id);
  });

  test('wrong password fails without changing vault', () async {
    final (selfDocId, _, _) = await seedVault();
    final archiveBytes = await backup.exportVault(
      'correct-password',
      documentIds: {selfDocId},
    );
    expect(
      () => backup.previewImport(archiveBytes, 'wrong-password'),
      throwsA(isA<AppException>()),
    );
    expect(await documents.getAll(), hasLength(2));
  });

  test('rejects empty document selection', () async {
    expect(
      () => backup.exportVault('backup-pass-123', documentIds: {}),
      throwsA(isA<AppException>()),
    );
  });
}
