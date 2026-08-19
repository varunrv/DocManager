import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../errors.dart';
import 'file_store.dart';

FileStore createFileStoreImpl() => IoFileStore();

class IoFileStore implements FileStore {
  Future<Directory> _root() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'docs'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _file(String key) async {
    final root = await _root();
    return File(p.join(root.path, key));
  }

  @override
  Future<void> write(String key, Uint8List bytes) async {
    try {
      final file = await _file(key);
      await file.writeAsBytes(bytes, flush: true);
    } on FileSystemException {
      throw const AppException(
        'Not enough storage to save this file. Try a smaller document.',
      );
    }
  }

  @override
  Future<Uint8List> read(String key) async {
    final file = await _file(key);
    if (!await file.exists()) {
      throw const AppException('The file is missing from local storage.');
    }
    return file.readAsBytes();
  }

  @override
  Future<void> delete(String key) async {
    final file = await _file(key);
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<int> totalBytes() async {
    final root = await _root();
    var total = 0;
    await for (final entity in root.list()) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }
}
