import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../core/utils/mime_utils.dart';

class DocumentPreview extends StatelessWidget {
  const DocumentPreview({
    super.key,
    required this.bytes,
    required this.mimeType,
    required this.sourceName,
  });

  final Uint8List bytes;
  final String mimeType;
  final String sourceName;

  @override
  Widget build(BuildContext context) {
    if (isImageMime(mimeType)) {
      return InteractiveViewer(
        child: Center(child: Image.memory(bytes)),
      );
    }
    if (isPdfMime(mimeType)) {
      return PdfViewer.data(
        bytes,
        sourceName: sourceName,
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.insert_drive_file_outlined, size: 64),
          const SizedBox(height: 12),
          Text(
            'Preview is not available for this file type.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Use Share or Download to open it.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
