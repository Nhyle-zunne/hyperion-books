import 'dart:convert';
import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';
import 'package:file_selector/file_selector.dart';
import 'package:intl/intl.dart';
import '../models/book_entry.dart';

/// Restorable, unencrypted JSON (separate from the human-readable Excel export).
class BackupService {
  static const int schemaVersion = 1;
  static const int maxEntries = 100000;
  static const int maxBytes = 15 * 1024 * 1024;

  static String encode(Iterable<BookEntry> entries) => const JsonEncoder.withIndent('  ').convert({
    'format': 'hyperion-books-backup',
    'schema_version': schemaVersion,
    'created_at': DateTime.now().toUtc().toIso8601String(),
    'entries': entries.map((e) => e.toBackupJson()).toList(),
  });

  static List<BookEntry> decode(String contents) {
    if (utf8.encode(contents).length > maxBytes) throw const FormatException('Backup too large');
    final object = jsonDecode(contents);
    if (object is! Map<String, dynamic> || object['format'] != 'hyperion-books-backup' ||
        object['schema_version'] != schemaVersion || object['entries'] is! List) {
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
    return entries;
  }

  static Future<void> export(List<BookEntry> entries) async {
    final bytes = Uint8List.fromList(utf8.encode(encode(entries)));
    await FileSaver.instance.saveFile(
      name: 'Hyperion_Books_BACKUP_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}',
      bytes: bytes, fileExtension: 'json', mimeType: MimeType.custom,
      customMimeType: 'application/json',
    );
  }

  static Future<List<BookEntry>?> selectAndRead() async {
    const typeGroup = XTypeGroup(label: 'Hyperion Books JSON backup',
      extensions: ['json'], mimeTypes: ['application/json']);
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return null;
    if (await file.length() > maxBytes) throw const FormatException('Backup too large');
    return decode(await file.readAsString());
  }
}
