import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/widgets/constrained_page_body.dart';
import '../../categories/presentation/categories_providers.dart';
import '../../people/presentation/people_providers.dart';
import 'document_providers.dart';
import 'widgets/document_card.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(libraryFilterProvider);
    final documents = ref.watch(libraryDocumentsProvider);
    final people = ref.watch(peopleProvider).valueOrNull ?? const [];
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];

    if (_searchController.text != filter.query) {
      _searchController.value = TextEditingValue(
        text: filter.query,
        selection: TextSelection.collapsed(offset: filter.query.length),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Manager'),
        actions: [
          IconButton(
            tooltip: filter.gridView ? 'List view' : 'Grid view',
            onPressed: () => ref.read(libraryFilterProvider.notifier).toggleView(),
            icon: Icon(filter.gridView ? Icons.view_list : Icons.grid_view),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/add'),
        icon: const Icon(Icons.add),
        label: const Text('Add document'),
      ),
      body: ConstrainedPageBody(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search title, tags, notes, or person',
                ),
                onChanged: (value) =>
                    ref.read(libraryFilterProvider.notifier).setQuery(value),
              ),
            ),
            const SizedBox(height: 8),
            _FilterRow(
              selectedId: filter.personId,
              allLabel: 'All',
              items: [
                for (final person in people)
                  (person.id, person.isSelf ? person.displayName : person.ownerLabel),
              ],
              onSelected: (id) =>
                  ref.read(libraryFilterProvider.notifier).setPerson(id),
            ),
            _FilterRow(
              selectedId: filter.categoryId,
              allLabel: 'All',
              items: [
                for (final category in categories) (category.id, category.name),
              ],
              onSelected: (id) =>
                  ref.read(libraryFilterProvider.notifier).setCategory(id),
            ),
            Expanded(
              child: documents.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('$error')),
                data: (items) {
                  if (items.isEmpty) {
                    return const _EmptyLibrary();
                  }
                  if (filter.gridView) {
                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 220,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.78,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return DocumentCard(
                          item: item,
                          compact: true,
                          onTap: () => context.push('/document/${item.document.id}'),
                        );
                      },
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return DocumentCard(
                        item: item,
                        compact: false,
                        onTap: () => context.push('/document/${item.document.id}'),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.selectedId,
    required this.allLabel,
    required this.items,
    required this.onSelected,
  });

  final String? selectedId;
  final String allLabel;
  final List<(String, String)> items;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(allLabel),
              selected: selectedId == null,
              onSelected: (_) => onSelected(null),
            ),
          ),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(item.$2),
                selected: selectedId == item.$1,
                onSelected: (_) => onSelected(item.$1),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_open,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Keep every document in one place',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Save IDs, certificates, and files for yourself or your family, then share or download them when someone asks.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push('/add'),
              icon: const Icon(Icons.add),
              label: const Text('Add your first document'),
            ),
          ],
        ),
      ),
    );
  }
}
