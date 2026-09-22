import 'dart:convert';

import '../../categories/domain/category.dart';
import '../../documents/domain/document.dart';
import '../../people/domain/person.dart';

const backupFormatVersion = 1;

class BackupManifest {
  const BackupManifest({
    required this.formatVersion,
    required this.exportedAt,
    required this.people,
    required this.categories,
    required this.documents,
  });

  final int formatVersion;
  final DateTime exportedAt;
  final List<BackupPerson> people;
  final List<BackupCategory> categories;
  final List<BackupDocument> documents;

  Map<String, dynamic> toJson() => {
        'formatVersion': formatVersion,
        'exportedAt': exportedAt.toUtc().toIso8601String(),
        'people': people.map((p) => p.toJson()).toList(),
        'categories': categories.map((c) => c.toJson()).toList(),
        'documents': documents.map((d) => d.toJson()).toList(),
      };

  factory BackupManifest.fromJson(Map<String, dynamic> json) {
    return BackupManifest(
      formatVersion: json['formatVersion'] as int? ?? 0,
      exportedAt: DateTime.parse(json['exportedAt'] as String),
      people: (json['people'] as List<dynamic>)
          .map((e) => BackupPerson.fromJson(e as Map<String, dynamic>))
          .toList(),
      categories: (json['categories'] as List<dynamic>)
          .map((e) => BackupCategory.fromJson(e as Map<String, dynamic>))
          .toList(),
      documents: (json['documents'] as List<dynamic>)
          .map((e) => BackupDocument.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  static BackupManifest fromVault({
    required List<Person> people,
    required List<Category> categories,
    required List<Document> documents,
  }) {
    return BackupManifest(
      formatVersion: backupFormatVersion,
      exportedAt: DateTime.now().toUtc(),
      people: people.map(BackupPerson.fromPerson).toList(),
      categories: categories.map(BackupCategory.fromCategory).toList(),
      documents: documents.map(BackupDocument.fromDocument).toList(),
    );
  }
}

class BackupPerson {
  const BackupPerson({
    required this.id,
    required this.displayName,
    required this.relationship,
    this.relationshipLabel,
    required this.isSelf,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String displayName;
  final String relationship;
  final String? relationshipLabel;
  final bool isSelf;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory BackupPerson.fromPerson(Person person) {
    return BackupPerson(
      id: person.id,
      displayName: person.displayName,
      relationship: person.relationship.name,
      relationshipLabel: person.relationshipLabel,
      isSelf: person.isSelf,
      createdAt: person.createdAt,
      updatedAt: person.updatedAt,
    );
  }

  Person toPerson() {
    return Person(
      id: id,
      displayName: displayName,
      relationship: relationshipFromStorage(relationship),
      relationshipLabel: relationshipLabel,
      isSelf: isSelf,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'relationship': relationship,
        'relationshipLabel': relationshipLabel,
        'isSelf': isSelf,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory BackupPerson.fromJson(Map<String, dynamic> json) {
    return BackupPerson(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      relationship: json['relationship'] as String,
      relationshipLabel: json['relationshipLabel'] as String?,
      isSelf: json['isSelf'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class BackupCategory {
  const BackupCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.sortOrder,
    required this.isDefault,
  });

  final String id;
  final String name;
  final String icon;
  final int sortOrder;
  final bool isDefault;

  factory BackupCategory.fromCategory(Category category) {
    return BackupCategory(
      id: category.id,
      name: category.name,
      icon: category.icon,
      sortOrder: category.sortOrder,
      isDefault: category.isDefault,
    );
  }

  Category toCategory() {
    return Category(
      id: id,
      name: name,
      icon: icon,
      sortOrder: sortOrder,
      isDefault: isDefault,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'sortOrder': sortOrder,
        'isDefault': isDefault,
      };

  factory BackupCategory.fromJson(Map<String, dynamic> json) {
    return BackupCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String,
      sortOrder: json['sortOrder'] as int,
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }
}

class BackupDocument {
  const BackupDocument({
    required this.id,
    required this.personId,
    required this.title,
    required this.categoryId,
    required this.tags,
    required this.notes,
    required this.originalFileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.storageKey,
    this.thumbnailKey,
    this.expiresAt,
    required this.reminderEnabled,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String personId;
  final String title;
  final String categoryId;
  final List<String> tags;
  final String notes;
  final String originalFileName;
  final String mimeType;
  final int sizeBytes;
  final String storageKey;
  final String? thumbnailKey;
  final DateTime? expiresAt;
  final bool reminderEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory BackupDocument.fromDocument(Document document) {
    return BackupDocument(
      id: document.id,
      personId: document.personId,
      title: document.title,
      categoryId: document.categoryId,
      tags: document.tags,
      notes: document.notes,
      originalFileName: document.originalFileName,
      mimeType: document.mimeType,
      sizeBytes: document.sizeBytes,
      storageKey: document.storageKey,
      thumbnailKey: document.thumbnailKey,
      expiresAt: document.expiresAt,
      reminderEnabled: document.reminderEnabled,
      createdAt: document.createdAt,
      updatedAt: document.updatedAt,
    );
  }

  Document toDocument() {
    return Document(
      id: id,
      personId: personId,
      title: title,
      categoryId: categoryId,
      tags: tags,
      notes: notes,
      originalFileName: originalFileName,
      mimeType: mimeType,
      sizeBytes: sizeBytes,
      storageKey: storageKey,
      thumbnailKey: thumbnailKey,
      expiresAt: expiresAt,
      reminderEnabled: reminderEnabled,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'personId': personId,
        'title': title,
        'categoryId': categoryId,
        'tags': tags,
        'notes': notes,
        'originalFileName': originalFileName,
        'mimeType': mimeType,
        'sizeBytes': sizeBytes,
        'storageKey': storageKey,
        'thumbnailKey': thumbnailKey,
        'expiresAt': expiresAt?.toUtc().toIso8601String(),
        'reminderEnabled': reminderEnabled,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory BackupDocument.fromJson(Map<String, dynamic> json) {
    return BackupDocument(
      id: json['id'] as String,
      personId: json['personId'] as String,
      title: json['title'] as String,
      categoryId: json['categoryId'] as String,
      tags: (json['tags'] as List<dynamic>).map((e) => e.toString()).toList(),
      notes: json['notes'] as String? ?? '',
      originalFileName: json['originalFileName'] as String,
      mimeType: json['mimeType'] as String,
      sizeBytes: json['sizeBytes'] as int,
      storageKey: json['storageKey'] as String,
      thumbnailKey: json['thumbnailKey'] as String?,
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.parse(json['expiresAt'] as String),
      reminderEnabled: json['reminderEnabled'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

String encodeManifest(BackupManifest manifest) =>
    const JsonEncoder.withIndent('  ').convert(manifest.toJson());

BackupManifest decodeManifest(String raw) =>
    BackupManifest.fromJson(jsonDecode(raw) as Map<String, dynamic>);
