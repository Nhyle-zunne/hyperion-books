import 'package:sembast/sembast.dart';
import 'package:sembast_web/sembast_web.dart';
import '../models/book_entry.dart';

/// Data never leaves this browser's IndexedDB unless the user exports it.
/// Records are not encrypted at rest; do not use a shared browser profile.
class LocalRepository {
  final Database db;
  final StoreRef<String, Map<String, Object?>> _records =
      stringMapStoreFactory.store('entries');

  LocalRepository._(this.db);

  static Future<LocalRepository> open() async {
    final db = await databaseFactoryWeb.openDatabase('hyperion_books_local_v2');
    return LocalRepository._(db);
  }

  Future<List<BookEntry>> list() async {
    final snapshots = await _records.find(db);
    return snapshots.map((s) => BookEntry.fromLocalJson(s.value)).toList();
  }

  Future<void> upsert(BookEntry entry) async {
    await _records.record(entry.id).put(db, entry.toLocalJson());
  }

  /// Atomic replacement so an interrupted restore never leaves partial books.
  Future<void> replaceAll(List<BookEntry> entries) async {
    await db.transaction((txn) async {
      await _records.delete(txn);
      for (final entry in entries) {
        await _records.record(entry.id).put(txn, entry.toLocalJson());
      }
    });
  }

  Future<void> remove(String id) async {
    await _records.record(id).delete(db);
  }

  Future<void> close() => db.close();
}
