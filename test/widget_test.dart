import 'package:doc_manager/core/utils/formatters.dart';
import 'package:doc_manager/features/people/domain/person.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats byte sizes', () {
    expect(formatBytes(512), '512 B');
    expect(formatBytes(2048), '2.0 KB');
    expect(formatBytes(2 * 1024 * 1024), '2.0 MB');
  });

  test('parses tags and titles from file names', () {
    expect(parseTags(' passport, 2024, passport '), ['passport', '2024']);
    expect(titleFromFileName('aadhaar_card.pdf'), 'aadhaar card');
  });

  test('builds owner labels for self and family', () {
    final now = DateTime(2026, 1, 1);
    final me = Person(
      id: 'person-self',
      displayName: 'Me',
      relationship: PersonRelationship.self,
      isSelf: true,
      createdAt: now,
      updatedAt: now,
    );
    final child = Person(
      id: 'p2',
      displayName: 'Aarav',
      relationship: PersonRelationship.child,
      isSelf: false,
      createdAt: now,
      updatedAt: now,
    );
    expect(me.ownerLabel, 'Me');
    expect(child.ownerLabel, 'Aarav · Child');
  });
}
