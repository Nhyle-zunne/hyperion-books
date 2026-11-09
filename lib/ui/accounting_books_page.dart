import 'package:flutter/material.dart';
import '../theme/hyperion_theme.dart';
import 'package:intl/intl.dart';
import '../models/accounting_books.dart';
import '../models/book_table_view.dart';
import 'books_compact_table.dart';
import '../models/book_entry.dart';
import '../models/business_workspace.dart';
import '../models/paymongo_transaction.dart';
import '../services/export_service.dart';
import '../services/report_printer.dart';

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
  final Future<void> Function(BusinessWorkspace) save;
  final int initialTab;
  const AccountingBooksPage({super.key, required this.entries,
    required this.transactions, required this.workspace, required this.save,
    this.initialTab = 0});

  @override State<AccountingBooksPage> createState() => _AccountingBooksPageState();
}

class _AccountingBooksPageState extends State<AccountingBooksPage> {
  late int _tab;
  bool _includeVoided = false;
  bool _includeUnverified = true;
  DateTime? _start;
  DateTime? _end;
  bool _all = false;
  bool _exporting = false;
  bool _showReviewFilters = false;
  String? _ledgerAccount;
  final ScrollController _pageScroll = ScrollController();

  @override void dispose() {
    _pageScroll.dispose();
    super.dispose();
  }

