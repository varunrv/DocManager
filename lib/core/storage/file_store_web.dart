import 'dart:typed_data';

import 'package:idb_shim/idb_browser.dart';

import '../errors.dart';
import 'file_store.dart';

FileStore createFileStoreImpl() => WebFileStore();

class WebFileStore implements FileStore {
  static const _dbName = 'doc_manager_files';
  static const _storeName = 'blobs';

  Database? _db;

  Future<Database> _open() async {
    if (_db != null) return _db!;
    _db = await idbFactoryBrowser.open(
      _dbName,
      version: 1,
      onUpgradeNeeded: (event) {
        final db = event.database;
        if (!db.objectStoreNames.contains(_storeName)) {
          db.createObjectStore(_storeName);
        }
      },
    );
    return _db!;
  }

  @override
  Future<void> write(String key, Uint8List bytes) async {
    try {
      final db = await _open();
      final txn = db.transaction(_storeName, idbModeReadWrite);
      await txn.objectStore(_storeName).put(bytes, key);
      await txn.completed;
    } catch (error) {
      throw const AppException(
        'Not enough storage to save this file. Browser storage may be full.',
      );
    }
  }

  @override
  Future<Uint8List> read(String key) async {
    final db = await _open();
    final txn = db.transaction(_storeName, idbModeReadOnly);
    final value = await txn.objectStore(_storeName).getObject(key);
    await txn.completed;
    if (value is Uint8List) return value;
    if (value is List<int>) return Uint8List.fromList(value);
    throw const AppException('The file is missing from local storage.');
  }

  @override
  Future<void> delete(String key) async {
    final db = await _open();
    final txn = db.transaction(_storeName, idbModeReadWrite);
    await txn.objectStore(_storeName).delete(key);
    await txn.completed;
  }

  @override
  Future<int> totalBytes() async {
    final db = await _open();
    final txn = db.transaction(_storeName, idbModeReadOnly);
    final store = txn.objectStore(_storeName);
    var total = 0;
    await for (final cursor in store.openCursor(autoAdvance: true)) {
      final value = cursor.value;
      if (value is Uint8List) {
        total += value.lengthInBytes;
      } else if (value is List) {
        total += value.length;
      }
    }
    await txn.completed;
    return total;
  }
}
