import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/app.dart';
import '../../../app/widgets/constrained_page_body.dart';
import '../../../core/errors.dart';
import '../../../core/providers.dart';
import '../../documents/domain/document_list_item.dart';
import '../../documents/presentation/document_providers.dart';
import '../../people/domain/person.dart';
import '../../settings/presentation/backup_password_dialog.dart';
import '../../settings/presentation/lock_providers.dart';
import '../domain/backup_import.dart';

enum _ExportStep { people, documents }

class ExportBackupScreen extends ConsumerStatefulWidget {
  const ExportBackupScreen({super.key});

  @override
  ConsumerState<ExportBackupScreen> createState() => _ExportBackupScreenState();
}

class _ExportBackupScreenState extends ConsumerState<ExportBackupScreen> {
  final _selectedIds = <String>{};
  var _initialized = false;
  var _exporting = false;
  var _step = _ExportStep.people;
  String? _activePersonId;

  Future<T> _runWithoutRelock<T>(Future<T> Function() action) async {
    final suspendCount = ref.read(lockSuspendCountProvider);
    ref.read(lockSuspendCountProvider.notifier).state = suspendCount + 1;
    try {
      return await action();
    } finally {
      final current = ref.read(lockSuspendCountProvider);
      ref.read(lockSuspendCountProvider.notifier).state =
          current > 0 ? current - 1 : 0;
    }
  }

  void _ensureSelection(List<DocumentListItem> items) {
    if (_initialized) return;
    _initialized = true;
    _selectedIds
      ..clear()
      ..addAll(items.map((item) => item.document.id));
  }

