import 'package:file_saver/file_saver.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

bool isImageMime(String mimeType) => mimeType.toLowerCase().startsWith('image/');

bool isPdfMime(String mimeType) => mimeType.toLowerCase() == 'application/pdf';

/// Typed notes created in-app (editable as text).
bool isPlainTextMime(String mimeType) =>
    mimeType.toLowerCase() == 'text/plain';

/// Any text/* type — used for preview only, not for edit-as-note mode.
bool isTextMime(String mimeType) =>
    mimeType.toLowerCase().startsWith('text/');

String guessMimeType(String fileName, String? reported) {
  final value = reported?.trim();
  if (value != null && value.isNotEmpty && value != 'application/octet-stream') {
    return value;
  }
  return lookupMimeType(fileName) ?? 'application/octet-stream';
}

MimeType saverMimeType(String mimeType) {
  switch (mimeType.toLowerCase()) {
    case 'application/pdf':
      return MimeType.pdf;
    case 'image/png':
      return MimeType.png;
    case 'image/jpeg':
      return MimeType.jpeg;
    case 'image/webp':
      return MimeType.webp;
    case 'image/gif':
      return MimeType.gif;
    case 'text/plain':
      return MimeType.text;
    default:
      return MimeType.other;
  }
}

String fileExtension(String fileName) {
  final ext = p.extension(fileName);
  return ext.startsWith('.') ? ext.substring(1) : ext;
}
