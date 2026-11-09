import 'dart:convert';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:file_saver/file_saver.dart';
import '../models/book_entry.dart';

/// Import a simple expense CSV with a stable Reference. Never guess identity
/// from amount/date alone: two legitimate purchases may be identical.
class ExpenseCsvService {
  static const maxBytes = 8 * 1024 * 1024;
  static const maxRows = 20000;
  static const template = 'Reference,Date,Amount,Description,Category\n'
    'EXP-0001,2026-11-01,150.00,Hosting subscription,Software\n';

  static Future<List<BookEntry>?> select() async {
    const group = XTypeGroup(label: 'Expense records CSV',
      extensions: ['csv'], mimeTypes: ['text/csv']);
    final file = await openFile(acceptedTypeGroups: [group]);
    if (file == null) return null;
    if (await file.length() > maxBytes) {
      throw const FormatException('Expense CSV exceeds 8 MB.');
    }
    return parse(await file.readAsString());
  }

  static Future<void> downloadTemplate() async {
    await FileSaver.instance.saveFile(
      name: 'Hyperion_Expense_Import_Template',
      bytes: Uint8List.fromList(utf8.encode(template)),
      fileExtension: 'csv', mimeType: MimeType.custom,
      customMimeType: 'text/csv',
    );
  }

  static List<BookEntry> parse(String text) {
    if (utf8.encode(text).length > maxBytes) {
      throw const FormatException('Expense CSV exceeds 8 MB.');
    }
    final rows = _rows(text.replaceFirst('\uFEFF', ''));
    if (rows.isEmpty) throw const FormatException('Expense CSV is empty.');
    final headers = <String, int>{};
    for (var i = 0; i < rows.first.length; i++) {
      final header = rows.first[i].trim().toLowerCase();
      if (headers.containsKey(header)) {
        throw FormatException('Duplicate column name $header.');
      }
      headers[header] = i;
    }
    for (final required in ['reference','date','amount','description']) {
      if (!headers.containsKey(required)) {
        throw FormatException('Missing column: $required. '
          'Use the downloadable Hyperion expense template.');
      }
    }
    String cell(List<String> row, String key) {
      final i = headers[key];
      return i == null ? '' : row[i].trim();
    }
    final records = <BookEntry>[];
    final seen = <String>{};
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.every((v) => v.trim().isEmpty)) continue;
      final line = i + 1;
      if (row.length != rows.first.length) {
        throw FormatException('Wrong number of columns on row $line.');
      }
      final ref = cell(row, 'reference');
      if (!RegExp(r'^[A-Za-z0-9_.-]{1,80}$').hasMatch(ref)) {
        throw FormatException('Invalid Reference on row $line.');
      }
      final id = 'expense-import-$ref';
      if (!seen.add(id)) {
        throw FormatException('Duplicate Reference on row $line.');
      }
      final date = _date(cell(row, 'date'), line);
      final amount = parsePesos(cell(row, 'amount'));
      final description = cell(row, 'description');
      final category = cell(row, 'category');
      if (amount == null || amount <= 0 || amount > 100000000000000) {
        throw FormatException('Invalid positive amount on row $line.');
      }
      if (description.isEmpty || description.length > 1000 ||
          category.length > 150) {
        throw FormatException('Invalid description or category on row $line.');
      }
      records.add(BookEntry(
        id: id, userId: 'local', kind: EntryKind.expense,
        date: date, platform: '', description: description,
        category: category.isEmpty ? 'General' : category,
        amountCentavos: amount, dirty: false,
      ));
      if (records.length > maxRows) {
        throw const FormatException('Too many expense rows (max 20,000).');
      }
    }
    records.sort((a, b) {
      final order = a.date.compareTo(b.date);
      return order != 0 ? order : a.id.compareTo(b.id);
    });
    return records;
  }

  static DateTime _date(String raw, int line) {
    final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(raw);
    final slash = iso == null
      ? RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(raw) : null;
    final m = iso ?? slash;
    if (m == null) {
      throw FormatException('Invalid date on row $line; use YYYY-MM-DD.');
    }
    final year = int.parse(m.group(iso != null ? 1 : 3)!);
    final month = int.parse(m.group(iso != null ? 2 : 1)!);
    final day = int.parse(m.group(iso != null ? 3 : 2)!);
    final parsed = DateTime(year, month, day);
    if (year < 2000 || year > 2100 || parsed.year != year ||
        parsed.month != month || parsed.day != day) {
      throw FormatException('Invalid calendar date on row $line.');
    }
    return parsed;
  }

  static List<List<String>> _rows(String csv) {
    final rows = <List<String>>[];
    var row = <String>[];
    final current = StringBuffer();
    var quoted = false, atStart = true;
    void endField() {
      row.add(current.toString());
      current.clear();
      atStart = true;
    }
    void endRow() {
      endField();
      if (row.any((x) => x.isNotEmpty)) rows.add(row);
      row = <String>[];
    }
    for (var i = 0; i < csv.length; i++) {
      final c = csv[i];
      if (c == '"') {
        if (quoted && i + 1 < csv.length && csv[i + 1] == '"') {
          current.write('"'); i++;
        } else if (quoted) {
          quoted = false;
        } else if (atStart) {
          quoted = true;
          atStart = false;
        } else {
          throw const FormatException('Malformed quoted CSV field.');
        }
      } else if (quoted) {
        current.write(c);
      } else if (c == ',') {
        endField();
      } else if (c == '\r' || c == '\n') {
        if (c == '\r' && i + 1 < csv.length && csv[i + 1] == '\n') i++;
        endRow();
      } else {
        current.write(c); atStart = false;
      }
    }
    if (quoted) throw const FormatException('Unclosed CSV quotation.');
    if (row.isNotEmpty || current.isNotEmpty) endRow();
    return rows;
  }
}
