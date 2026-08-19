import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app.dart';
import '../../../app/widgets/constrained_page_body.dart';
import '../../../core/errors.dart';
import '../../../core/providers.dart';
import '../../../core/utils/formatters.dart';
import 'document_actions.dart';
import 'document_preview.dart';
import 'document_providers.dart';
import 'widgets/document_card.dart';

class DocumentDetailScreen extends ConsumerWidget {
  const DocumentDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(documentItemProvider(id));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/');
      },
      child: item.when(
      loading: () => Scaffold(
        appBar: AppBar(leading: _homeBackButton(context)),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(leading: _homeBackButton(context)),
        body: Center(child: Text('$error')),
      ),
      data: (data) {
        if (data == null) {
          return Scaffold(
            appBar: AppBar(leading: _homeBackButton(context)),
            body: const Center(child: Text('Document not found.')),
          );
        }
        final bytesAsync = ref.watch(documentBytesProvider(data.document));
        return Scaffold(
          appBar: AppBar(
            leading: _homeBackButton(context),
            title: Text(data.document.title),
            actions: [
              IconButton(
                tooltip: 'Edit',
                onPressed: () => context.push('/document/$id/edit'),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Delete',
                onPressed: () => _delete(context, ref),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          body: ConstrainedPageBody(
            child: Column(
              children: [
                Expanded(
                  child: bytesAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Center(child: Text('$error')),
                    data: (bytes) => DocumentPreview(
                      bytes: bytes,
                      mimeType: data.document.mimeType,
                      sourceName: data.document.id,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OwnerChip(person: data.person),
                          Chip(label: Text(data.category.name)),
                          Chip(label: Text(formatBytes(data.document.sizeBytes))),
                          if (data.document.expiresAt != null)
                            Chip(
                              label: Text(
                                'Expires ${formatDate(data.document.expiresAt!)}',
                              ),
                            ),
                          for (final tag in data.document.tags)
                            Chip(label: Text(tag)),
                        ],
                      ),
                      if (data.document.notes.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(data.document.notes),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          if (!kIsWeb)
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: bytesAsync.valueOrNull == null
                                    ? null
                                    : () => shareDocument(
                                          data.document,
                                          bytesAsync.valueOrNull!,
                                        ),
                                icon: const Icon(Icons.ios_share),
                                label: const Text('Share'),
                              ),
                            ),
                          if (!kIsWeb) const SizedBox(width: 12),
                          Expanded(
                            child: kIsWeb
                                ? FilledButton.icon(
                                    onPressed: bytesAsync.valueOrNull == null
                                        ? null
                                        : () => downloadDocument(
                                              data.document,
                                              bytesAsync.valueOrNull!,
                                            ),
                                    icon: const Icon(Icons.download),
                                    label: const Text('Download'),
                                  )
                                : OutlinedButton.icon(
                                    onPressed: bytesAsync.valueOrNull == null
                                        ? null
                                        : () => downloadDocument(
                                              data.document,
                                              bytesAsync.valueOrNull!,
                                            ),
                                    icon: const Icon(Icons.download),
                                    label: const Text('Download'),
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
    );
  }

  Widget _homeBackButton(BuildContext context) {
    return IconButton(
      icon: const BackButtonIcon(),
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: () => context.go('/'),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmAction(
      context: context,
      title: 'Delete this document?',
      message: 'The file will be removed from this device.',
    );
    if (!confirmed) return;
    try {
      await ref.read(documentRepositoryProvider).delete(id);
      if (context.mounted) context.go('/');
    } on AppException catch (error) {
      if (context.mounted) showAppMessage(context, error.message);
    }
  }
}
