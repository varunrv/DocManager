enum PersonRelationship { self, spouse, child, parent, sibling, other }

class Person {
  const Person({
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
  final PersonRelationship relationship;
  final String? relationshipLabel;
  final bool isSelf;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get relationshipDisplay {
    switch (relationship) {
      case PersonRelationship.self:
        return 'Self';
      case PersonRelationship.spouse:
        return 'Spouse';
      case PersonRelationship.child:
        return 'Child';
      case PersonRelationship.parent:
        return 'Parent';
      case PersonRelationship.sibling:
        return 'Sibling';
      case PersonRelationship.other:
        final label = relationshipLabel?.trim();
        return (label != null && label.isNotEmpty) ? label : 'Other';
    }
  }

  String get ownerLabel =>
      isSelf ? displayName : '$displayName · $relationshipDisplay';

  Person copyWith({
    String? displayName,
    PersonRelationship? relationship,
    String? relationshipLabel,
    DateTime? updatedAt,
  }) {
    return Person(
      id: id,
      displayName: displayName ?? this.displayName,
      relationship: relationship ?? this.relationship,
      relationshipLabel: relationshipLabel ?? this.relationshipLabel,
      isSelf: isSelf,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

PersonRelationship relationshipFromStorage(String value) {
  return PersonRelationship.values.firstWhere(
    (item) => item.name == value,
    orElse: () => PersonRelationship.other,
  );
}
