import 'package:intl/intl.dart';

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

String formatDate(DateTime date) => DateFormat.yMMMd().format(date);

String titleFromFileName(String fileName) {
  final base = fileName.contains('.')
      ? fileName.substring(0, fileName.lastIndexOf('.'))
      : fileName;
  return base.replaceAll(RegExp(r'[_-]+'), ' ').trim();
}

List<String> parseTags(String raw) {
  return raw
      .split(',')
      .map((tag) => tag.trim())
      .where((tag) => tag.isNotEmpty)
      .toSet()
      .toList();
}

String tagsToInput(List<String> tags) => tags.join(', ');
