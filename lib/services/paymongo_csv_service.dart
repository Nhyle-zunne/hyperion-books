import 'dart:convert';
import 'package:file_selector/file_selector.dart';
import '../models/paymongo_transaction.dart';

/// Strictly parses the PayMongo TRANSACTIONS report, not settlement payouts.
class PayMongoCsvPreview {
  final List<PayMongoTransaction> transactions;
  final int ignored;
  const PayMongoCsvPreview(this.transactions, this.ignored);
}

class PayMongoCsvService {
  static const maxBytes = 12 * 1024 * 1024;
  static const maxRows = 50000;

  static Future<PayMongoCsvPreview?> select() async {
    const group = XTypeGroup(label: 'PayMongo transaction CSV',
      extensions: ['csv'], mimeTypes: ['text/csv', 'application/vnd.ms-excel']);
    final file = await openFile(acceptedTypeGroups: [group]);
    if (file == null) return null;
    if (await file.length() > maxBytes) {
      throw const FormatException('CSV is too large (12 MB maximum).');
    }
    return parse(await file.readAsString());
  }

  static PayMongoCsvPreview parse(String csv) {
    if (utf8.encode(csv).length > maxBytes) {
      throw const FormatException('CSV is too large (12 MB maximum).');
    }
    final matrix = _parseCsv(csv.replaceFirst('\uFEFF', ''));
    if (matrix.isEmpty) throw const FormatException('CSV is empty.');
    final headers = <String, int>{};
    for (var i = 0; i < matrix.first.length; i++) {
      headers[matrix.first[i].trim().toLowerCase()] = i;
    }
    const required = [
      'transaction id', 'type', 'currency', 'gross amount',
      'fee', 'vat', 'net amount', 'status', 'transaction date',
    ];
    if (required.any((h) => !headers.containsKey(h))) {
      throw const FormatException(
        'This is not a supported PayMongo transaction CSV. '
        'Export Transactions with Transaction ID, Type, Gross, Fee, VAT, '
        'Net Amount, Status and Transaction Date.');
    }
    String cell(List<String> row, String name) {
      final index = headers[name];
      return index == null || index >= row.length ? '' : row[index].trim();
    }

    final seen = <String>{};
    final parsed = <PayMongoTransaction>[];
    var ignored = 0;
    for (var i = 1; i < matrix.length; i++) {
      final row = matrix[i];
      if (row.every((s) => s.trim().isEmpty)) continue;
      if (row.length != matrix.first.length) {
        throw FormatException('Invalid column count on CSV row ${i + 1}.');
      }
      final type = cell(row, 'type');
      final status = cell(row, 'status');
      final active = (type == 'Payment' && status == 'Paid') ||
          (type == 'Adjustment' && status == 'Succeeded') ||
          (type == 'Refund' && (status == 'Succeeded' || status == 'Refunded'));
      if (!active) {
        ignored++;
        continue;
      }
      if (cell(row, 'currency').toUpperCase() != 'PHP') {
        throw FormatException('Only PHP transactions are supported (row ${i + 1}).');
      }
      final id = cell(row, 'transaction id');
      if (id.isEmpty || id.length > 160 ||
          !RegExp(r'^[A-Za-z0-9_\-]+$').hasMatch(id)) {
        throw FormatException('Invalid Transaction ID on row ${i + 1}.');
      }
      if (!seen.add(id)) {
        throw FormatException('Duplicate Transaction ID inside CSV on row ${i + 1}.');
      }
      final occurredAt = _parseDateTime(cell(row, 'transaction date'), i + 1);
      parsed.add(PayMongoTransaction(
        id: id, type: type, status: status,
        occurredAt: occurredAt,
        paymentMethod: cell(row, 'payment method'),
        grossCentavos: _money(cell(row, 'gross amount'), i + 1),
        feeCentavos: _money(cell(row, 'fee'), i + 1),
        vatCentavos: _money(cell(row, 'vat'), i + 1),
        netCentavos: _money(cell(row, 'net amount'), i + 1),
      ));
    }
    parsed.sort((a,b) {
      final cmp = b.occurredAt.compareTo(a.occurredAt);
      return cmp != 0 ? cmp : a.id.compareTo(b.id);
    });
    return PayMongoCsvPreview(parsed, ignored);
  }

