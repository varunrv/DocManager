import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../features/categories/domain/category.dart' as domain;
import '../../features/documents/domain/document.dart' as domain;
import '../../features/people/domain/person.dart' as domain;

part 'app_database.g.dart';

@DataClassName('PersonRow')
class People extends Table {
  TextColumn get id => text()();
  TextColumn get displayName => text()();
  TextColumn get relationship => text()();
  TextColumn get relationshipLabel => text().nullable()();
  BoolColumn get isSelf => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('CategoryRow')
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get icon => text()();
  IntColumn get sortOrder => integer()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('DocumentRow')
class Documents extends Table {
  TextColumn get id => text()();
  TextColumn get personId => text().references(People, #id)();
  TextColumn get title => text()();
  TextColumn get categoryId => text().references(Categories, #id)();
  TextColumn get tagsJson => text().withDefault(const Constant('[]'))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  TextColumn get originalFileName => text()();
  TextColumn get mimeType => text()();
  IntColumn get sizeBytes => integer()();
  TextColumn get storageKey => text()();
  TextColumn get thumbnailKey => text().nullable()();
  DateTimeColumn get expiresAt => dateTime().nullable()();
  BoolColumn get reminderEnabled =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [People, Categories, Documents])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'docket'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (migrator) async {
          await migrator.createAll();
          await _seed();
        },
        onUpgrade: (migrator, from, to) async {
          if (from < 2) {
            await migrator.addColumn(
              documents,
              documents.reminderEnabled,
            );
          }
        },
      );

  Future<void> _seed() async {
    final now = DateTime.now();
    await into(people).insert(
      PeopleCompanion.insert(
        id: 'person-self',
        displayName: 'Me',
        relationship: domain.PersonRelationship.self.name,
        isSelf: const Value(true),
        createdAt: now,
        updatedAt: now,
      ),
    );

    const defaults = <(String, String, String, int)>[
      ('category-identity', 'Identity', 'badge', 0),
      ('category-education', 'Education', 'school', 1),
      ('category-finance', 'Finance', 'account_balance', 2),
      ('category-medical', 'Medical', 'medical_services', 3),
      ('category-vehicle', 'Vehicle', 'directions_car', 4),
      ('category-travel', 'Travel', 'flight', 5),
      ('category-other', 'Other', 'folder', 6),
    ];

    for (final item in defaults) {
      await into(categories).insert(
        CategoriesCompanion.insert(
          id: item.$1,
          name: item.$2,
          icon: item.$3,
          sortOrder: item.$4,
          isDefault: const Value(true),
        ),
      );
    }
  }
}

domain.Person personFromRow(PersonRow row) {
  return domain.Person(
    id: row.id,
    displayName: row.displayName,
    relationship: domain.relationshipFromStorage(row.relationship),
    relationshipLabel: row.relationshipLabel,
    isSelf: row.isSelf,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );
}

domain.Category categoryFromRow(CategoryRow row) {
  return domain.Category(
    id: row.id,
    name: row.name,
    icon: row.icon,
    sortOrder: row.sortOrder,
    isDefault: row.isDefault,
  );
}

domain.Document documentFromRow(DocumentRow row) {
  return domain.Document(
    id: row.id,
    personId: row.personId,
    title: row.title,
    categoryId: row.categoryId,
    tags: domainTagsFromJson(row.tagsJson),
    notes: row.notes,
    originalFileName: row.originalFileName,
    mimeType: row.mimeType,
    sizeBytes: row.sizeBytes,
    storageKey: row.storageKey,
    thumbnailKey: row.thumbnailKey,
    expiresAt: row.expiresAt,
    reminderEnabled: row.reminderEnabled,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );
}

List<String> domainTagsFromJson(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return decoded.map((item) => item.toString()).toList();
    }
  } catch (_) {}
  return const [];
}

String tagsToJson(List<String> tags) => jsonEncode(tags);

String newId() => const Uuid().v4();
