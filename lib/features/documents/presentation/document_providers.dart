import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../domain/document_list_item.dart';

@immutable
class LibraryFilter {
  const LibraryFilter({
    this.personId,
    this.categoryId,
    this.query = '',
    this.gridView = false,
  });

  final String? personId;
  final String? categoryId;
  final String query;
  final bool gridView;

  LibraryFilter copyWith({
    String? personId,
    bool clearPerson = false,
    String? categoryId,
    bool clearCategory = false,
    String? query,
    bool? gridView,
  }) {
    return LibraryFilter(
      personId: clearPerson ? null : (personId ?? this.personId),
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      query: query ?? this.query,
      gridView: gridView ?? this.gridView,
    );
  }
}

class LibraryFilterNotifier extends Notifier<LibraryFilter> {
  @override
  LibraryFilter build() => const LibraryFilter();

  void setPerson(String? id) {
    state = id == null
        ? state.copyWith(clearPerson: true)
        : state.copyWith(personId: id);
  }

  void setCategory(String? id) {
    state = id == null
        ? state.copyWith(clearCategory: true)
        : state.copyWith(categoryId: id);
  }

  void setQuery(String query) {
    state = state.copyWith(query: query);
  }

  void toggleView() {
    state = state.copyWith(gridView: !state.gridView);
  }
}

final libraryFilterProvider =
    NotifierProvider<LibraryFilterNotifier, LibraryFilter>(
  LibraryFilterNotifier.new,
);

final libraryDocumentsProvider = StreamProvider<List<DocumentListItem>>((ref) {
  final filter = ref.watch(libraryFilterProvider);
  return ref.watch(documentRepositoryProvider).watchAll(
        personId: filter.personId,
        categoryId: filter.categoryId,
        query: filter.query,
      );
});

final documentItemProvider =
    FutureProvider.family<DocumentListItem?, String>((ref, id) {
  return ref.watch(documentRepositoryProvider).getListItem(id);
});

final allDocumentsProvider = StreamProvider<List<DocumentListItem>>((ref) {
  return ref.watch(documentRepositoryProvider).watchAll();
});

final storageBytesProvider = FutureProvider<int>((ref) {
  ref.watch(allDocumentsProvider);
  return ref.watch(documentRepositoryProvider).storageBytes();
});

final documentBytesProvider =
    FutureProvider.family<Uint8List, String>((ref, id) async {
  final repo = ref.watch(documentRepositoryProvider);
  final document = await repo.getById(id);
  if (document == null) {
    throw StateError('Document not found.');
  }
  return repo.readFile(document);
});

final thumbnailBytesProvider =
    FutureProvider.family<Uint8List?, String>((ref, key) async {
  try {
    return await ref.watch(fileStoreProvider).read(key);
  } catch (_) {
    return null;
  }
});
