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
String _stamp(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

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

  static const _tabNames = ['Journal', 'Ledger', 'Cash receipts', 'Cash disbursements'];

  String _hint() => switch (_tab) {
    0 => 'Debits and credits by account, with original transaction references.',
    1 => 'One account at a time. Dr/Cr shows the balance side; B/F carries '
        'included earlier activity into the selected period.',
    2 => 'Bank / cash is money received. Clearing is still held by the '
        'processor. Transfers are not extra sales; never add these columns as revenue.',
    _ => 'Only recorded payments, not unpaid purchases or draft bills.',
  };

  @override
  Widget build(BuildContext context) {
    final books = AccountingBooks.fromSources(
      widget.entries, widget.transactions);
    final report = _table(books);
    return LayoutBuilder(builder: (context, viewport) {
      final narrow = viewport.maxWidth < 740;
      final spacing = narrow ? 10.0 : 16.0;
      final gridHeight = (viewport.maxHeight * .61).clamp(260.0, 580.0);
      return Scrollbar(
        controller: _pageScroll, thumbVisibility: true,
        child: ListView(
          controller: _pageScroll,
          padding: EdgeInsets.fromLTRB(spacing, 12, spacing, 28),
          children: [
            Card(child: Padding(
              padding: EdgeInsets.all(narrow ? 12 : 15),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (narrow) ...[
                    _header(),
                    const SizedBox(height: 8),
                    _actions(report),
                  ] else
                    Row(children: [
                      Expanded(child: _header()),
                      _actions(report),
                    ]),
                  const SizedBox(height: 10),
                  Wrap(spacing: 7, runSpacing: 7, children: [
                    for (var i = 0; i < _tabNames.length; i++)
                      ChoiceChip(
                        label: Text(_tabNames[i],
                          style: const TextStyle(fontSize: 12)),
                        selected: _tab == i,
                        onSelected: (_) => setState(() => _tab = i),
                      ),
                  ]),
                  Divider(height: 17, color: HyperionColors.border),
                  Text('COVERED PERIOD', style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w900,
                    color: HyperionColors.muted, letterSpacing: .8)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 7, runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _pick(true),
                        icon: const Icon(Icons.event_outlined, size: 15),
                        label: Text(_start == null ? 'From' : _stamp(_start!),
                          style: const TextStyle(fontSize: 12))),
                      Text('to', style: TextStyle(
                        fontSize: 12, color: HyperionColors.muted)),
                      OutlinedButton.icon(
                        onPressed: () => _pick(false),
                        icon: const Icon(Icons.event_outlined, size: 15),
                        label: Text(_end == null ? 'Until' : _stamp(_end!),
                          style: const TextStyle(fontSize: 12))),
                      TextButton(
                        onPressed: () => setState(() => _all = !_all),
                        child: Text(_all ? 'Use selected period' : 'Show all dates')),
                      TextButton.icon(
                        onPressed: () => setState(
                          () => _showReviewFilters = !_showReviewFilters),
                        icon: Icon(_showReviewFilters
                          ? Icons.expand_less : Icons.tune_outlined,
                          size: 16),
                        label: const Text('Review filters')),
                    ],
                  ),
                  if (_showReviewFilters) ...[
                    const SizedBox(height: 7),
                    Wrap(spacing: 8, runSpacing: 5, children: [
                      FilterChip(label: const Text('Include voided'),
                        selected: _includeVoided,
                        onSelected: (v) => setState(() => _includeVoided = v)),
                      FilterChip(label: const Text('Include unverified'),
                        selected: _includeUnverified,
                        onSelected: (v) => setState(
                          () => _includeUnverified = v)),
                    ]),
                  ],
                  if (_tab == 1 && report.ledgerAccounts.isNotEmpty) ...[
                    const SizedBox(height: 11),
                    DropdownButtonFormField<String>(
                      key: ValueKey('ledger-${report.ledgerAccount}'),
                      isExpanded: true,
                      initialValue: report.ledgerAccount,
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'Ledger account (one folio at a time)',
                        prefixIcon: Icon(Icons.account_balance_outlined,
                          size: 18)),
                      items: [
                        for (final name in report.ledgerAccounts)
                          DropdownMenuItem(value: name, child: Text(name,
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (value) => setState(
                        () => _ledgerAccount = value),
                    ),
                  ],
                ],
              ),
            )),
            const SizedBox(height: 10),
            Card(clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: EdgeInsets.all(narrow ? 10 : 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(widget.workspace.businessName.trim().isEmpty
                      ? 'HYPERION BOOKS'
                      : widget.workspace.businessName.trim(),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: HyperionColors.brand,
                        fontSize: 13, fontWeight: FontWeight.w900)),
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
                          style: TextStyle(fontSize: 10.5,
                            color: HyperionColors.muted))),
                    const SizedBox(height: 6),
                    Text(report.title, textAlign: TextAlign.center,
                      style: TextStyle(color: HyperionColors.brand,
                        fontSize: 17, fontWeight: FontWeight.w900)),
                    if (report.ledgerAccount != null)
                      Text(report.ledgerAccount!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: HyperionColors.ink,
                          fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text('For the period $_period  ·  '
                      '${report.rows.length - report.summaryRows.length} rows',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11,
                        color: HyperionColors.muted)),
                    const SizedBox(height: 7),
                    Text(_hint(), textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10.5,
                        color: HyperionColors.muted, height: 1.3)),
                    const SizedBox(height: 10),
                    BooksCompactTable(
                      key: ValueKey('book-$_tab-${report.ledgerAccount}'),
                      report: report, bookIndex: _tab,
                      height: gridHeight,
                      onOpenReference: _manageReference,
                    ),
                    const SizedBox(height: 7),
                    Text('Select a reference to see the full source details '
                      'and review flags. All amounts are PHP.',
                      style: TextStyle(fontSize: 10.5,
                        color: HyperionColors.muted)),
                  ],
                ),
              ),
            ),
            if (books.warnings.isNotEmpty) ...[
              const SizedBox(height: 9),
              Card(child: ExpansionTile(
                title: Text('Reconciliation notices (${books.warnings.length})',
                  style: const TextStyle(fontSize: 12,
                    fontWeight: FontWeight.w700)),
                children: [
                  for (final warning in books.warnings)
                    ListTile(dense: true, title: Text(warning,
                      style: const TextStyle(fontSize: 12))),
                ],
              )),
            ],
            const SizedBox(height: 10),
            Text('DRAFT WORKING PAPERS · Not BIR-registered computerized or '
              'approved loose-leaf books. Retain and reconcile source invoices, '
              'sales files and bank statements. Confirm official formats and '
              'registration requirements with your RDO.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10.5,
                color: HyperionColors.muted)),
          ],
        ),
      );
    });
  }

  Widget _header() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Books of Accounts', style: TextStyle(
        fontSize: 19, fontWeight: FontWeight.w900,
        color: HyperionColors.brand)),
      const SizedBox(height: 2),
      Text('Four books · compact columns · full details on demand',
        style: TextStyle(fontSize: 11, color: HyperionColors.muted)),
    ],
  );

  Widget _actions(BookTableData report) => Wrap(
    spacing: 7, runSpacing: 7, children: [
      FilledButton.icon(
        onPressed: _exporting ? null : () => _export(report),
        icon: const Icon(Icons.file_download_outlined, size: 16),
        label: const Text('Export to Excel')),
      OutlinedButton.icon(
        onPressed: () => _print(report),
        icon: const Icon(Icons.print_outlined, size: 16),
        label: const Text('Print Report')),
    ],
  );
}
