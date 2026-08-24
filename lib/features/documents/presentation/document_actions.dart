import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/mime_utils.dart';
import '../domain/document.dart';

Future<void> shareDocument(Document document, Uint8List bytes) async {
  await shareDocuments([(document, bytes)]);
}

/// Shares one or more documents via the native share sheet.
/// On web, falls back to downloading each file individually.
Future<void> shareDocuments(List<(Document, Uint8List)> files) async {
  if (files.isEmpty) return;

  if (kIsWeb) {
    for (final (document, bytes) in files) {
      await downloadDocument(document, bytes);
    }
    return;
  }

  final dir = await getTemporaryDirectory();
  final usedNames = <String>{};
  final xFiles = <XFile>[];

  for (final (document, bytes) in files) {
    final uniqueName = _uniqueFileName(document.originalFileName, usedNames);
    usedNames.add(uniqueName);
    final filePath = p.join(dir.path, uniqueName);
    final file = XFile.fromData(
      bytes,
      mimeType: document.mimeType,
      name: uniqueName,
      path: filePath,
    );
    await file.saveTo(filePath);
    xFiles.add(XFile(filePath, mimeType: document.mimeType, name: uniqueName));
  }

  final subject = files.length == 1
      ? files.first.$1.title
      : '${files.length} documents';

  await SharePlus.instance.share(
    ShareParams(
      files: xFiles,
      subject: subject,
    ),
  );
}

String _uniqueFileName(String original, Set<String> used) {
  if (!used.contains(original)) return original;
  final ext = p.extension(original);
  final base = p.basenameWithoutExtension(original);
  var index = 2;
  while (true) {
    final candidate = '$base ($index)$ext';
    if (!used.contains(candidate)) return candidate;
    index++;
  }
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
