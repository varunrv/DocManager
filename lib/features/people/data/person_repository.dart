import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/errors.dart';
import '../domain/person.dart';

class PersonRepository {
  PersonRepository(this._db);

  final AppDatabase _db;

  Stream<List<Person>> watchAll() {
    final query = _db.select(_db.people)
      ..orderBy([
        (tbl) => OrderingTerm.desc(tbl.isSelf),
        (tbl) => OrderingTerm.asc(tbl.displayName),
      ]);
    return query.watch().map((rows) => rows.map(personFromRow).toList());
  }

  Future<List<Person>> getAll() async {
    final rows = await (_db.select(_db.people)..orderBy([
          (tbl) => OrderingTerm.desc(tbl.isSelf),
          (tbl) => OrderingTerm.asc(tbl.displayName),
        ]))
        .get();
    return rows.map(personFromRow).toList();
  }

  Future<Person> getSelf() async {
    final row = await (_db.select(_db.people)
          ..where((tbl) => tbl.isSelf.equals(true)))
        .getSingle();
    return personFromRow(row);
  }

  Future<Person?> getById(String id) async {
    final row = await (_db.select(_db.people)..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : personFromRow(row);
  }

  Future<Person> add({
    required String displayName,
    required PersonRelationship relationship,
    String? relationshipLabel,
  }) async {
    if (relationship == PersonRelationship.self) {
      throw const AppException('There can only be one Me profile.');
    }
    final now = DateTime.now();
    final id = newId();
    await _db.into(_db.people).insert(
          PeopleCompanion.insert(
            id: id,
            displayName: displayName.trim(),
            relationship: relationship.name,
            relationshipLabel: Value(relationshipLabel?.trim()),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return (await getById(id))!;
  }

  Future<void> update(Person person) async {
    if (person.isSelf && person.relationship != PersonRelationship.self) {
      throw const AppException('The Me profile must stay assigned to you.');
    }
    await (_db.update(_db.people)..where((tbl) => tbl.id.equals(person.id)))
        .write(
      PeopleCompanion(
        displayName: Value(person.displayName.trim()),
        relationship: Value(person.relationship.name),
        relationshipLabel: Value(person.relationshipLabel?.trim()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> documentCount(String personId) async {
    final count = _db.documents.id.count();
    final query = _db.selectOnly(_db.documents)
      ..addColumns([count])
      ..where(_db.documents.personId.equals(personId));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  Future<void> delete(String id) async {
    final person = await getById(id);
    if (person == null) return;
    if (person.isSelf) {
      throw const AppException('You cannot delete the Me profile.');
    }
    final owned = await documentCount(id);
    if (owned > 0) {
      throw AppException(
        'Move or delete $owned document${owned == 1 ? '' : 's'} first.',
      );
    }
    await (_db.delete(_db.people)..where((tbl) => tbl.id.equals(id))).go();
  }
}
