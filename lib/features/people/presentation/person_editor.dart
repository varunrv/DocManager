import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app.dart';
import '../../../core/errors.dart';
import '../../../core/providers.dart';
import '../domain/person.dart';

Future<Person?> showPersonEditor(
  BuildContext context, {
  Person? existing,
}) {
  return showDialog<Person>(
    context: context,
    builder: (context) => PersonEditorDialog(existing: existing),
  );
}

class PersonEditorDialog extends ConsumerStatefulWidget {
  const PersonEditorDialog({super.key, this.existing});

  final Person? existing;

  @override
  ConsumerState<PersonEditorDialog> createState() => _PersonEditorDialogState();
}

class _PersonEditorDialogState extends ConsumerState<PersonEditorDialog> {
  final _nameController = TextEditingController();
  final _otherController = TextEditingController();
  late PersonRelationship _relationship;
  var _saving = false;

  bool get _isSelf => widget.existing?.isSelf ?? false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _nameController.text = existing.displayName;
      _relationship = existing.relationship;
      _otherController.text = existing.relationshipLabel ?? '';
    } else {
      _relationship = PersonRelationship.spouse;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _otherController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      showAppMessage(context, 'Enter a name.');
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(personRepositoryProvider);
    try {
      if (widget.existing == null) {
        final created = await repo.add(
          displayName: name,
          relationship: _relationship,
          relationshipLabel: _relationship == PersonRelationship.other
              ? _otherController.text
              : null,
        );
        if (mounted) Navigator.pop(context, created);
      } else {
        final updated = widget.existing!.copyWith(
          displayName: name,
          relationship: _isSelf ? PersonRelationship.self : _relationship,
          relationshipLabel: _relationship == PersonRelationship.other
              ? _otherController.text
              : null,
        );
        await repo.update(updated);
        if (mounted) Navigator.pop(context, updated);
      }
    } on AppException catch (error) {
      if (mounted) showAppMessage(context, error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final familyRelationships = PersonRelationship.values
        .where((value) => value != PersonRelationship.self)
        .toList();

    return AlertDialog(
      title: Text(widget.existing == null ? 'Add someone' : 'Edit person'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Aarav, Mom, ...',
              ),
            ),
            if (!_isSelf) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<PersonRelationship>(
                key: ValueKey(_relationship),
                initialValue: _relationship,
                decoration: const InputDecoration(labelText: 'Relationship'),
                items: [
                  for (final value in familyRelationships)
                    DropdownMenuItem(
                      value: value,
                      child: Text(_relationshipTitle(value)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _relationship = value);
                },
              ),
              if (_relationship == PersonRelationship.other) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _otherController,
                  decoration: const InputDecoration(
                    labelText: 'Custom relationship',
                    hintText: 'Uncle, Cousin, ...',
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

String _relationshipTitle(PersonRelationship relationship) {
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
      return 'Other';
  }
}
