import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/accounting_books.dart';
import '../models/book_entry.dart';
import '../models/business_workspace.dart';
import '../models/paymongo_transaction.dart';
import '../services/export_service.dart';
import '../services/report_printer.dart';

const _navy = Color(0xFF112940);
const _muted = Color(0xFF63748A);
const _gold = Color(0xFFF2CB55);
final _money = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
String _peso(int centavos) => centavos == 0 ? '' : _money.format(centavos / 100);
String _stamp(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
String _code(String account) => account.split(' ').first;
String _account(String account) => account.contains(' ')
    ? account.substring(account.indexOf(' ') + 1) : account;

/// Report view derived from existing locally stored entries. It never posts new
/// transactions or changes how PayMongo bank transfers are classified.
class AccountingBooksPage extends StatefulWidget {
  final List<BookEntry> entries;
  final List<PayMongoTransaction> transactions;
  final BusinessWorkspace workspace;
  const AccountingBooksPage({super.key, required this.entries,
    required this.transactions, required this.workspace});

  @override State<AccountingBooksPage> createState() => _AccountingBooksPageState();
}

class _ReportTable {
  final String title;
  final List<String> headers;
  final List<List<String>> rows;
  const _ReportTable(this.title, this.headers, this.rows);
}

class _AccountingBooksPageState extends State<AccountingBooksPage> {
  int _tab = 0;
  bool _optional = false;
  DateTime? _start;
  DateTime? _end;
  bool _all = false;
  bool _exporting = false;

  @override void initState() {
    super.initState();
    final now = DateTime.now();
    _start = DateTime(now.year, now.month);
    _end = DateTime(now.year, now.month + 1, 0);
  }

  bool _within(DateTime date) {
    if (_all) return true;
    final day = DateTime(date.year, date.month, date.day);
    return (_start == null || !day.isBefore(_start!)) &&
        (_end == null || !day.isAfter(_end!));
  }

  Future<void> _pick(bool begin) async {
    final chosen = await showDatePicker(context: context,
      initialDate: (begin ? _start : _end) ?? DateTime.now(),
      firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (chosen == null) return;
    final other = begin ? _end : _start;
    if (other != null && (begin ? chosen.isAfter(other) : chosen.isBefore(other))) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('The beginning date must not be after the ending date.')));
      return;
    }
    setState(() { _all = false; if (begin) { _start = chosen; } else { _end = chosen; } });
  }

  String get _period {
    if (_all) return 'All recorded dates';
    return '${_start == null ? "Beginning" : _stamp(_start!)} to '
        '${_end == null ? "Present" : _stamp(_end!)}';
  }

  _ReportTable _table(AccountingBooks books) {
    switch (_tab) {
      case 0:
        final postings = books.journal.where((p) => _within(p.date)).toList();
        final rows = <List<String>>[
          for (final p in postings) [
            p.reference, _stamp(p.date), _code(p.account), _account(p.account),
            p.particulars,
            if (_optional) p.source,
            _peso(p.debit), _peso(p.credit),
          ],
        ];
        if (postings.isNotEmpty) {
          final totalDebit = postings.fold<int>(0, (v, p) => v + p.debit);
          final totalCredit = postings.fold<int>(0, (v, p) => v + p.credit);
          rows.add(['TOTAL', '', '', '', '',
            if (_optional) '',
            _peso(totalDebit), _peso(totalCredit)]);
        }
        return _ReportTable('General Journal', [
          'Reference No.', 'Date', 'GL Code', 'GL Account',
          'Description', if (_optional) 'Source', 'Debit', 'Credit',
        ], rows);
      case 1:
        final rows = <List<String>>[];
        final accounts = books.ledger.keys.toList()..sort();
        for (final account in accounts) {
          for (final p in books.ledger[account]!) {
            if (!_within(p.posting.date)) continue;
            rows.add([
              _code(account), _account(account), _stamp(p.posting.date),
              p.posting.reference, p.posting.particulars,
              if (_optional) p.posting.source,
              _peso(p.posting.debit), _peso(p.posting.credit),
              _peso(p.debitBalance), _peso(p.creditBalance),
            ]);
          }
        }
        return _ReportTable('General Ledger', [
          'GL Code', 'GL Account', 'Date', 'Reference No.', 'Description',
          if (_optional) 'Source', 'Debit', 'Credit', 'Debit balance', 'Credit balance',
        ], rows);
      case 2:
        final receipts = books.cashReceipts.where((e) => _within(e.date)).toList();
        return _ReportTable('Cash Receipts Journal', [
          'Reference No.', 'Date', 'Description',
          if (_optional) 'Collection channel',
          'Gross collection', 'Fees incl. VAT', 'Processor net',
          'Bank received', if (_optional) 'Classification',
        ], [
          for (final e in receipts) [
            e.reference, _stamp(e.date), e.particulars,
            if (_optional) e.channel,
            _peso(e.gross), _peso(e.fees), _peso(e.processorNet),
            _peso(e.bankReceived),
            if (_optional) e.bankTransfer ? 'Transfer — not a sale' :
              e.provisional ? 'Provisional — review' : 'Collection',
          ],
        ]);
      default:
        final paid = books.cashDisbursements.where((e) => _within(e.date)).toList();
        return _ReportTable('Cash Disbursements Journal', [
          'Reference No.', 'Date', 'Description',
          'GL Code', 'Expense account', 'Cash / bank paid',
        ], [
          for (final e in paid) [
            e.reference, _stamp(e.date), e.particulars,
            _code(e.account), _account(e.account), _peso(e.amount),
          ],
        ]);
    }
  }

  Future<void> _export(_ReportTable table) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      await ExportService.exportBookTable(
        table.title, table.headers, table.rows,
        period: _period, businessName: widget.workspace.businessName);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Selected book exported to Excel.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Excel export failed: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _print(_ReportTable table) {
    final opened = ReportPrinter.printTable(
      title: table.title, period: _period,
      businessName: widget.workspace.businessName,
      headers: table.headers, rows: table.rows);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Allow pop-ups to open the printable report.')));
    }
  }

  @override Widget build(BuildContext context) {
    final books = AccountingBooks.fromSources(
      widget.entries, widget.transactions);
    final table = _table(books);
    final narrow = MediaQuery.sizeOf(context).width < 680;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
        color: Colors.white, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Books of Accounts', style: TextStyle(
              color: _navy, fontWeight: FontWeight.w900, fontSize: 22)),
            const SizedBox(height: 3),
            const Text('Journal and ledger working papers, prepared from your local records.',
              style: TextStyle(color: _muted, fontSize: 12)),
            const SizedBox(height: 15),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (var i = 0; i < 4; i++)
                _tabButton(i, const ['Journal','Ledger',
                  'Cash Receipt','Cash Disbursement'][i]),
            ]),
            const SizedBox(height: 14),
            Wrap(spacing: 10, runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center, children: [
                FilledButton.icon(
                  onPressed: _exporting ? null : () => _export(table),
                  icon: const Icon(Icons.table_view_outlined, size: 18),
                  label: const Text('Export to Excel')),
                OutlinedButton.icon(onPressed: () => _print(table),
                  icon: const Icon(Icons.print_outlined, size: 18),
                  label: const Text('Print Report')),
              ]),
          ])),
      Expanded(child: ListView(padding: const EdgeInsets.all(16),
        children: [
          Card(child: Padding(padding: const EdgeInsets.all(15),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Covered Period', style: TextStyle(
                fontWeight: FontWeight.w800, color: _navy)),
              const SizedBox(height: 9),
              Wrap(spacing: 9, runSpacing: 9,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _pick(true),
                    icon: const Icon(Icons.event, size: 18),
                    label: Text(_start == null ? 'Begin date' : _stamp(_start!))),
                  const Text('to', style: TextStyle(color: _muted)),
                  OutlinedButton.icon(
                    onPressed: () => _pick(false),
                    icon: const Icon(Icons.event, size: 18),
                    label: Text(_end == null ? 'End date' : _stamp(_end!))),
                  TextButton(onPressed: () => setState(() => _all = !_all),
                    child: Text(_all ? 'Use selected dates' : 'All dates')),
                ]),
              const SizedBox(height: 8),
              CheckboxListTile(
                dense: true, contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Show optional columns'),
                value: _optional,
                onChanged: (v) => setState(() => _optional = v ?? false)),
              const CheckboxListTile(
                dense: true, contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text('Include voided entries'),
                subtitle: Text('Not available: deleted entries are removed from local records.'),
                value: false, onChanged: null),
              const CheckboxListTile(
                dense: true, contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text('Include unverified'),
                subtitle: Text('On by default; source-level verification tracking is not available yet.'),
                value: true, onChanged: null),
            ]))),
          const SizedBox(height: 15),
          Card(child: Padding(padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.workspace.businessName.trim().isEmpty ?
                'HYPERION BOOKS' : widget.workspace.businessName.trim(),
                style: const TextStyle(color: _navy,
                  fontWeight: FontWeight.w900, fontSize: 17)),
              const SizedBox(height: 5),
              Text(table.title, style: const TextStyle(
                color: _navy, fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 3),
              Text('For the period $_period', style: const TextStyle(
                color: _muted, fontSize: 12)),
              const SizedBox(height: 14),
              if (table.rows.isEmpty)
                const Padding(padding: EdgeInsets.symmetric(vertical: 35),
                  child: Center(child: Text(
                    'No entries for this period. Select All dates or import transactions.',
                    textAlign: TextAlign.center)))
              else
                SingleChildScrollView(scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      const Color(0xFFF0F4F9)),
                    headingTextStyle: const TextStyle(
                      color: _navy, fontWeight: FontWeight.w900),
                    columnSpacing: narrow ? 16 : 24,
                    columns: [
                      for (final label in table.headers)
                        DataColumn(label: Text(label)),
                    ],
                    rows: [
                      for (final row in table.rows)
                        DataRow(cells: [
                          for (final value in row)
                            DataCell(ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 250),
                              child: SelectableText(value,
                                style: const TextStyle(fontSize: 12)))),
                        ]),
                    ],
                  )),
            ]))),
          const SizedBox(height: 13),
          if (books.warnings.isNotEmpty)
            Card(child: Padding(padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Reconciliation notices', style: TextStyle(
                  color: _navy, fontWeight: FontWeight.w800)),
                const SizedBox(height: 7),
                for (final warning in books.warnings)
                  Padding(padding: const EdgeInsets.only(bottom: 5),
                    child: Text('• $warning',
                      style: const TextStyle(fontSize: 12, color: _muted))),
              ]))),
          const SizedBox(height: 6),
          const Text('DRAFT WORKING PAPERS ONLY · Not BIR-registered computerized books. '
            'These tables do not establish invoice validity, account verification '
            'or filing compliance. Period-filtered ledger balances include earlier '
            'postings; reconcile against source invoices and bank statements.',
            style: TextStyle(color: _muted, fontSize: 11)),
          const SizedBox(height: 20),
        ])),
    ]);
  }

  Widget _tabButton(int index, String label) {
    final active = _tab == index;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: active ? _navy : Colors.white,
        foregroundColor: active ? Colors.white : _navy,
        side: BorderSide(color: active ? _navy : const Color(0xFFDAE3ED))),
      onPressed: () => setState(() => _tab = index),
      child: Text(label));
  }
}
