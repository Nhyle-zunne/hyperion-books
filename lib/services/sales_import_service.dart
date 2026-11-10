import 'dart:convert';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_selector/file_selector.dart';
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';
import '../models/paymongo_transaction.dart';
import 'paymongo_csv_service.dart';

/// Unified, provider-neutral sales import. Existing export layouts remain
/// compatible, but users can also use the documented Hyperion Sales template.
///
/// A stable unique reference is required: matching dates and amounts do not
/// prove two separate sales are the same transaction.
class SalesImportPreview {
  final List<PayMongoTransaction> transactions;
  final int ignored;
  final String sourceFormat;
  const SalesImportPreview(this.transactions, this.ignored, this.sourceFormat);
}

class SalesImportService {
  static const maxBytes = 12 * 1024 * 1024;
  static const maxRows = 50000;
  static const template =
      'Reference,Date,Gross Amount,Fee,Fee VAT,Net Amount,Status,Payment Method,Type,Currency,Customer Name,Customer Email,Customer Phone,Buyer Address,Buyer TIN\n'
      'SALE-0001,2026-11-10 09:30,1000.00,-15.00,-1.61,985.00,Paid,Bank Transfer,Payment,PHP,Sample Customer,buyer@example.test,+63-900-000-0000,,\n';

  static Future<SalesImportPreview?> select() async {
    const group = XTypeGroup(label: 'Sales CSV or Excel workbook',
      extensions: ['csv', 'xlsx'],
      mimeTypes: ['text/csv',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet']);
    final file = await openFile(acceptedTypeGroups: [group]);
    if (file == null) return null;
    if (await file.length() > maxBytes) {
      throw const FormatException('Sales file exceeds 12 MB.');
    }
    final bytes = await file.readAsBytes();
    if (file.name.toLowerCase().endsWith('.xlsx')) {
      return parseWorkbook(bytes);
    }
    if (file.name.toLowerCase().endsWith('.csv')) {
      return parseCsv(utf8.decode(bytes, allowMalformed: false));
    }
    throw const FormatException('Select a .csv or .xlsx sales file.');
  }

  static Future<void> downloadTemplate() async {
    await FileSaver.instance.saveFile(
      name: 'Hyperion_Sales_Import_Template',
      bytes: Uint8List.fromList(utf8.encode(template)),
      fileExtension: 'csv', mimeType: MimeType.custom,
      customMimeType: 'text/csv',
    );
  }

  static SalesImportPreview parseCsv(String input) {
    if (utf8.encode(input).length > maxBytes) {
      throw const FormatException('Sales file exceeds 12 MB.');
    }
    return parseRows(PayMongoCsvService.readRows(input));
  }

  static SalesImportPreview parseWorkbook(List<int> bytes) {
    if (bytes.length > maxBytes) {
      throw const FormatException('Excel file exceeds 12 MB.');
    }
    final workbook = Excel.decodeBytes(bytes);
    final available = workbook.tables.values.where((sheet) => sheet.maxRows > 0);
    if (available.isEmpty) {
      throw const FormatException('The selected workbook has no sales rows.');
    }
    final sheet = available.first;
    if (sheet.maxRows > maxRows + 1 || sheet.maxColumns > 100) {
      throw const FormatException('Excel worksheet is too large.');
    }
    final rows = <List<String>>[];
    for (final cells in sheet.rows) {
      final row = <String>[];
      for (final cell in cells) {
        final value = cell?.value;
        final text = switch (value) {
          null => '',
          TextCellValue() => _plainText(value.value),
          IntCellValue() => value.value.toString(),
          DoubleCellValue() => value.value.toString(),
          DateCellValue() =>
            DateFormat('yyyy-MM-dd HH:mm').format(value.asDateTimeLocal()),
          DateTimeCellValue() =>
            DateFormat('yyyy-MM-dd HH:mm:ss').format(value.asDateTimeLocal()),
          BoolCellValue() => value.value.toString(),
          FormulaCellValue() => throw const FormatException(
            'Formula cells are not supported for sales imports. '
            'Paste values into a new worksheet and try again.'),
          TimeCellValue() => throw const FormatException(
            'Time-only cells are not supported. Provide a date and time.'),
        };
        row.add(text);
      }
      if (row.any((cell) => cell.trim().isNotEmpty)) rows.add(row);
    }
    final preview = parseRows(rows);
    return SalesImportPreview(preview.transactions, preview.ignored, 'Excel');
  }

  static SalesImportPreview parseRows(List<List<String>> rows) {
    if (rows.isEmpty) throw const FormatException('Sales file is empty.');
    if (rows.length > maxRows + 1) {
      throw const FormatException('Sales file has too many rows.');
    }
    final header = <String,int>{};
    for (var i = 0; i < rows.first.length; i++) {
      final label = rows.first[i].trim().toLowerCase();
      if (label.isEmpty) continue;
      if (header.containsKey(label)) {
        throw FormatException('Duplicate column heading "$label".');
      }
      header[label] = i;
    }

    // Read established transaction exports without altering their accounting
    // semantics. These private source formats are intentionally not exposed as
    // branded choices in the Sales interface.
    final legacy = ['transaction id', 'type', 'currency', 'gross amount',
      'fee', 'vat', 'net amount', 'status', 'transaction date']
        .every(header.containsKey);
    if (legacy) {
      final result = PayMongoCsvService.parse(_asCsv(rows));
      return SalesImportPreview(result.transactions, result.ignored, 'CSV / Excel');
    }

    int? column(List<String> names) {
      for (final name in names) {
        final index = header[name];
        if (index != null) return index;
      }
      return null;
    }
    final referenceColumn = column(['reference','transaction id','sale id','order id']);
    final dateColumn = column(['date','transaction date','sale date','timestamp']);
    final grossColumn = column(['gross amount','amount','sales amount','total']);
    if (referenceColumn == null || dateColumn == null || grossColumn == null) {
      throw const FormatException(
        'Missing sales columns: Reference, Date and Gross Amount. '
        'Download the Hyperion Sales template and use unique references.');
    }
    final feeColumn = column(['fee','fees','processing fee']);
    final vatColumn = column(['fee vat','vat portion','vat on fees','vat']);
    final netColumn = column(['net amount','net']);
    final statusColumn = column(['status','payment status']);
    final methodColumn = column(['payment method','method','channel']);
    final typeColumn = column(['type','transaction type']);
    final currencyColumn = column(['currency']);
    final customerColumn = column(['customer name','buyer name','billing name','customer','name']);
    final emailColumn = column(['customer email','buyer email','email address','email','billing email']);
    final phoneColumn = column(['customer phone','phone','phone number','mobile number','contact number','billing phone']);
    final addressColumn = column(['buyer address','billing address','customer address','address']);
    final tinColumn = column(['buyer tin','customer tin','billing tin','tin']);
    String cell(List<String> row, int? index) =>
      index == null || index >= row.length ? '' : row[index].trim();

    final normalized = <List<String>>[
      ['Transaction ID','Type','Currency','Gross Amount','Fee','VAT',
       'Net Amount','Status','Transaction Date','Payment Method',
       'Customer Name','Customer Email','Customer Phone',
       'Buyer Address','Buyer TIN'],
    ];
    final seen = <String>{};
    var ignored = 0;
    for (var index = 1; index < rows.length; index++) {
      final row = rows[index];
      final line = index + 1;
      if (row.every((s) => s.trim().isEmpty)) continue;
      if (row.length != rows.first.length) {
        throw FormatException('Invalid number of columns on row $line.');
      }
      final ref = cell(row, referenceColumn);
      if (!RegExp(r'^[A-Za-z0-9_-]{6,160}$').hasMatch(ref)) {
        throw FormatException('Row $line has an invalid Reference. '
          'Use a unique reference of 6–160 letters, numbers, underscores or hyphens.');
      }
      if (!seen.add(ref)) {
        throw FormatException('Reference "$ref" occurs twice in this file.');
      }
      final currency = cell(row, currencyColumn);
      if (currency.isNotEmpty && currency.toUpperCase() != 'PHP') {
        throw FormatException('Only PHP sales are supported (row $line).');
      }
      final rawType = cell(row, typeColumn).toLowerCase();
      final type = switch (rawType) {
        '' || 'sale' || 'payment' => 'Payment',
        'refund' => 'Refund',
        'adjustment' => 'Adjustment',
        _ => throw FormatException('Unsupported sale type on row $line.'),
      };
      final rawStatus = cell(row, statusColumn).toLowerCase();
      if (['pending','unpaid','failed','cancelled','canceled','void',
        'draft','rejected'].contains(rawStatus)) {
        ignored++;
        continue;
      }
      if (!['','paid','completed','complete','settled','succeeded',
        'success','refunded'].contains(rawStatus)) {
        throw FormatException('Unsupported status on row $line.');
      }
      final status = type == 'Payment' ? 'Paid' : 'Succeeded';
      final gross = _money(cell(row, grossColumn), line);
      final feeRaw = cell(row, feeColumn);
      final fee = feeRaw.isEmpty ? 0 : _money(feeRaw, line);
      final vatRaw = cell(row, vatColumn);
      final vat = vatRaw.isEmpty ? 0 : _money(vatRaw, line);
      final signedFee = fee > 0 ? -fee : fee;
      final signedVat = vat > 0 ? -vat : vat;
      if (signedVat.abs() > signedFee.abs()) {
        throw FormatException('Fee VAT cannot exceed the total fee (row $line).');
      }
      if (type == 'Payment' && gross <= 0) {
        throw FormatException('A paid sale must have a positive gross amount (row $line).');
      }
      final calculatedNet = gross + signedFee;
      final rawNet = cell(row, netColumn);
      final net = rawNet.isEmpty ? calculatedNet : _money(rawNet, line);
      if (net != calculatedNet) {
        throw FormatException('Row $line net does not equal gross plus fee. '
          'Fee VAT is already included in the fee and must not be deducted again.');
      }
      normalized.add([
        ref, type, 'PHP', _decimal(gross), _decimal(signedFee),
        _decimal(signedVat), _decimal(net), status,
        cell(row, dateColumn), cell(row, methodColumn),
        cell(row, customerColumn), cell(row, emailColumn),
        cell(row, phoneColumn), cell(row, addressColumn), cell(row, tinColumn),
      ]);
    }
    final output = PayMongoCsvService.parse(_asCsv(normalized));
    return SalesImportPreview(output.transactions, ignored + output.ignored,
      'CSV / Excel');
  }

  /// The Excel 4.x TextCellValue holds a rich TextSpan rather than a String.
  /// Preserve text exactly, including nested runs, when reading headings.
  static String _plainText(TextSpan span) =>
    (span.text ?? '') +
    (span.children ?? const <TextSpan>[]).map(_plainText).join();

  static int _money(String raw, int row) {
    final cleaned = raw.trim().replaceAll(',', '').replaceAll('₱','');
    final match = RegExp(r'^(-?)(\d{1,12})(?:\.(\d{1,2}))?$')
      .firstMatch(cleaned);
    if (match == null) {
      throw FormatException('Invalid PHP amount on row $row.');
    }
    final cents = int.parse(match.group(2)!) * 100 +
      int.parse((match.group(3) ?? '0').padRight(2, '0'));
    return match.group(1) == '-' ? -cents : cents;
  }

  static String _decimal(int cents) =>
    '${cents < 0 ? "-" : ""}${cents.abs() ~/ 100}.'
      '${(cents.abs() % 100).toString().padLeft(2, "0")}';

  static String _asCsv(List<List<String>> matrix) =>
    matrix.map((row) => row.map(_quote).join(',')).join('\n');

  static String _quote(String value) =>
    '"${value.replaceAll('"', '""')}"';
}
