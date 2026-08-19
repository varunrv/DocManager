import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/errors.dart';
import '../domain/category.dart';

class CategoryRepository {
  CategoryRepository(this._db);

  final AppDatabase _db;

  Stream<List<Category>> watchAll() {
    final query = _db.select(_db.categories)
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.sortOrder)]);
    return query.watch().map((rows) => rows.map(categoryFromRow).toList());
  }

  Future<List<Category>> getAll() async {
    final rows = await (_db.select(_db.categories)
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.sortOrder)]))
        .get();
    return rows.map(categoryFromRow).toList();
  }

  Future<Category?> getById(String id) async {
    final row = await (_db.select(_db.categories)
          ..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : categoryFromRow(row);
  }

  Future<Category> addCustom(String name) async {
    final existing = await getAll();
    final nextOrder = existing.isEmpty
        ? 0
        : existing.map((item) => item.sortOrder).reduce((a, b) => a > b ? a : b) +
            1;
    final id = newId();
    await _db.into(_db.categories).insert(
          CategoriesCompanion.insert(
            id: id,
            name: name.trim(),
            icon: 'folder',
            sortOrder: nextOrder,
          ),
        );
    return (await getById(id))!;
  }

  Future<int> documentCount(String categoryId) async {
    final count = _db.documents.id.count();
    final query = _db.selectOnly(_db.documents)
      ..addColumns([count])
      ..where(_db.documents.categoryId.equals(categoryId));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  Future<void> delete(String id) async {
    final category = await getById(id);
    if (category == null) return;
    if (category.isDefault) {
      throw const AppException('Default categories cannot be deleted.');
    }
    final owned = await documentCount(id);
    if (owned > 0) {
      throw AppException(
        'Move or delete $owned document${owned == 1 ? '' : 's'} first.',
      );
    }
    await (_db.delete(_db.categories)..where((tbl) => tbl.id.equals(id))).go();
  }
}
