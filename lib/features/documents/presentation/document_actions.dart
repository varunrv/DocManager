import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/mime_utils.dart';
import '../domain/document.dart';

Future<void> shareDocument(Document document, Uint8List bytes) async {
  if (kIsWeb) {
    await downloadDocument(document, bytes);
    return;
  }
  final dir = await getTemporaryDirectory();
  final filePath = p.join(dir.path, document.originalFileName);
  final file = XFile.fromData(
    bytes,
    mimeType: document.mimeType,
    name: document.originalFileName,
    path: filePath,
  );
  await file.saveTo(filePath);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(filePath, mimeType: document.mimeType)],
      subject: document.title,
    ),
  );
}

Future<void> downloadDocument(Document document, Uint8List bytes) async {
  await FileSaver.instance.saveFile(
    name: p.basenameWithoutExtension(document.originalFileName),
    bytes: bytes,
    fileExtension: fileExtension(document.originalFileName),
    mimeType: saverMimeType(document.mimeType),
    customMimeType: document.mimeType,
  );
}