  Map<String, List<DocumentListItem>> _groupByPerson(
    List<DocumentListItem> items,
  ) {
    final grouped = <String, List<DocumentListItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.person.id, () => []).add(item);
    }
    return grouped;
  }

  List<Person> _peopleInOrder(List<DocumentListItem> items) {
    final seen = <String>{};
    final people = <Person>[];
    for (final item in items) {
      if (seen.add(item.person.id)) {
        people.add(item.person);
      }
    }
    people.sort((a, b) {
      if (a.isSelf != b.isSelf) return a.isSelf ? -1 : 1;
      return a.displayName.compareTo(b.displayName);
    });
    return people;
  }

  Set<String> _idsForPerson(List<DocumentListItem> docs) =>
      docs.map((item) => item.document.id).toSet();

  int _selectedCountFor(List<DocumentListItem> docs) =>
      docs.where((item) => _selectedIds.contains(item.document.id)).length;

  bool? _checkboxValue(int selected, int total) {
    if (total == 0 || selected == 0) return false;
    if (selected == total) return true;
    return null;
  }

  void _togglePerson(List<DocumentListItem> docs, bool select) {
    setState(() {
      if (select) {
        _selectedIds.addAll(_idsForPerson(docs));
      } else {
        _selectedIds.removeAll(_idsForPerson(docs));
      }
    });
  }

  void _toggleAllPeople(Map<String, List<DocumentListItem>> grouped, bool select) {
    setState(() {
      if (select) {
        _selectedIds
          ..clear()
          ..addAll(grouped.values.expand(_idsForPerson));
      } else {
        _selectedIds.clear();
      }
    });
  }

  void _toggleDoc(String id, bool selected) {
    setState(() {
      if (selected) {
        _selectedIds.add(id);
      } else {
        _selectedIds.remove(id);
      }
    });
  }

  Future<bool> _ensureSelfNameIfNeeded(List<DocumentListItem> items) async {
    final selfItems = items.where(
      (item) => _selectedIds.contains(item.document.id) && item.person.isSelf,
    );
    if (selfItems.isEmpty) return true;

    final self = selfItems.first.person;
    if (!isPlaceholderSelfName(self.displayName)) return true;

    final name = await showDialog<String>(
      context: context,
      builder: (context) => const _SelfNameDialog(),
    );
    if (name == null || !mounted) return false;

    await ref.read(personRepositoryProvider).update(
          self.copyWith(displayName: name.trim()),
        );
    return true;
  }

  Future<void> _continueExport(List<DocumentListItem> items) async {
    if (_selectedIds.isEmpty || _exporting) return;

    final ready = await _ensureSelfNameIfNeeded(items);
    if (!ready || !mounted) return;

    final password = await showBackupPasswordDialog(
      context,
      title: 'Export backup',
      confirm: true,
    );
    if (password == null || !mounted) return;

    setState(() => _exporting = true);
    try {
      final bytes = await ref.read(vaultBackupServiceProvider).exportVault(
            password,
            documentIds: Set<String>.from(_selectedIds),
          );
      final stamp = DateFormat('yyyyMMdd').format(DateTime.now());
      final fileName = 'docket-backup-$stamp.docket';

      if (kIsWeb) {
        await FileSaver.instance.saveFile(
          name: p.basenameWithoutExtension(fileName),
          bytes: bytes,
          fileExtension: 'docket',
          mimeType: MimeType.other,
          customMimeType: 'application/octet-stream',
        );
        if (mounted) {
          showAppMessage(context, 'Backup download started.');
          context.pop();
        }
        return;
      }

      final dir = await getTemporaryDirectory();
      final path = p.join(dir.path, fileName);
      final temp = XFile.fromData(
        bytes,
        mimeType: 'application/octet-stream',
        name: fileName,
        path: path,
      );
      await temp.saveTo(path);

      await _runWithoutRelock(() async {
        await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile(
                path,
                mimeType: 'application/octet-stream',
                name: fileName,
              ),
            ],
            subject: 'Docket backup',
          ),
        );
      });

      if (mounted) {
        showAppMessage(context, 'Backup ready to share.');
        context.pop();
      }
    } on AppException catch (error) {
      if (mounted) showAppMessage(context, error.message);
    } catch (_) {
      if (mounted) showAppMessage(context, 'Could not export backup.');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _personTitle(Person person) {
    if (person.isSelf) {
      return isPlaceholderSelfName(person.displayName)
          ? 'Me'
          : '${person.displayName} (Me)';
    }
    return person.displayName;
  }

  String _personSubtitle(Person person, int selected, int total) {
    final count = selected == 0
        ? '$total document${total == 1 ? '' : 's'}'
        : '$selected of $total selected';
    if (person.isSelf) return count;
    return '${person.relationshipDisplay} · $count';
  }

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(allDocumentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _step == _ExportStep.people ? 'Choose people' : 'Choose documents',
        ),
        leading: _step == _ExportStep.documents
            ? IconButton(
                tooltip: 'Back to people',
                onPressed: _exporting
                    ? null
                    : () => setState(() {
                          _step = _ExportStep.people;
                          _activePersonId = null;
                        }),
                icon: const Icon(Icons.arrow_back),
              )
            : null,
      ),
      body: ConstrainedPageBody(
        child: docsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('$error')),
          data: (items) {
            _ensureSelection(items);
            if (items.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No documents to export yet.'),
                ),
              );
            }

            final grouped = _groupByPerson(items);
            final people = _peopleInOrder(items);

            if (_step == _ExportStep.documents) {
              final personDocs = grouped[_activePersonId];
              if (personDocs == null || personDocs.isEmpty) {
                return const Center(child: Text('No documents for this person.'));
              }
              return _DocumentsStep(
                person: personDocs.first.person,
                docs: personDocs,
                selectedIds: _selectedIds,
                exporting: _exporting,
                personTitle: _personTitle(personDocs.first.person),
                checkboxValue: _checkboxValue(
                  _selectedCountFor(personDocs),
                  personDocs.length,
                ),
                onToggleAll: (select) => _togglePerson(personDocs, select),
                onToggleDoc: _toggleDoc,
              );
            }

            return _PeopleStep(
              people: people,
              grouped: grouped,
              selectedTotal: _selectedIds.length,
              totalDocs: items.length,
              exporting: _exporting,
              checkboxValue: _checkboxValue(_selectedIds.length, items.length),
              personTitle: _personTitle,
              personSubtitle: _personSubtitle,
              selectedCountFor: _selectedCountFor,
              personCheckboxValue: (docs) => _checkboxValue(
                _selectedCountFor(docs),
                docs.length,
              ),
              onToggleAll: (select) => _toggleAllPeople(grouped, select),
              onTogglePerson: _togglePerson,
              onOpenPerson: (personId) {
                setState(() {
                  _activePersonId = personId;
                  _step = _ExportStep.documents;
                });
              },
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: _step == _ExportStep.documents
              ? OutlinedButton(
                  onPressed: _exporting
                      ? null
                      : () => setState(() {
                            _step = _ExportStep.people;
                            _activePersonId = null;
                          }),
                  child: const Text('Done — back to people'),
                )
              : FilledButton(
                  onPressed: _selectedIds.isEmpty || _exporting
                      ? null
                      : () {
                          final items = docsAsync.value ?? const [];
                          _continueExport(items);
                        },
                  child: _exporting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('Export (${_selectedIds.length})'),
                ),
        ),
      ),
    );
  }
}

