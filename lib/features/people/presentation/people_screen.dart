import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app.dart';
import '../../../app/widgets/constrained_page_body.dart';
import '../../../core/errors.dart';
import '../../../core/providers.dart';
import '../../documents/presentation/document_providers.dart';
import '../domain/person.dart';
import 'people_providers.dart';
import 'person_editor.dart';

class PeopleScreen extends ConsumerWidget {
  const PeopleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final people = ref.watch(peopleProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('People')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showPersonEditor(context),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add someone'),
      ),
      body: ConstrainedPageBody(
        child: people.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('$error')),
          data: (items) {
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                return _PersonTile(person: items[index]);
              },
            );
          },
        ),
      ),
    );
  }
}

class _PersonTile extends ConsumerWidget {
  const _PersonTile({required this.person});

  final Person person;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = (ref.watch(allDocumentsProvider).value ?? const [])
        .where((item) => item.document.personId == person.id)
        .length;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Text(
            person.displayName.isEmpty
                ? '?'
                : person.displayName.substring(0, 1).toUpperCase(),
          ),
        ),
        title: Text(person.displayName),
        subtitle: Text(
          person.isSelf
              ? 'You · $count document${count == 1 ? '' : 's'}'
              : '${person.relationshipDisplay} · $count document${count == 1 ? '' : 's'}',
        ),
        trailing: person.isSelf
            ? IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => showPersonEditor(context, existing: person),
              )
            : PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'edit') {
                    await showPersonEditor(context, existing: person);
                  } else if (value == 'delete') {
                    final confirmed = await confirmAction(
                      context: context,
                      title: 'Remove ${person.displayName}?',
                      message:
                          'This only removes the person. Documents must be moved or deleted first.',
                    );
                    if (!confirmed) return;
                    try {
                      await ref.read(personRepositoryProvider).delete(person.id);
                    } on AppException catch (error) {
                      if (context.mounted) {
                        showAppMessage(context, error.message);
                      }
                    }
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
      ),
    );
  }
}
