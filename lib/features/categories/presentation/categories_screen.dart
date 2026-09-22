import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app.dart';
import '../../../app/widgets/constrained_page_body.dart';
import '../../../core/errors.dart';
import '../../../core/providers.dart';
import '../../../core/utils/category_icons.dart';
import '../../documents/presentation/document_providers.dart';
import '../domain/category.dart';
import 'categories_providers.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addCategory(context, ref),
        icon: const Icon(Icons.create_new_folder_outlined),
        label: const Text('Add category'),
      ),
      body: ConstrainedPageBody(
        child: categories.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('$error')),
          data: (items) {
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                return _CategoryTile(category: items[index]);
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _addCategory(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('New category'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
    if (name == null || name.isEmpty) return;
    try {
      await ref.read(categoryRepositoryProvider).addCustom(name);
    } on AppException catch (error) {
      if (context.mounted) showAppMessage(context, error.message);
    }
  }
}

class _CategoryTile extends ConsumerWidget {
  const _CategoryTile({required this.category});

  final Category category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = (ref.watch(allDocumentsProvider).value ?? const [])
        .where((item) => item.document.categoryId == category.id)
        .length;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(iconForCategory(category.icon)),
        ),
        title: Text(category.name),
        subtitle: Text('$count document${count == 1 ? '' : 's'}'),
        onTap: () {
          ref.read(libraryFilterProvider.notifier).setCategory(category.id);
          context.go('/');
        },
        trailing: category.isDefault
            ? null
            : IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final confirmed = await confirmAction(
                    context: context,
                    title: 'Delete ${category.name}?',
                    message:
                        'Documents in this category must be moved or deleted first.',
                  );
                  if (!confirmed) return;
                  try {
                    await ref.read(categoryRepositoryProvider).delete(category.id);
                  } on AppException catch (error) {
                    if (context.mounted) {
                      showAppMessage(context, error.message);
                    }
                  }
                },
              ),
      ),
    );
  }
}