class _PeopleStep extends StatelessWidget {
  const _PeopleStep({
    required this.people,
    required this.grouped,
    required this.selectedTotal,
    required this.totalDocs,
    required this.exporting,
    required this.checkboxValue,
    required this.personTitle,
    required this.personSubtitle,
    required this.selectedCountFor,
    required this.personCheckboxValue,
    required this.onToggleAll,
    required this.onTogglePerson,
    required this.onOpenPerson,
  });

  final List<Person> people;
  final Map<String, List<DocumentListItem>> grouped;
  final int selectedTotal;
  final int totalDocs;
  final bool exporting;
  final bool? checkboxValue;
  final String Function(Person person) personTitle;
  final String Function(Person person, int selected, int total) personSubtitle;
  final int Function(List<DocumentListItem> docs) selectedCountFor;
  final bool? Function(List<DocumentListItem> docs) personCheckboxValue;
  final ValueChanged<bool> onToggleAll;
  final void Function(List<DocumentListItem> docs, bool select) onTogglePerson;
  final ValueChanged<String> onOpenPerson;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(
            'Select people first. Tap a person to choose which of their documents to include.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        CheckboxListTile(
          value: checkboxValue,
          tristate: true,
          title: const Text('All people'),
          subtitle: Text('$selectedTotal of $totalDocs documents selected'),
          onChanged: exporting ? null : (value) => onToggleAll(value == true),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
            itemCount: people.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final person = people[index];
              final docs = grouped[person.id] ?? const [];
              final selected = selectedCountFor(docs);
              return Card(
                child: ListTile(
                  leading: Checkbox(
                    value: personCheckboxValue(docs),
                    tristate: true,
                    onChanged: exporting
                        ? null
                        : (value) => onTogglePerson(docs, value == true),
                  ),
                  title: Text(personTitle(person)),
                  subtitle: Text(personSubtitle(person, selected, docs.length)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onOpenPerson(person.id),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DocumentsStep extends StatelessWidget {
  const _DocumentsStep({
    required this.person,
    required this.docs,
    required this.selectedIds,
    required this.exporting,
    required this.personTitle,
    required this.checkboxValue,
    required this.onToggleAll,
    required this.onToggleDoc,
  });

  final Person person;
  final List<DocumentListItem> docs;
  final Set<String> selectedIds;
  final bool exporting;
  final String personTitle;
  final bool? checkboxValue;
  final ValueChanged<bool> onToggleAll;
  final void Function(String id, bool selected) onToggleDoc;

  @override
  Widget build(BuildContext context) {
    final selected = docs.where((d) => selectedIds.contains(d.document.id)).length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(
            'Documents for $personTitle',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        CheckboxListTile(
          value: checkboxValue,
          tristate: true,
          title: const Text('All documents'),
          subtitle: Text('$selected of ${docs.length} selected'),
          onChanged: exporting ? null : (value) => onToggleAll(value == true),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final item = docs[index];
              final id = item.document.id;
              return CheckboxListTile(
                value: selectedIds.contains(id),
                title: Text(item.document.title),
                subtitle: Text(item.category.name),
                onChanged: exporting
                    ? null
                    : (value) => onToggleDoc(id, value == true),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SelfNameDialog extends StatefulWidget {
  const _SelfNameDialog();

  @override
  State<_SelfNameDialog> createState() => _SelfNameDialogState();
}

class _SelfNameDialogState extends State<_SelfNameDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Your name'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Name for your documents',
          hintText: 'e.g. Varun',
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _submit() {
    final name = _controller.text.trim();
    if (isPlaceholderSelfName(name)) {
      showAppMessage(context, 'Enter your real name (not “Me”).');
      return;
    }
    Navigator.pop(context, name);
  }
}
