import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app.dart';
import '../../../app/widgets/constrained_page_body.dart';
import '../../../core/providers.dart';
import '../../categories/presentation/categories_providers.dart';
import '../../people/presentation/people_providers.dart';
import '../../settings/presentation/lock_providers.dart';
import '../domain/document.dart';
import '../domain/document_list_item.dart';
import 'document_actions.dart';
import 'document_providers.dart';
import 'quick_add_sheet.dart';
import 'widgets/document_card.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _searchController = TextEditingController();
  final _selectedIds = <String>{};
  var _selectionMode = false;
  var _sharing = false;
  var _bulkWorking = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _enterSelection(String documentId) {
    setState(() {
      _selectionMode = true;
      _selectedIds
        ..clear()
        ..add(documentId);
    });
  }

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelected(String documentId) {
    setState(() {
      if (_selectedIds.contains(documentId)) {
        _selectedIds.remove(documentId);
        if (_selectedIds.isEmpty) {
          _selectionMode = false;
        }
      } else {
        _selectedIds.add(documentId);
      }
    });
  }

  void _onDocumentTap(DocumentListItem item) {
    final id = item.document.id;
    if (_selectionMode) {
      _toggleSelected(id);
      return;
    }
    context.push('/document/$id');
  }

  Future<void> _shareSelected(List<DocumentListItem> items) async {
    if (_selectedIds.isEmpty || _sharing) return;

    final selected = items
        .where((item) => _selectedIds.contains(item.document.id))
        .map((item) => item.document)
        .toList();
    if (selected.isEmpty) return;

    setState(() => _sharing = true);
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(documentRepositoryProvider);
    final suspendCount = ref.read(lockSuspendCountProvider);
    ref.read(lockSuspendCountProvider.notifier).state = suspendCount + 1;

    try {
      final files = <(Document, Uint8List)>[];
      for (final document in selected) {
        final bytes = await repo.readFile(document);
        files.add((document, bytes));
      }

      await shareDocuments(files);
      if (!mounted) return;
      _exitSelection();
      if (kIsWeb) {
        showAppMessage(
          context,
          files.length == 1
              ? 'Download started.'
              : 'Downloads started for ${files.length} documents.',
        );
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Could not share the selected documents.'),
          ),
        );
      }
    } finally {
      final current = ref.read(lockSuspendCountProvider);
      ref.read(lockSuspendCountProvider.notifier).state =
          current > 0 ? current - 1 : 0;
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty || _bulkWorking) return;

    final count = _selectedIds.length;
    final confirmed = await confirmAction(
      context: context,
      title: 'Delete documents?',
      message:
          'Delete $count document${count == 1 ? '' : 's'}? This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!confirmed || !mounted) return;

    setState(() => _bulkWorking = true);
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(documentRepositoryProvider);
    try {
      final deleted = await repo.deleteMany(_selectedIds);
      ref.invalidate(storageBytesProvider);
      if (!mounted) return;
      _exitSelection();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            deleted == count
                ? 'Deleted $deleted document${deleted == 1 ? '' : 's'}.'
                : 'Deleted $deleted of $count documents.',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Could not delete the selected documents.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _bulkWorking = false);
    }
  }

  Future<void> _moveSelected() async {
    if (_selectedIds.isEmpty || _bulkWorking) return;

    final people = ref.read(peopleProvider).value ?? const [];
    if (people.isEmpty) return;

    final personId = await showDialog<String>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Move to'),
          children: [
            for (final person in people)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, person.id),
                child: Text(
                  person.isSelf ? person.displayName : person.ownerLabel,
                ),
              ),
          ],
        );
      },
    );
    if (personId == null || !mounted) return;

    setState(() => _bulkWorking = true);
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(documentRepositoryProvider);
    try {
      final moved = await repo.updatePersonIdMany(_selectedIds, personId);
      if (!mounted) return;
      _exitSelection();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            moved == 0
                ? 'Selected documents already belong to that person.'
                : 'Moved $moved document${moved == 1 ? '' : 's'}.',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Could not move the selected documents.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _bulkWorking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(libraryFilterProvider);
    final documents = ref.watch(libraryDocumentsProvider);
    final people = ref.watch(peopleProvider).value ?? const [];
    final categories = ref.watch(categoriesProvider).value ?? const [];

    if (_searchController.text != filter.query) {
      _searchController.value = TextEditingValue(
        text: filter.query,
        selection: TextSelection.collapsed(offset: filter.query.length),
      );
    }

    final items = documents.value ?? const <DocumentListItem>[];

    return Scaffold(
      appBar: AppBar(
        leading: _selectionMode
            ? IconButton(
                tooltip: 'Cancel',
                onPressed: _sharing || _bulkWorking ? null : _exitSelection,
                icon: const Icon(Icons.close),
              )
            : null,
        title: Text(
          _selectionMode
              ? '${_selectedIds.length} selected'
              : 'Docket',
        ),
        actions: [
          if (_selectionMode) ...[
            IconButton(
              tooltip: 'Move',
              onPressed: _selectedIds.isEmpty || _bulkWorking
                  ? null
                  : _moveSelected,
              icon: const Icon(Icons.drive_file_move_outline),
            ),
            IconButton(
              tooltip: 'Delete',
              onPressed: _selectedIds.isEmpty || _bulkWorking
                  ? null
                  : _deleteSelected,
              icon: const Icon(Icons.delete_outline),
            ),
            IconButton(
              tooltip: kIsWeb ? 'Download' : 'Share',
              onPressed: _selectedIds.isEmpty || _sharing || _bulkWorking
                  ? null
                  : () => _shareSelected(items),
              icon: _sharing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(kIsWeb ? Icons.download : Icons.ios_share),
            ),
          ] else
            IconButton(
              tooltip: filter.gridView ? 'List view' : 'Grid view',
              onPressed: () =>
                  ref.read(libraryFilterProvider.notifier).toggleView(),
              icon: Icon(filter.gridView ? Icons.view_list : Icons.grid_view),
            ),
        ],
      ),
      floatingActionButton: _selectionMode
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.small(
                  heroTag: 'quick-add',
                  onPressed: () => showQuickAddSheet(context),
                  tooltip: 'Quick add',
                  child: const Icon(Icons.bolt_outlined),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.extended(
                  heroTag: 'add-document',
                  onPressed: () => context.push('/add'),
                  icon: const Icon(Icons.add),
                  label: const Text('Add document'),
                ),
              ],
            ),
      body: ConstrainedPageBody(
        child: Column(
          children: [
            if (!_selectionMode) ...[
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
                    (
                      person.id,
                      person.isSelf ? person.displayName : person.ownerLabel
                    ),
                ],
                onSelected: (id) =>
                    ref.read(libraryFilterProvider.notifier).setPerson(id),
              ),
              _FilterRow(
                selectedId: filter.categoryId,
                allLabel: 'All',
                items: [
                  for (final category in categories)
                    (category.id, category.name),
                ],
                onSelected: (id) =>
                    ref.read(libraryFilterProvider.notifier).setCategory(id),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Tap documents to select, then ${kIsWeb ? 'download' : 'share'} them together.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
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
                        final id = item.document.id;
                        return DocumentCard(
                          item: item,
                          compact: true,
                          selectionMode: _selectionMode,
                          selected: _selectedIds.contains(id),
                          onTap: () => _onDocumentTap(item),
                          onLongPress: () => _enterSelection(id),
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
                      final id = item.document.id;
                      return DocumentCard(
                        item: item,
                        compact: false,
                        selectionMode: _selectionMode,
                        selected: _selectedIds.contains(id),
                        onTap: () => _onDocumentTap(item),
                        onLongPress: () => _enterSelection(id),
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