  @override void initState() {
    super.initState();
    _tab = widget.initialTab.clamp(0, 3);
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('The beginning date must not be after the ending date.')));
      }
      return;
    }
    setState(() { _all = false; if (begin) { _start = chosen; } else { _end = chosen; } });
  }

  String get _period {
    if (_all) return 'All recorded dates';
    return '${_start == null ? "Beginning" : _stamp(_start!)} to '
        '${_end == null ? "Present" : _stamp(_end!)}';
  }

  BookTableData _table(AccountingBooks books) => BookTableData.build(
    books: books,
    bookIndex: _tab,
    start: _start, end: _end, allDates: _all,
    requestedLedgerAccount: _ledgerAccount,
    voidedReferences: widget.workspace.voidedReferences.toSet(),
    verifiedReferences: widget.workspace.verifiedReferences.toSet(),
    includeVoided: _includeVoided,
    includeUnverified: _includeUnverified,
  );

  Future<void> _manageReference(String ref) async {
    PayMongoTransaction? transaction;
    BookEntry? manual;
    for (final item in widget.transactions) {
      if (item.id == ref) { transaction = item; break; }
    }
    for (final item in widget.entries) {
      if (item.id == ref) { manual = item; break; }
    }
    final verified = widget.workspace.verifiedReferences.contains(ref);
    final voided = widget.workspace.voidedReferences.contains(ref);
    Widget detail(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 120, child: Text(label, style: TextStyle(
          fontSize: 12, color: HyperionColors.muted, fontWeight: FontWeight.w600))),
        Expanded(child: SelectableText(value,
          style: TextStyle(fontSize: 13))),
      ]));
    final choice = await showDialog<String>(context: context, builder: (d) =>
      AlertDialog(
        title: Text('Source transaction details'),
        content: SizedBox(width: 530, child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            detail('Reference', ref),
            if (transaction != null) ...[
              detail('Source', transaction.isManual ? 'Manual direct sale' : 'Sales import'),
              if (transaction.isManual && transaction.reference.isNotEmpty)
                detail('Payment reference', transaction.reference),
              if (transaction.isManual)
                detail('Product / service', transaction.description),
              if (transaction.isManual && transaction.depositAccount.isNotEmpty)
                detail('Received into', transaction.depositAccount),
              detail('Date/time', DateFormat('MMM d, yyyy, h:mm a').format(transaction.occurredAt)),
              detail('Type', transaction.type),
              detail('Status', transaction.status),
              detail('Payment method', transaction.paymentMethod),
              detail('Gross amount', _money.format(transaction.grossCentavos / 100)),
              detail('Fee (as exported)', _money.format(transaction.feeCentavos / 100)),
              detail('Fee VAT component', _money.format(transaction.vatCentavos / 100)),
              detail('Net amount', _money.format(transaction.netCentavos / 100)),
            ] else if (manual != null) ...[
              detail('Source', manual.kind == EntryKind.expense ?
                'Manually entered expense' : 'Manually entered bank payout'),
              detail('Date', _stamp(manual.date)),
              detail('Description', manual.description.isEmpty ? '—' : manual.description),
              detail('Platform', manual.platform),
              detail('Category', manual.category),
              detail('Amount', _money.format(manual.amountCentavos / 100)),
              if (manual.grossCentavos != null)
                detail('Reported gross', _money.format(manual.grossCentavos! / 100)),
            ] else
              Text('No matching source transaction on this device.',
                style: TextStyle(color: HyperionColors.muted)),
            Divider(height: 26),
            Text('Book working-paper review',
              style: TextStyle(fontWeight: FontWeight.w800)),
            SizedBox(height: 4),
            Text('These manual flags only change draft book views. '
              'They do not change the original CSV or establish BIR verification.',
              style: TextStyle(fontSize: 12, color: HyperionColors.muted)),
            ListTile(contentPadding: EdgeInsets.zero,
              leading: Icon(verified ? Icons.verified : Icons.verified_outlined),
              title: Text(verified ? 'Remove manual verification' : 'Mark manually verified'),
              onTap: () => Navigator.pop(d, 'verify')),
            ListTile(contentPadding: EdgeInsets.zero,
              leading: Icon(voided ? Icons.restore : Icons.block_outlined),
              title: Text(voided ? 'Restore in draft reports' : 'Exclude from draft reports'),
              onTap: () => Navigator.pop(d, 'void')),
          ]))),
        actions: [TextButton(onPressed: () => Navigator.pop(d),
          child: Text('Close'))]));
    if (choice == null) return;
    final next = choice == 'verify'
      ? widget.workspace.copyWith(verifiedReferences: [
          for (final id in widget.workspace.verifiedReferences)
            if (id != ref) id,
          if (!verified) ref,
        ])
      : widget.workspace.copyWith(voidedReferences: [
          for (final id in widget.workspace.voidedReferences)
            if (id != ref) id,
          if (!voided) ref,
        ]);
    try {
      await widget.save(next);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Book review flag saved locally. Back up your records.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not save flag: $error')));
      }
    }
  }

  Future<void> _export(BookTableData table) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      await ExportService.exportBookTable(
        table.ledgerAccount == null ? table.title :
          '${table.title} - ${table.ledgerAccount}',
        table.headers, table.rows,
        period: _period, businessName: widget.workspace.businessName,
        businessTin: widget.workspace.businessTin,
        businessAddress: widget.workspace.businessAddress);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Selected book exported to Excel.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Excel export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _print(BookTableData table) {
    final opened = ReportPrinter.printTable(
      title: table.ledgerAccount == null ? table.title :
        '${table.title} - ${table.ledgerAccount}', period: _period,
      businessName: widget.workspace.businessName,
      businessTin: widget.workspace.businessTin,
      businessAddress: widget.workspace.businessAddress,
      headers: table.headers, rows: table.rows);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Allow pop-ups to open the printable report.')));
    }
  }

  @override Widget build(BuildContext context) {
    final books = AccountingBooks.fromSources(
      widget.entries, widget.transactions);
    final report = _table(books);
    return LayoutBuilder(builder: (context, viewport) {
      final narrow = viewport.maxWidth < 700;
      final dataHeight = (viewport.maxHeight * .58).clamp(240.0, 560.0);
      final buttonStyle = OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10));
      return Scrollbar(
        controller: _pageScroll, thumbVisibility: true,
        child: ListView(controller: _pageScroll,
          padding: EdgeInsets.symmetric(
            horizontal: narrow ? 10 : 20, vertical: narrow ? 10 : 16),
          children: [
            // All controls live in the SAME vertical scroll flow as the report:
            // no fixed header can cover the date filter or transaction table.
            Card(child: Padding(padding: EdgeInsets.all(narrow ? 12 : 17),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Books of Accounts', style: TextStyle(
                        fontSize: 21, fontWeight: FontWeight.w900, color: HyperionColors.brand)),
                      SizedBox(height: 3),
                      Text('Four journals and ledgers · local working papers',
                        style: TextStyle(fontSize: 12, color: HyperionColors.muted)),
                    ])),
                  if (!narrow) Icon(Icons.menu_book_outlined,
                    color: HyperionColors.brand, size: 26),
                ]),
                SizedBox(height: 12),
                Wrap(spacing: 7, runSpacing: 8, children: [
                  for (var i = 0; i < 4; i++)
                    _tabButton(i, [
                      'Journal', 'Ledger', 'Cash Receipt', 'Cash Disbursement'][i]),
                ]),
                SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  FilledButton.icon(
                    onPressed: _exporting ? null : () => _export(report),
                    icon: Icon(Icons.table_view_outlined, size: 17),
                    label: Text('Export to Excel')),
                  OutlinedButton.icon(
                    onPressed: () => _print(report),
                    icon: Icon(Icons.print_outlined, size: 17),
                    label: Text('Print Report')),
                ]),
              ]))),
            SizedBox(height: 10),
            Card(child: Padding(padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('COVERED PERIOD', style: TextStyle(
                  fontSize: 11, letterSpacing: .7,
                  color: HyperionColors.muted, fontWeight: FontWeight.w900)),
                SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center, children: [
                    OutlinedButton.icon(style: buttonStyle,
                      onPressed: () => _pick(true),
                      icon: Icon(Icons.calendar_today_outlined, size: 15),
                      label: Text(_start == null ? 'Start date' : _stamp(_start!))),
                    Text('to', style: TextStyle(color: HyperionColors.muted)),
                    OutlinedButton.icon(style: buttonStyle,
                      onPressed: () => _pick(false),
                      icon: Icon(Icons.calendar_today_outlined, size: 15),
                      label: Text(_end == null ? 'End date' : _stamp(_end!))),
                    TextButton(onPressed: () => setState(() => _all = !_all),
                      child: Text(_all ? 'Use selected period' : 'Show all dates')),
                  ]),
                SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 4, children: [
                  FilterChip(label: Text('Optional columns'),
                    selected: _optional,
                    onSelected: (v) => setState(() => _optional = v)),
                  FilterChip(label: Text('Include voided'),
                    selected: _includeVoided,
                    onSelected: (v) => setState(() => _includeVoided = v)),
                  FilterChip(label: Text('Include unverified'),
                    selected: _includeUnverified,
                    onSelected: (v) => setState(() => _includeUnverified = v)),
                ]),
              ]))),
            SizedBox(height: 10),
            Card(clipBehavior: Clip.antiAlias,
              child: Padding(padding: EdgeInsets.all(narrow ? 10 : 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: Column(children: [
                      Text(widget.workspace.businessName.trim().isEmpty
                        ? 'HYPERION BOOKS'
                        : widget.workspace.businessName.trim(),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: HyperionColors.brand,
                          fontWeight: FontWeight.w900, fontSize: 16)),
                      if (widget.workspace.businessTin.isNotEmpty ||
                          widget.workspace.businessAddress.isNotEmpty)
                        Padding(padding: const EdgeInsets.only(top: 3),
                          child: Text([
                            if (widget.workspace.businessTin.isNotEmpty)
                              'TIN ${widget.workspace.businessTin}',
                            if (widget.workspace.businessAddress.isNotEmpty)
                              widget.workspace.businessAddress,
                          ].join(' · '),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: HyperionColors.muted, fontSize: 11))),
                      SizedBox(height: 9),
                      Text(report.title, style: TextStyle(
                        color: HyperionColors.brand, fontWeight: FontWeight.w900, fontSize: 17)),
                      SizedBox(height: 3),
                      Text('For the period $_period',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: HyperionColors.muted, fontSize: 12)),
                      SizedBox(height: 3),
                      Text('${report.rows.length} visible journal/ledger lines',
                        style: TextStyle(color: HyperionColors.muted, fontSize: 11)),
                    ])),
                    SizedBox(height: 13),
                    if (report.rows.isEmpty)
                      Padding(padding: EdgeInsets.symmetric(vertical: 28),
                        child: Center(child: Text(
                          'No records in this period. Select “Show all dates” or import transactions.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: HyperionColors.muted))))
                    else ...[
                      // Keep the horizontal track visible even when there are
                      // hundreds of rows; the report has its own vertical pane.
                      Row(children: [
                        Icon(Icons.swipe, color: HyperionColors.muted, size: 17),
                        SizedBox(width: 5),
                        Expanded(child: Text(
                          'Drag the bottom scrollbar or use arrows to see every column. '
                          'Select a reference to view the complete transaction.',
                          style: TextStyle(fontSize: 11, color: HyperionColors.muted))),
                        IconButton(tooltip: 'Scroll table left',
                          onPressed: () => _scrollTable(-320),
                          icon: Icon(Icons.chevron_left)),
                        IconButton(tooltip: 'Scroll table right',
                          onPressed: () => _scrollTable(320),
                          icon: Icon(Icons.chevron_right)),
                      ]),
                      SizedBox(height: dataHeight,
                        child: LayoutBuilder(builder: (context, size) =>
                          Scrollbar(
                            controller: _tableHorizontal,
                            thumbVisibility: true,
                            trackVisibility: true,
                            interactive: true,
                            scrollbarOrientation: ScrollbarOrientation.bottom,
                            child: SingleChildScrollView(
                              controller: _tableHorizontal,
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(minWidth: size.maxWidth),
                                child: Scrollbar(
                                  controller: _tableVertical,
                                  thumbVisibility: true,
                                  trackVisibility: true,
                                  interactive: true,
                                  child: SingleChildScrollView(
                                    controller: _tableVertical,
                                    scrollDirection: Axis.vertical,
                                    child: DataTable(
                                      dataRowMinHeight: 46,
                                      dataRowMaxHeight: 96,
                                      headingRowColor: WidgetStateProperty.all(
                                        HyperionColors.elevated),
                                      headingTextStyle: TextStyle(
                                        fontWeight: FontWeight.w900, color: HyperionColors.brand),
                                      columnSpacing: narrow ? 16 : 25,
                                      columns: [
                                        for (final header in report.headers)
                                          DataColumn(label: Text(header)),
                                      ],
                                      rows: [
                                        for (final row in report.rows)
                                          DataRow(cells: [
                                            for (var i = 0; i < row.length; i++)
                                              DataCell(ConstrainedBox(
                                                constraints: BoxConstraints(
                                                  maxWidth: i == 4 ? 380 : 260),
                                                child: i == (_tab == 1 ? 3 : 0) &&
                                                    row[i].isNotEmpty && row[i] != 'TOTAL'
                                                  ? Text(row[i],
                                                      style: TextStyle(
                                                        color: HyperionColors.brand,
                                                        decoration: TextDecoration.underline,
                                                        fontSize: 12))
                                                  : SelectableText(row[i],
                                                      style: TextStyle(fontSize: 12))),
                                                onTap: i == (_tab == 1 ? 3 : 0) &&
                                                    row[i].isNotEmpty && row[i] != 'TOTAL'
                                                  ? () => _manageReference(row[i]) : null),
                                          ]),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )),
                      SizedBox(height: 4),
                      Text('Horizontal and vertical report scrollbars are separate.',
                        style: TextStyle(color: HyperionColors.muted, fontSize: 10)),
                    ],
                  ]))),
            if (books.warnings.isNotEmpty) ...[
              SizedBox(height: 10),
              Card(child: ExpansionTile(
                title: Text('Reconciliation notices (${books.warnings.length})'),
                children: [
                  for (final warning in books.warnings)
                    ListTile(dense: true, title: Text(warning,
                      style: TextStyle(fontSize: 12))),
                ],
              )),
            ],
            SizedBox(height: 8),
            Padding(padding: EdgeInsets.all(8), child: Text(
              'DRAFT WORKING PAPERS ONLY · Not BIR-registered computerized books. '
              'Review and void flags affect reports only. Retain and reconcile '
              'original invoices, PayMongo records and bank statements.',
              style: TextStyle(color: HyperionColors.muted, fontSize: 11))),
            SizedBox(height: 20),
          ]),
      );
    });
  }

  Widget _tabButton(int index, String label) {
    final active = _tab == index;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: active ? HyperionColors.brandFill : HyperionColors.card,
        foregroundColor: active ? HyperionColors.onBrandFill : HyperionColors.brand,
        side: BorderSide(color: active ? HyperionColors.brandFill : HyperionColors.border)),
      onPressed: () => setState(() => _tab = index),
      child: Text(label));
  }
}
