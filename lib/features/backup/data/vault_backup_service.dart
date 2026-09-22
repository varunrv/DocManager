import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/errors.dart';
import '../../../core/storage/file_store.dart';
import '../../categories/data/category_repository.dart';
import '../../documents/data/document_repository.dart';
import '../../people/data/person_repository.dart';
import '../../people/domain/person.dart';
import '../domain/backup_import.dart';
import '../domain/backup_manifest.dart';

class VaultBackupService {
  VaultBackupService({
    required AppDatabase db,
    required DocumentRepository documents,
    required PersonRepository people,
    required CategoryRepository categories,
    required FileStore files,
  })  : _db = db,
        _documents = documents,
        _people = people,
        _categories = categories,
        _files = files;

  final AppDatabase _db;
  final DocumentRepository _documents;
  final PersonRepository _people;
  final CategoryRepository _categories;
  final FileStore _files;

  static const _saltLength = 16;
  static const _nonceLength = 12;
  static const _macLength = 16;
  static const _pbkdf2Iterations = 100000;

  /// Exports only the selected document ids.
  Future<Uint8List> exportVault(
    String password, {
    required Set<String> documentIds,
  }) async {
    if (password.trim().length < 8) {
      throw const AppException('Backup password must be at least 8 characters.');
    }
    if (documentIds.isEmpty) {
      throw const AppException('Select at least one document to export.');
    }

    final allPeople = await _people.getAll();
    final allCategories = await _categories.getAll();
    final allDocuments = await _documents.getAll();
    final selectedDocs =
        allDocuments.where((d) => documentIds.contains(d.id)).toList();
    if (selectedDocs.isEmpty) {
      throw const AppException('Select at least one document to export.');
    }

    final self = allPeople.where((p) => p.isSelf).firstOrNull;
    final includesSelfDocs = selectedDocs.any((d) => d.personId == self?.id);
    if (includesSelfDocs &&
        (self == null || isPlaceholderSelfName(self.displayName))) {
      throw const AppException(
        'Set your name in People before exporting your own documents.',
      );
    }

    final personIds = selectedDocs.map((d) => d.personId).toSet();
    final categoryIds = selectedDocs.map((d) => d.categoryId).toSet();
    final people = allPeople.where((p) => personIds.contains(p.id)).toList();
    final categories =
        allCategories.where((c) => categoryIds.contains(c.id)).toList();

    final manifest = BackupManifest.fromVault(
      people: people,
      categories: categories,
      documents: selectedDocs,
    );

    final archive = Archive();
    final manifestJson = utf8.encode(encodeManifest(manifest));
    archive.addFile(
      ArchiveFile('manifest.json', manifestJson.length, manifestJson),
    );

    for (final document in selectedDocs) {
      final bytes = await _documents.readFile(document);
      archive.addFile(
        ArchiveFile('files/${document.storageKey}', bytes.length, bytes),
      );
      final thumbKey = document.thumbnailKey;
      if (thumbKey != null) {
        final thumb = await _documents.readThumbnail(document);
        if (thumb != null) {
          archive.addFile(ArchiveFile('files/$thumbKey', thumb.length, thumb));
        }
      }
    }

    final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive));
    return _encrypt(zipBytes, password);
  }

  Future<BackupPreview> previewImport(
    Uint8List payload,
    String password,
  ) async {
    final decoded = await _decodeBackup(payload, password);
    final summaries = decoded.manifest.people.map((person) {
      final count = decoded.manifest.documents
          .where((d) => d.personId == person.id)
          .length;
      return BackupPersonSummary(person: person, documentCount: count);
    }).toList()
      ..sort((a, b) {
        if (a.person.isSelf != b.person.isSelf) {
          return a.person.isSelf ? -1 : 1;
        }
        return a.person.displayName.compareTo(b.person.displayName);
      });

    return BackupPreview(
      exportedAt: decoded.manifest.exportedAt,
      people: summaries,
      manifest: decoded.manifest,
      payload: payload,
    );
  }

  Future<BackupImportResult> importVault(
    Uint8List payload,
    String password, {
    required List<PersonImportDecision> decisions,
  }) async {
    if (decisions.isEmpty) {
      throw const AppException('Nothing selected to import.');
    }

    final decoded = await _decodeBackup(payload, password);
    final manifest = decoded.manifest;
    final archive = decoded.archive;

    final decisionByPerson = {
      for (final d in decisions) d.backupPersonId: d,
    };

    var peopleCreated = 0;
    var peopleSkipped = 0;
    var documentsAdded = 0;
    var documentsSkipped = 0;
    var categoriesAdded = 0;

    final personIdMap = <String, String>{};
    final localSelf = await _people.getSelf();
    final existingDocs = await _documents.getAll();
    final existingDocIds = existingDocs.map((d) => d.id).toSet();
    final existingCategories = {
      for (final c in await _categories.getAll()) c.id: c,
    };

    for (final backupPerson in manifest.people) {
      final decision = decisionByPerson[backupPerson.id];
      if (decision == null || decision.action == PersonImportAction.skip) {
        peopleSkipped++;
        continue;
      }

      if (decision.action == PersonImportAction.mergeExisting) {
        final targetId = decision.targetLocalPersonId;
        if (targetId == null || targetId.isEmpty) {
          throw const AppException('Choose who to merge into.');
        }
        final target = await _people.getById(targetId);
        if (target == null) {
          throw const AppException('Selected person no longer exists.');
        }
        personIdMap[backupPerson.id] = target.id;

        if (backupPerson.isSelf &&
            target.isSelf &&
            decision.updateLocalMeName &&
            decision.newDisplayName != null &&
            !isPlaceholderSelfName(decision.newDisplayName!)) {
          await _people.update(
            target.copyWith(displayName: decision.newDisplayName!.trim()),
          );
        }
        continue;
      }

      // createNew
      final name = (decision.newDisplayName ?? backupPerson.displayName).trim();
      if (name.isEmpty) {
        throw AppException('Enter a name for ${backupPerson.displayName}.');
      }

      if (backupPerson.isSelf) {
        // Never create a second Me — merge onto local Me instead.
        personIdMap[backupPerson.id] = localSelf.id;
        if (!isPlaceholderSelfName(name) &&
            (isPlaceholderSelfName(localSelf.displayName) ||
                decision.updateLocalMeName)) {
          await _people.update(localSelf.copyWith(displayName: name));
        }
        continue;
      }

      final relationship =
          decision.newRelationship ??
          relationshipFromStorage(backupPerson.relationship);
      if (relationship == PersonRelationship.self) {
        throw const AppException('Cannot create another Me profile.');
      }

      final created = await _people.add(
        displayName: name,
        relationship: relationship,
        relationshipLabel: relationship == PersonRelationship.other
            ? (decision.relationshipLabel ?? backupPerson.relationshipLabel)
            : null,
      );
      personIdMap[backupPerson.id] = created.id;
      peopleCreated++;
    }

    final docsToImport = manifest.documents
        .where((d) => personIdMap.containsKey(d.personId))
        .toList();

    for (final backupDoc in docsToImport) {
      final categoryId = backupDoc.categoryId;
      if (!existingCategories.containsKey(categoryId)) {
        final backupCat = manifest.categories
            .where((c) => c.id == categoryId)
            .firstOrNull;
        if (backupCat != null) {
          await _db.into(_db.categories).insert(
                CategoriesCompanion.insert(
                  id: backupCat.id,
                  name: backupCat.name,
                  icon: backupCat.icon,
                  sortOrder: backupCat.sortOrder,
                  isDefault: Value(backupCat.isDefault),
                ),
                mode: InsertMode.insertOrIgnore,
              );
          existingCategories[categoryId] = backupCat.toCategory();
          categoriesAdded++;
        }
      }
    }

    for (final backupDoc in docsToImport) {
      final mappedPersonId = personIdMap[backupDoc.personId]!;
      if (existingDocIds.contains(backupDoc.id)) {
        documentsSkipped++;
        continue;
      }

      final file = _archiveFile(archive, 'files/${backupDoc.storageKey}');
      if (file == null) {
        throw AppException('Backup is missing file for "${backupDoc.title}".');
      }

      // Use a fresh storage key if one somehow collides.
      var storageKey = backupDoc.storageKey;
      try {
        await _files.read(storageKey);
        storageKey = const Uuid().v4();
      } catch (_) {
        // Missing is expected for a new key.
      }

      await _files.write(storageKey, file.content);

      String? thumbnailKey;
      final thumbBackupKey = backupDoc.thumbnailKey;
      if (thumbBackupKey != null) {
        final thumbFile = _archiveFile(archive, 'files/$thumbBackupKey');
        if (thumbFile != null) {
          final thumbKey = storageKey == backupDoc.storageKey
              ? thumbBackupKey
              : '$storageKey-thumb';
          await _files.write(thumbKey, thumbFile.content);
          thumbnailKey = thumbKey;
        }
      }

      await _db.into(_db.documents).insert(
            DocumentsCompanion.insert(
              id: backupDoc.id,
              personId: mappedPersonId,
              title: backupDoc.title,
              categoryId: backupDoc.categoryId,
              tagsJson: Value(tagsToJson(backupDoc.tags)),
              notes: Value(backupDoc.notes),
              originalFileName: backupDoc.originalFileName,
              mimeType: backupDoc.mimeType,
              sizeBytes: backupDoc.sizeBytes,
              storageKey: storageKey,
              thumbnailKey: Value(thumbnailKey),
              expiresAt: Value(backupDoc.expiresAt),
              reminderEnabled: Value(backupDoc.reminderEnabled),
              createdAt: backupDoc.createdAt,
              updatedAt: backupDoc.updatedAt,
            ),
          );
      existingDocIds.add(backupDoc.id);
      documentsAdded++;
    }

    return BackupImportResult(
      peopleCreated: peopleCreated,
      documentsAdded: documentsAdded,
      documentsSkipped: documentsSkipped,
      categoriesAdded: categoriesAdded,
      peopleSkipped: peopleSkipped,
    );
  }

  Future<({BackupManifest manifest, Archive archive})> _decodeBackup(
    Uint8List payload,
    String password,
  ) async {
    if (password.trim().length < 8) {
      throw const AppException('Backup password must be at least 8 characters.');
    }
    final zipBytes = await _decrypt(payload, password);
    final archive = ZipDecoder().decodeBytes(zipBytes);
    final manifestFile = archive.files.firstWhere(
      (file) => file.name == 'manifest.json',
      orElse: () =>
          throw const AppException('Backup file is missing manifest.json.'),
    );
    final manifest = decodeManifest(utf8.decode(manifestFile.content));
    if (manifest.formatVersion != backupFormatVersion) {
      throw AppException(
        'Unsupported backup version (${manifest.formatVersion}).',
      );
    }
    return (manifest: manifest, archive: archive);
  }

  ArchiveFile? _archiveFile(Archive archive, String path) {
    for (final file in archive.files) {
      if (file.name == path) return file;
    }
    return null;
  }

  Future<Uint8List> _encrypt(Uint8List plaintext, String password) async {
    final salt = _randomBytes(_saltLength);
    final key = await _deriveKey(password, salt);
    final algorithm = AesGcm.with256bits();
    final nonce = _randomBytes(_nonceLength);
    final box = await algorithm.encrypt(
      plaintext,
      secretKey: key,
      nonce: nonce,
    );
    final out = Uint8List(
      _saltLength + _nonceLength + box.cipherText.length + _macLength,
    );
    out.setRange(0, _saltLength, salt);
    out.setRange(_saltLength, _saltLength + _nonceLength, nonce);
    out.setRange(
      _saltLength + _nonceLength,
      _saltLength + _nonceLength + box.cipherText.length,
      box.cipherText,
    );
    out.setRange(
      _saltLength + _nonceLength + box.cipherText.length,
      out.length,
      box.mac.bytes,
    );
    return out;
  }

  Future<Uint8List> _decrypt(Uint8List payload, String password) async {
    if (payload.length < _saltLength + _nonceLength + _macLength + 1) {
      throw const AppException('That backup file looks invalid.');
    }
    final salt = payload.sublist(0, _saltLength);
    final nonce = payload.sublist(_saltLength, _saltLength + _nonceLength);
    final macStart = payload.length - _macLength;
    final cipherText = payload.sublist(_saltLength + _nonceLength, macStart);
    final mac = Mac(payload.sublist(macStart));
    final key = await _deriveKey(password, salt);
    final algorithm = AesGcm.with256bits();
    try {
      final box = SecretBox(cipherText, nonce: nonce, mac: mac);
      return Uint8List.fromList(await algorithm.decrypt(box, secretKey: key));
    } catch (_) {
      throw const AppException('Wrong password or corrupted backup file.');
    }
  }

  Future<SecretKey> _deriveKey(String password, List<int> salt) {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _pbkdf2Iterations,
      bits: 256,
    );
    return pbkdf2.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
  }

  List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }
}
