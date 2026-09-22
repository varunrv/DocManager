import '../domain/backup_manifest.dart';
import '../../people/domain/person.dart';

enum PersonImportAction { mergeExisting, createNew, skip }

class BackupPersonSummary {
  const BackupPersonSummary({
    required this.person,
    required this.documentCount,
  });

  final BackupPerson person;
  final int documentCount;

  String get label {
    if (person.isSelf) {
      return '${person.displayName} (Me in backup)';
    }
    final rel = relationshipFromStorage(person.relationship).name;
    return '${person.displayName} · ${_titleCase(rel)}';
  }
}

class BackupPreview {
  const BackupPreview({
    required this.exportedAt,
    required this.people,
    required this.manifest,
    required this.payload,
  });

  final DateTime exportedAt;
  final List<BackupPersonSummary> people;
  final BackupManifest manifest;

  /// Encrypted original bytes kept so import can re-open the archive.
  final List<int> payload;
}

class PersonImportDecision {
  const PersonImportDecision({
    required this.backupPersonId,
    required this.action,
    this.targetLocalPersonId,
    this.newDisplayName,
    this.newRelationship,
    this.relationshipLabel,
    this.updateLocalMeName = false,
  });

  final String backupPersonId;
  final PersonImportAction action;
  final String? targetLocalPersonId;
  final String? newDisplayName;
  final PersonRelationship? newRelationship;
  final String? relationshipLabel;
  final bool updateLocalMeName;
}

class BackupImportResult {
  const BackupImportResult({
    required this.peopleCreated,
    required this.documentsAdded,
    required this.documentsSkipped,
    required this.categoriesAdded,
    required this.peopleSkipped,
  });

  final int peopleCreated;
  final int documentsAdded;
  final int documentsSkipped;
  final int categoriesAdded;
  final int peopleSkipped;

  String get summaryMessage {
    final parts = <String>[];
    if (documentsAdded > 0) {
      parts.add(
        'Added $documentsAdded document${documentsAdded == 1 ? '' : 's'}',
      );
    }
    if (peopleCreated > 0) {
      parts.add(
        'created $peopleCreated person${peopleCreated == 1 ? '' : 's'}',
      );
    }
    if (documentsSkipped > 0) {
      parts.add(
        'skipped $documentsSkipped existing document${documentsSkipped == 1 ? '' : 's'}',
      );
    }
    if (peopleSkipped > 0) {
      parts.add(
        'skipped $peopleSkipped person${peopleSkipped == 1 ? '' : 's'}',
      );
    }
    if (parts.isEmpty) return 'Nothing was imported.';
    return '${parts.join(', ')}.';
  }
}

bool isPlaceholderSelfName(String name) {
  final trimmed = name.trim();
  return trimmed.isEmpty || trimmed.toLowerCase() == 'me';
}

String _titleCase(String value) {
  if (value.isEmpty) return value;
  return '${value[0].toUpperCase()}${value.substring(1)}';
}