  static int _money(String raw, int row) {
    final value = raw.trim().replaceAll(',', '').replaceAll('₱', '');
    final match = RegExp(r'^(-?)(\d{1,12})(?:\.(\d{1,2}))?$').firstMatch(value);
    if (match == null) throw FormatException('Invalid amount on CSV row $row.');
    final centavos = int.parse(match.group(2)!) * 100 +
      int.parse((match.group(3) ?? '').padRight(2, '0').isEmpty
        ? '0' : (match.group(3) ?? '').padRight(2, '0'));
    return match.group(1) == '-' ? -centavos : centavos;
  }

  static DateTime _parseDateTime(String raw, int row) {
    // PayMongo CSV exports use both ISO dates and slash-separated US dates.
    // Preserve the wall-clock time: these files don't declare a timezone.
    // E.g. 2026-11-04 13:51, 2026-11-04T13:51:00, 11/04/2026 13:51.
    final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})[ T]'
      r'(\d{1,2}):(\d{2})(?::(\d{2}))?$').firstMatch(raw);
    final monthFirst = iso == null
      ? RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})\s+'
          r'(\d{1,2}):(\d{2})(?::(\d{2}))?$').firstMatch(raw)
      : null;
    final match = iso ?? monthFirst;
    if (match == null) {
      throw FormatException(
        'Unsupported date/time on CSV row $row: expected '
        'YYYY-MM-DD HH:MM or MM/DD/YYYY HH:MM.');
    }
    final year = int.parse(match.group(iso != null ? 1 : 3)!);
    final month = int.parse(match.group(iso != null ? 2 : 1)!);
    final day = int.parse(match.group(iso != null ? 3 : 2)!);
    final hour = int.parse(match.group(4)!);
    final minute = int.parse(match.group(5)!);
    final second = int.parse(match.group(6) ?? '0');
    final d = DateTime(year, month, day, hour, minute, second);
    if (year < 2000 || year > 2100 || d.year != year || d.month != month ||
        d.day != day || d.hour != hour || d.minute != minute ||
        d.second != second) {
      throw FormatException('Out-of-range date/time on CSV row $row.');
    }
    return d;
  }

  /// Shared safe RFC4180 reader for local sales imports.
  static List<List<String>> readRows(String text) =>
      _parseCsv(text.replaceFirst('\uFEFF', ''));

  /// RFC 4180-style quoted CSV handling, including embedded commas/newlines.
  static List<List<String>> _parseCsv(String text) {
    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var quoted = false, atFieldStart = true;
    void pushField() {
      row.add(field.toString());
      field.clear();
      atFieldStart = true;
    }
    void pushRow() {
      pushField();
      if (row.any((c) => c.isNotEmpty)) rows.add(row);
      row = <String>[];
      if (rows.length > maxRows + 1) {
        throw const FormatException('CSV contains too many rows.');
      }
    }
    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if (char == '"') {
        if (quoted && i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else if (quoted) {
          quoted = false;
        } else if (atFieldStart) {
          quoted = true;
          atFieldStart = false;
        } else {
          throw const FormatException('Malformed quoted CSV field.');
        }
      } else if (quoted) {
        field.write(char);
      } else if (char == ',') {
        pushField();
      } else if (char == '\n' || char == '\r') {
        if (char == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
        pushRow();
      } else {
        field.write(char);
        atFieldStart = false;
      }
    }
    if (quoted) throw const FormatException('Unclosed quoted field in CSV.');
    if (row.isNotEmpty || field.isNotEmpty) pushRow();
    return rows;
  }
}
