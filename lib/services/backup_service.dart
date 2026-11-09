import 'dart:convert';
import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';
import 'package:file_selector/file_selector.dart';
import 'package:intl/intl.dart';
import '../models/book_entry.dart';
import '../models/paymongo_transaction.dart';
import '../models/business_workspace.dart';

/// Restorable, unencrypted JSON (separate from the human-readable Excel export).
class BooksBackup {
  final List<BookEntry> entries;
  final List<PayMongoTransaction> paymongo;
  final BusinessWorkspace workspace;
  const BooksBackup(this.entries, this.paymongo,
      {this.workspace = const BusinessWorkspace()});
}

class BackupService {
  static const int schemaVersion = 3;
  static const int maxEntries = 100000;
  static const int maxBytes = 15 * 1024 * 1024;

  static String encode(Iterable<BookEntry> entries,
      {Iterable<PayMongoTransaction> paymongo = const [],
       BusinessWorkspace workspace = const BusinessWorkspace()}) =>
    const JsonEncoder.withIndent('  ').convert({
      'format': 'hyperion-books-backup',
      'schema_version': schemaVersion,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'entries': entries.map((e) => e.toBackupJson()).toList(),
      'paymongo': paymongo.map((e) => e.toJson()).toList(),
      'workspace': workspace.toJson(),
    });

  /// Keep the old entry-only API for compatibility with existing tests/tools.
  static List<BookEntry> decode(String contents) => decodeFull(contents).entries;

  /// Reads both old v1 entry-only backups and new v2 backups with imported
  /// PayMongo transactions. Import never sends data to GitHub or any server.
  static BooksBackup decodeFull(String contents) {
    if (utf8.encode(contents).length > maxBytes) throw const FormatException('Backup too large');
    final object = jsonDecode(contents);
    if (object is! Map<String, dynamic> || object['format'] != 'hyperion-books-backup' ||
        ![1, 2, schemaVersion].contains(object['schema_version']) ||
        object['entries'] is! List ||
        (object['schema_version'] != 1 && object['paymongo'] is! List) ||
        (object['schema_version'] == schemaVersion &&
            object['workspace'] is! Map<String, dynamic>)) {
      throw const FormatException('Not a supported Hyperion Books JSON backup');
    }
    final rawEntries = object['entries'] as List;
    if (rawEntries.length > maxEntries) throw const FormatException('Too many entries');
    final ids = <String>{};
    final entries = <BookEntry>[];
    for (final raw in rawEntries) {
      if (raw is! Map<String, dynamic>) throw const FormatException('Invalid entry');
      final entry = BookEntry.fromBackupJson(raw);
      if (!ids.add(entry.id)) throw const FormatException('Duplicate entry ID');
      entries.add(entry);
    }
    final imported = <PayMongoTransaction>[];
    final paymongoIds = <String>{};
    final rawTransactions = object['schema_version'] == 1
      ? <dynamic>[] : object['paymongo'] as List;
    if (rawTransactions.length > maxEntries) {
      throw const FormatException('Too many imported PayMongo transactions');
    }
    for (final raw in rawTransactions) {
      if (raw is! Map<String, dynamic>) throw const FormatException('Invalid PayMongo record');
      final item = PayMongoTransaction.fromJson(raw);
      if (!paymongoIds.add(item.id)) throw const FormatException('Duplicate PayMongo ID');
      imported.add(item);
    }
    final workspace = object['schema_version'] == schemaVersion
        ? BusinessWorkspace.fromJson(
            object['workspace'] as Map<String, dynamic>)
        : const BusinessWorkspace();
    return BooksBackup(entries, imported, workspace: workspace);
  }

  static Future<void> export(List<BookEntry> entries,
      {List<PayMongoTransaction> paymongo = const [],
       BusinessWorkspace workspace = const BusinessWorkspace()}) async {
    final bytes = Uint8List.fromList(utf8.encode(encode(entries, paymongo: paymongo,
      workspace: workspace)));
    await FileSaver.instance.saveFile(
      name: 'Hyperion_Books_BACKUP_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}',
      bytes: bytes, fileExtension: 'json', mimeType: MimeType.custom,
      customMimeType: 'application/json',
    );
  }

  static Future<BooksBackup?> selectAndRead() async {
    const typeGroup = XTypeGroup(label: 'Hyperion Books JSON backup',
      extensions: ['json'], mimeTypes: ['application/json']);
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return null;
    if (await file.length() > maxBytes) throw const FormatException('Backup too large');
    return decodeFull(await file.readAsString());
  }
}
