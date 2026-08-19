import 'dart:typed_data';

import 'file_store_stub.dart'
    if (dart.library.io) 'file_store_io.dart'
    if (dart.library.js_interop) 'file_store_web.dart';

abstract class FileStore {
  Future<void> write(String key, Uint8List bytes);

  Future<Uint8List> read(String key);

  Future<void> delete(String key);

  Future<int> totalBytes();
}

FileStore createFileStore() => createFileStoreImpl();
