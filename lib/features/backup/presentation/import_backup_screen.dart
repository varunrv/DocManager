import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app.dart';
import '../../../app/widgets/constrained_page_body.dart';
import '../../../core/errors.dart';
import '../../../core/providers.dart';
import '../../categories/presentation/categories_providers.dart';
import '../../documents/presentation/document_providers.dart';
import '../../people/domain/person.dart';
import '../../people/presentation/people_providers.dart';
import '../domain/backup_import.dart';

/// Holds the active import preview between password unlock and wizard finish.
final backupImportPreviewProvider =
    StateProvider<BackupPreview?>((ref) => null);

final backupImportPasswordProvider = StateProvider<String?>((ref) => null);

class ImportBackupScreen extends ConsumerStatefulWidget {
  const ImportBackupScreen({super.key});

  @override
  ConsumerState<ImportBackupScreen> createState() => _ImportBackupScreenState();
}

class _ImportBackupScreenState extends ConsumerState<ImportBackupScreen> {
  var _index = 0;
  var _importing = false;
  final _decisions = <String, _PersonDecisionDraft>{};

  @override
  void dispose() {
    for (final draft in _decisions.values) {
      draft.nameController.dispose();
      draft.otherController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preview = ref.watch(backupImportPreviewProvider);
    final localPeople = ref.watch(peopleProvider).value ?? const <Person>[];

    if (preview == null || preview.people.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Import backup')),
        body: const Center(child: Text('No backup loaded.')),
      );
    }

    final summaries = preview.people;
    final current = summaries[_index];
    final draft = _decisions.putIfAbsent(
      current.person.id,
      () => _PersonDecisionDraft.initial(current, localPeople),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Person ${_index + 1} of ${summaries.length}'),
      ),
      body: ConstrainedPageBody(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'How should this person be saved on this device?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: Icon(
                  current.person.isSelf ? Icons.person : Icons.people_outline,
                ),
                title: Text(current.label),
                subtitle: Text(
                  '${current.documentCount} document${current.documentCount == 1 ? '' : 's'} in backup',
                ),
              ),
            ),
            const SizedBox(height: 16),
            RadioGroup<PersonImportAction>(
              groupValue: draft.action,
              onChanged: (value) {
                if (value == null) return;
                setState(() => draft.action = value);
              },
              child: Column(
                children: [
                  RadioListTile<PersonImportAction>(
                    value: PersonImportAction.mergeExisting,
                    title: const Text('Merge into existing person'),
                    subtitle: const Text(
                      'Attach these documents to someone already on this device.',
                    ),
                  ),
                  RadioListTile<PersonImportAction>(
                    value: PersonImportAction.createNew,
                    title: Text(
                      current.person.isSelf
                          ? 'Save onto Me (update name)'
                          : 'Create as new person',
                    ),
                    subtitle: Text(
                      current.person.isSelf
                          ? 'Documents go to your Me profile.'
                          : 'Add a new profile with the name and relationship you choose.',
                    ),
                  ),
                  RadioListTile<PersonImportAction>(
                    value: PersonImportAction.skip,
                    title: const Text('Skip'),
                    subtitle: const Text(
                      'Do not import this person’s documents.',
                    ),
                  ),
                ],
              ),
            ),
            if (draft.action == PersonImportAction.mergeExisting) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: ValueKey('merge-${current.person.id}-${draft.targetLocalPersonId}'),
                initialValue: draft.targetLocalPersonId,
                decoration: const InputDecoration(
                  labelText: 'Merge into',
                ),
                items: [
                  for (final person in localPeople)
                    DropdownMenuItem(
                      value: person.id,
                      child: Text(
                        person.isSelf
                            ? '${person.displayName} (Me)'
                            : person.ownerLabel,
                      ),
                    ),
                ],
                onChanged: (value) {
                  setState(() => draft.targetLocalPersonId = value);
                },
              ),
              if (current.person.isSelf &&
                  draft.targetLocalPersonId ==
                      localPeople.where((p) => p.isSelf).firstOrNull?.id) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: draft.nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Update my name (optional)',
                    hintText: 'Leave blank to keep current name',
                  ),
                ),
              ],
            ],
            if (draft.action == PersonImportAction.createNew) ...[
              const SizedBox(height: 8),
              TextField(
                controller: draft.nameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: current.person.isSelf ? 'My name' : 'Name',
                ),
              ),
              if (!current.person.isSelf) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<PersonRelationship>(
                  key: ValueKey('rel-${current.person.id}-${draft.relationship}'),
                  initialValue: draft.relationship,
                  decoration: const InputDecoration(labelText: 'Relationship'),
                  items: [
                    for (final value in PersonRelationship.values.where(
                      (r) => r != PersonRelationship.self,
                    ))
                      DropdownMenuItem(
                        value: value,
                        child: Text(_relationshipTitle(value)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => draft.relationship = value);
                    }
                  },
                ),
                if (draft.relationship == PersonRelationship.other) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: draft.otherController,
                    decoration: const InputDecoration(
                      labelText: 'Custom relationship',
                    ),
                  ),
                ],
              ],
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              if (_index > 0)
                TextButton(
                  onPressed: _importing
                      ? null
                      : () => setState(() => _index -= 1),
                  child: const Text('Back'),
                ),
              const Spacer(),
              FilledButton(
                onPressed: _importing
                    ? null
                    : () => _onPrimary(summaries, current, draft),
                child: _importing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _index == summaries.length - 1 ? 'Import' : 'Next',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onPrimary(
    List<BackupPersonSummary> summaries,
    BackupPersonSummary current,
    _PersonDecisionDraft draft,
  ) async {
    final error = draft.validate(current);
    if (error != null) {
      showAppMessage(context, error);
      return;
    }

    if (_index < summaries.length - 1) {
      setState(() => _index += 1);
      return;
    }

    await _runImport(summaries);
  }

  Future<void> _runImport(List<BackupPersonSummary> summaries) async {
    final preview = ref.read(backupImportPreviewProvider);
    final password = ref.read(backupImportPasswordProvider);
    if (preview == null || password == null) return;

    final decisions = <PersonImportDecision>[];
    for (final summary in summaries) {
      final draft = _decisions[summary.person.id] ??
          _PersonDecisionDraft.initial(
            summary,
            ref.read(peopleProvider).value ?? const [],
          );
      decisions.add(draft.toDecision(summary));
    }

    setState(() => _importing = true);
    try {
      final result = await ref.read(vaultBackupServiceProvider).importVault(
            Uint8List.fromList(preview.payload),
            password,
            decisions: decisions,
          );
      ref.invalidate(storageBytesProvider);
      ref.invalidate(allDocumentsProvider);
      ref.invalidate(peopleProvider);
      ref.invalidate(categoriesProvider);
      ref.read(backupImportPreviewProvider.notifier).state = null;
      ref.read(backupImportPasswordProvider.notifier).state = null;
      if (mounted) {
        showAppMessage(context, result.summaryMessage);
        context.pop();
      }
    } on AppException catch (error) {
      if (mounted) showAppMessage(context, error.message);
    } catch (_) {
      if (mounted) showAppMessage(context, 'Could not import backup.');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }
}

class _PersonDecisionDraft {
  _PersonDecisionDraft({
    required this.action,
    required this.targetLocalPersonId,
    required this.relationship,
    required this.nameController,
    required this.otherController,
  });

  PersonImportAction action;
  String? targetLocalPersonId;
  PersonRelationship relationship;
  final TextEditingController nameController;
  final TextEditingController otherController;

  factory _PersonDecisionDraft.initial(
    BackupPersonSummary summary,
    List<Person> localPeople,
  ) {
    final localSelf = localPeople.where((p) => p.isSelf).firstOrNull;
    Person? suggestedMerge;
    if (summary.person.isSelf) {
      suggestedMerge = localSelf;
    } else {
      for (final person in localPeople) {
        if (!person.isSelf &&
            person.displayName.toLowerCase() ==
                summary.person.displayName.toLowerCase()) {
          suggestedMerge = person;
          break;
        }
      }
    }

    final action = summary.person.isSelf || suggestedMerge != null
        ? PersonImportAction.mergeExisting
        : PersonImportAction.createNew;

    final backupRel = relationshipFromStorage(summary.person.relationship);

    return _PersonDecisionDraft(
      action: action,
      targetLocalPersonId: suggestedMerge?.id ?? localSelf?.id,
      relationship: backupRel == PersonRelationship.self
          ? PersonRelationship.other
          : backupRel,
      nameController: TextEditingController(text: summary.person.displayName),
      otherController: TextEditingController(
        text: summary.person.relationshipLabel ?? '',
      ),
    );
  }

  String? validate(BackupPersonSummary summary) {
    switch (action) {
      case PersonImportAction.skip:
        return null;
      case PersonImportAction.mergeExisting:
        if (targetLocalPersonId == null || targetLocalPersonId!.isEmpty) {
          return 'Choose who to merge into.';
        }
        return null;
      case PersonImportAction.createNew:
        final name = nameController.text.trim();
        if (name.isEmpty) return 'Enter a name.';
        if (summary.person.isSelf && isPlaceholderSelfName(name)) {
          return 'Enter your real name (not “Me”).';
        }
        return null;
    }
  }

  PersonImportDecision toDecision(BackupPersonSummary summary) {
    final name = nameController.text.trim();
    return PersonImportDecision(
      backupPersonId: summary.person.id,
      action: action,
      targetLocalPersonId: targetLocalPersonId,
      newDisplayName: name.isEmpty ? null : name,
      newRelationship: relationship,
      relationshipLabel: relationship == PersonRelationship.other
          ? otherController.text.trim()
          : null,
      updateLocalMeName: name.isNotEmpty && !isPlaceholderSelfName(name),
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
