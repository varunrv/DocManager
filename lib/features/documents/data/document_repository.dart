import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/errors.dart';
import '../../../core/storage/file_store.dart';
import '../../../core/utils/thumbnails.dart';
import '../domain/document.dart';
import '../domain/document_list_item.dart';

class DocumentRepository {
  DocumentRepository(this._db, this._files);

  final AppDatabase _db;
  final FileStore _files;

  Stream<List<DocumentListItem>> watchAll({
    String? personId,
    String? categoryId,
    String query = '',
  }) {
    final joined = _db.select(_db.documents).join([
      innerJoin(_db.people, _db.people.id.equalsExp(_db.documents.personId)),
      innerJoin(
        _db.categories,
        _db.categories.id.equalsExp(_db.documents.categoryId),
      ),
    ]);

    Expression<bool>? predicate;
    if (personId != null) {
      predicate = _db.documents.personId.equals(personId);
    }
    if (categoryId != null) {
      final next = _db.documents.categoryId.equals(categoryId);
      predicate = predicate == null ? next : predicate & next;
    }
    if (predicate != null) {
      joined.where(predicate);
    }

    joined.orderBy([OrderingTerm.desc(_db.documents.updatedAt)]);

    final search = query.trim().toLowerCase();
    return joined.watch().map((rows) {
      final items = rows.map(_itemFromRow).toList();
      if (search.isEmpty) return items;
      return items.where((item) {
        final haystack = [
          item.document.title,
          item.document.notes,
          item.document.originalFileName,
          ...item.document.tags,
          item.person.displayName,
          item.person.relationshipDisplay,
        ].join(' ').toLowerCase();
        return haystack.contains(search);
      }).toList();
    });
  }

  Future<Document?> getById(String id) async {
    final row = await (_db.select(_db.documents)
          ..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : documentFromRow(row);
  }

  Future<DocumentListItem?> getListItem(String id) async {
    final joined = _db.select(_db.documents).join([
      innerJoin(_db.people, _db.people.id.equalsExp(_db.documents.personId)),
      innerJoin(
        _db.categories,
        _db.categories.id.equalsExp(_db.documents.categoryId),
      ),
    ])
      ..where(_db.documents.id.equals(id));
    final row = await joined.getSingleOrNull();
    return row == null ? null : _itemFromRow(row);
  }

  Future<Document> add({
    required String personId,
    required String title,
    required String categoryId,
    required List<String> tags,
    required String notes,
    required String originalFileName,
    required String mimeType,
    required Uint8List bytes,
    DateTime? expiresAt,
  }) async {
    final id = newId();
    await _persistFile(id, bytes, mimeType);
    final now = DateTime.now();
    try {
      await _db.into(_db.documents).insert(
            DocumentsCompanion.insert(
              id: id,
              personId: personId,
              title: title.trim(),
              categoryId: categoryId,
              tagsJson: Value(tagsToJson(tags)),
              notes: Value(notes.trim()),
              originalFileName: originalFileName,
              mimeType: mimeType,
              sizeBytes: bytes.length,
              storageKey: id,
              thumbnailKey: Value(await _thumbnailKeyIfPresent(id)),
              expiresAt: Value(expiresAt),
              createdAt: now,
              updatedAt: now,
            ),
          );
    } catch (error) {
      await _files.delete(id);
      await _files.delete(_thumbKey(id));
      rethrow;
    }
    return (await getById(id))!;
  }

  Future<void> update({
    required String id,
    required String personId,
    required String title,
    required String categoryId,
    required List<String> tags,
    required String notes,
    DateTime? expiresAt,
    String? originalFileName,
    String? mimeType,
    Uint8List? bytes,
  }) async {
    final existing = await getById(id);
    if (existing == null) {
      throw const AppException('Document not found.');
    }

    if (bytes != null && mimeType != null && originalFileName != null) {
      await _persistFile(id, bytes, mimeType);
    }

    await (_db.update(_db.documents)..where((tbl) => tbl.id.equals(id))).write(
      DocumentsCompanion(
        personId: Value(personId),
        title: Value(title.trim()),
        categoryId: Value(categoryId),
        tagsJson: Value(tagsToJson(tags)),
        notes: Value(notes.trim()),
        expiresAt: Value(expiresAt),
        originalFileName: originalFileName != null
            ? Value(originalFileName)
            : const Value.absent(),
        mimeType: mimeType != null ? Value(mimeType) : const Value.absent(),
        sizeBytes: bytes != null ? Value(bytes.length) : const Value.absent(),
        thumbnailKey: bytes != null
            ? Value(await _thumbnailKeyIfPresent(id))
            : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> delete(String id) async {
    final existing = await getById(id);
    if (existing == null) return;
    await _files.delete(existing.storageKey);
    if (existing.thumbnailKey != null) {
      await _files.delete(existing.thumbnailKey!);
    }
    await (_db.delete(_db.documents)..where((tbl) => tbl.id.equals(id))).go();
  }

  Future<Uint8List> readFile(Document document) =>
      _files.read(document.storageKey);

  Future<Uint8List?> readThumbnail(Document document) async {
    final key = document.thumbnailKey;
    if (key == null) return null;
    try {
      return await _files.read(key);
    } catch (_) {
      return null;
    }
  }

  Future<int> storageBytes() => _files.totalBytes();

  DocumentListItem _itemFromRow(TypedResult row) {
    return DocumentListItem(
      document: documentFromRow(row.readTable(_db.documents)),
      person: personFromRow(row.readTable(_db.people)),
      category: categoryFromRow(row.readTable(_db.categories)),
    );
  }

  String _thumbKey(String id) => '$id-thumb';

  Future<void> _persistFile(String id, Uint8List bytes, String mimeType) async {
    await _files.write(id, bytes);
    final thumb = await generateThumbnail(bytes, mimeType);
    final thumbKey = _thumbKey(id);
    if (thumb != null) {
      await _files.write(thumbKey, thumb);
    } else {
      await _files.delete(thumbKey);
    }
  }

  Future<String?> _thumbnailKeyIfPresent(String id) async {
    try {
      await _files.read(_thumbKey(id));
      return _thumbKey(id);
    } catch (_) {
      return null;
    }
  }
}
