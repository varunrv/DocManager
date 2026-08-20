import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/category_icons.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/mime_utils.dart';
import '../../../people/domain/person.dart';
import '../../domain/document_list_item.dart';
import '../document_providers.dart';

class DocumentCard extends ConsumerWidget {
  const DocumentCard({
    super.key,
    required this.item,
    required this.compact,
    required this.onTap,
  });

  final DocumentListItem item;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doc = item.document;
    final thumb = doc.thumbnailKey == null
        ? null
        : ref.watch(thumbnailBytesProvider(doc.thumbnailKey!));

    Widget preview() {
      final bytes = thumb?.valueOrNull;
      if (bytes != null) {
        return Image.memory(bytes, fit: BoxFit.cover);
      }
      return ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(
          isPdfMime(doc.mimeType)
              ? Icons.picture_as_pdf_outlined
              : isImageMime(doc.mimeType)
                  ? Icons.image_outlined
                  : isPlainTextMime(doc.mimeType)
                      ? Icons.notes_outlined
                      : Icons.insert_drive_file_outlined,
          size: compact ? 36 : 28,
        ),
      );
    }

    if (compact) {
      return Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: preview()),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.person.ownerLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(width: 48, height: 48, child: preview()),
        ),
        title: Text(doc.title),
        subtitle: Text(
          '${item.person.ownerLabel} · ${item.category.name} · ${formatBytes(doc.sizeBytes)}',
        ),
        trailing: Icon(iconForCategory(item.category.icon)),
      ),
    );
  }
}

class OwnerChip extends StatelessWidget {
  const OwnerChip({super.key, required this.person});

  final Person person;

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(person.isSelf ? Icons.person : Icons.family_restroom, size: 16),
      label: Text(person.ownerLabel),
    );
  }
}

class DocumentThumb extends StatelessWidget {
  const DocumentThumb({super.key, this.bytes, required this.mimeType});

  final Uint8List? bytes;
  final String mimeType;

  @override
  Widget build(BuildContext context) {
    if (bytes != null) {
      return Image.memory(bytes!, fit: BoxFit.cover);
    }
    return Icon(
      isPdfMime(mimeType)
          ? Icons.picture_as_pdf_outlined
          : isImageMime(mimeType)
              ? Icons.image_outlined
              : isPlainTextMime(mimeType)
                  ? Icons.notes_outlined
                  : Icons.insert_drive_file_outlined,
    );
  }
}
