import 'package:sembast_web/sembast_web.dart';
import '../models/book_entry.dart';
import '../models/paymongo_transaction.dart';
import '../models/business_workspace.dart';

/// Data never leaves this browser's IndexedDB unless the user exports it.
/// Records are not encrypted at rest; do not use a shared browser profile.
class LocalRepository {
  final Database db;
  final StoreRef<String, Map<String, Object?>> _records =
      stringMapStoreFactory.store('entries');
  final StoreRef<String, Map<String, Object?>> _paymongo =
      stringMapStoreFactory.store('paymongo_transactions');

  final StoreRef<String, Map<String, Object?>> _workspace =
      stringMapStoreFactory.store('business_workspace');

  LocalRepository._(this.db);

  static Future<LocalRepository> open() async {
    final db = await databaseFactoryWeb.openDatabase('hyperion_books_local_v2');
    return LocalRepository._(db);
  }

  Future<List<BookEntry>> list() async {
    final snapshots = await _records.find(db);
    return snapshots.map((s) => BookEntry.fromLocalJson(s.value)).toList();
  }

  Future<List<PayMongoTransaction>> listPayMongo() async {
    final snapshots = await _paymongo.find(db);
    return snapshots.map((s) => PayMongoTransaction.fromJson(s.value)).toList();
  }

  Future<BusinessWorkspace> readWorkspace() async {
    final record = await _workspace.record('current').get(db);
    if (record == null) return const BusinessWorkspace();
    return BusinessWorkspace.fromJson(record);
  }

  Future<void> saveWorkspace(BusinessWorkspace workspace) async {
    await _workspace.record('current').put(db, workspace.toJson());
  }

  /// Idempotent: an already-imported PayMongo transaction ID is never counted
  /// twice, even if a CSV contains overlapping dates or is re-imported.
  Future<int> importPayMongo(List<PayMongoTransaction> transactions) async {
    return db.transaction((txn) async {
      var added = 0;
      for (final item in transactions) {
        if (await _paymongo.record(item.id).get(txn) != null) continue;
        await _paymongo.record(item.id).put(txn, item.toJson());
        added++;
      }
      return added;
    });
  }

  /// Atomic expense import: never overwrites an existing entry/reference.
  Future<int> importExpenses(List<BookEntry> expenses) =>
      db.transaction((txn) async {
        var added = 0;
        for (final e in expenses) {
          if (e.kind != EntryKind.expense) {
            throw ArgumentError('Only expense records may be imported.');
          }
          if (await _records.record(e.id).get(txn) != null) continue;
          await _records.record(e.id).put(txn, e.toLocalJson());
          added++;
        }
        return added;
      });

  Future<void> upsert(BookEntry entry) async {
    await _records.record(entry.id).put(db, entry.toLocalJson());
  }

  /// Atomic replacement so an interrupted restore never leaves partial books.
  Future<void> replaceAll(List<BookEntry> entries,
      List<PayMongoTransaction> paymongo,
      {BusinessWorkspace workspace = const BusinessWorkspace()}) async {
    await db.transaction((txn) async {
      await _records.delete(txn);
      await _paymongo.delete(txn);
      await _workspace.delete(txn);
      for (final entry in entries) {
        await _records.record(entry.id).put(txn, entry.toLocalJson());
      }
      for (final item in paymongo) {
        await _paymongo.record(item.id).put(txn, item.toJson());
      }
      await _workspace.record('current').put(txn, workspace.toJson());
    });
  }

  Future<void> remove(String id) async {
    await _records.record(id).delete(db);
  }

  Future<void> close() => db.close();
}
