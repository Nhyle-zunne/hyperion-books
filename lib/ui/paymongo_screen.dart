import 'package:flutter/material.dart';
import '../theme/hyperion_theme.dart';
import 'package:intl/intl.dart';
import '../models/paymongo_transaction.dart';

final _peso = NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 2);
String _php(int value) => _peso.format(value / 100);

/// Payment transactions imported from the PayMongo CSV, kept separate from
/// actual cash payouts and expenses to prevent double-counting deposits.
class PayMongoScreen extends StatefulWidget {
  final List<PayMongoTransaction> transactions;
  final VoidCallback onImport;
  final VoidCallback onExport;
  final VoidCallback? onTemplate;
  final VoidCallback? onAddManual;
  final ValueChanged<PayMongoTransaction>? onEditManual;
  final ValueChanged<PayMongoTransaction>? onDeleteManual;
  const PayMongoScreen({
    super.key,
    required this.transactions,
    required this.onImport,
    required this.onExport,
    this.onTemplate,
    this.onAddManual,
    this.onEditManual,
    this.onDeleteManual,
  });

  @override
  State<PayMongoScreen> createState() => _PayMongoScreenState();
}

class _PayMongoScreenState extends State<PayMongoScreen> {
  bool _newestFirst = true;
  String _month = 'All time';
  bool _tableMode = false;
  bool _manualOnly = false;
  int _tablePage = 0;
  final _tableHorizontal = ScrollController();

  @override void dispose() {
    _tableHorizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final months = widget.transactions.map((e) => e.month).toSet().toList()
      ..sort((a,b) => b.compareTo(a));
    final selectedMonth = months.contains(_month) ? _month : 'All time';
    final items = widget.transactions.where((e) =>
      (selectedMonth == 'All time' || e.month == selectedMonth) &&
      (!_manualOnly || e.isManual)).toList()
      ..sort((a, b) {
        final cmp = a.occurredAt.compareTo(b.occurredAt);
        final timeCmp = _newestFirst ? -cmp : cmp;
        return timeCmp != 0 ? timeCmp : a.id.compareTo(b.id);
      });
    final totals = PayMongoTotals.fromTransactions(items);
    return LayoutBuilder(builder: (context, size) => ListView.builder(
      padding: EdgeInsets.fromLTRB(size.maxWidth < 500 ? 16 : 24, 20,
        size.maxWidth < 500 ? 16 : 24, 80),
      itemCount: _tableMode ? 1 : items.length + 1,
      itemBuilder: (context, index) {
        if (index > 0) return _transactionTile(items[index - 1]);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Sales', style: TextStyle(
            fontSize: 23, fontWeight: FontWeight.w900, color: HyperionColors.ink)),
          SizedBox(height: 7),
          Text('Record QR Ph, bank transfer and cash sales manually, or import '
            'CSV/Excel transactions. Direct receipts and imported payments '
            'appear together in totals and draft accounting books.',
            style: TextStyle(color: HyperionColors.muted, fontSize: 13)),
          SizedBox(height: 15),
          Wrap(spacing: 10, runSpacing: 10, children: [
            if (widget.onAddManual != null) FilledButton.icon(
              onPressed: widget.onAddManual, icon: Icon(Icons.add),
              label: Text('Add sale manually')),
            OutlinedButton.icon(
              onPressed: widget.onImport, icon: Icon(Icons.upload_file),
              label: Text('Import Sales CSV / Excel')),
            OutlinedButton.icon(
              onPressed: widget.onExport, icon: Icon(Icons.file_download_outlined),
              label: Text('Export Excel books')),
            if (widget.onTemplate != null) OutlinedButton.icon(
              onPressed: widget.onTemplate,
              icon: Icon(Icons.description_outlined),
              label: Text('Sales CSV template')),
          ]),
          SizedBox(height: 16),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              _valueRow('Paid sales', '${totals.payments}'),
              _valueRow('Gross sales', _php(totals.grossPaymentsCentavos)),
              _valueRow('Processing fees (including VAT)', _php(totals.paymentFeesCentavos)),
              _valueRow('VAT portion of those fees', _php(totals.paymentVatCentavos)),
              Divider(),
              _valueRow('Net sales after fees', _php(totals.netPaymentsCentavos), strong: true),
              _valueRow('Adjustments / refunds', _php(totals.adjustmentsNetCentavos)),
              _valueRow('Net sales and adjustments',
                _php(totals.activityNetCentavos), strong: true),
            ]))),
          SizedBox(height: 12),
          Card(child: Padding(padding: EdgeInsets.all(13),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline, color: HyperionColors.accent, size: 19),
              SizedBox(width: 9),
              Expanded(child: Text('Sales are saved locally on this device. Manual QR/bank/cash payments '
                'are direct receipts and do not require an additional payout entry. '
                'Imported processor collections use settlement clearing until a bank payout '
                'is recorded. Never record the same sale twice.',
                style: TextStyle(fontSize: 12, height: 1.45))),
            ]))),
          SizedBox(height: 17),
          Wrap(spacing: 12, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownButton<String>(
                value: selectedMonth,
                items: ['All time', ...months].map((s) =>
                  DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() { _month = v ?? 'All time'; _tablePage = 0; }),
              ),
              OutlinedButton.icon(
                onPressed: () => setState(() { _newestFirst = !_newestFirst; _tablePage = 0; }),
                icon: Icon(_newestFirst ? Icons.arrow_downward : Icons.arrow_upward, size: 17),
                label: Text(_newestFirst ? 'Newest first' : 'Oldest first')),
              FilterChip(
                label: Text('Manual only'),
                avatar: Icon(Icons.edit_note_outlined, size: 17),
                selected: _manualOnly,
                onSelected: (v) => setState(() { _manualOnly = v; _tablePage = 0; })),
              FilterChip(
                label: Text('Full-width table'),
                avatar: Icon(Icons.table_chart_outlined, size: 17),
                selected: _tableMode,
                onSelected: (v) => setState(() { _tableMode = v; _tablePage = 0; })),
            ]),
          SizedBox(height: 7),
          Text('${items.length} transaction(s) in this view '
            '· ${items.where((t) => t.isManual).length} manually entered',
            style: TextStyle(fontSize: 12, color: HyperionColors.muted)),
          SizedBox(height: 8),
          if (items.isEmpty) Padding(padding: EdgeInsets.symmetric(vertical: 38),
            child: Center(child: Text('No matching sales. Add a sale manually or import a CSV / Excel file.'))),
          if (_tableMode && items.isNotEmpty) _transactionTable(items),
        ]);
      },
    ));
  }

  Widget _valueRow(String name, String value, {bool strong = false}) =>
    Padding(padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Expanded(child: Text(name,
          style: TextStyle(fontSize: 12, color: HyperionColors.muted,
            fontWeight: strong ? FontWeight.w800 : FontWeight.w400))),
        SizedBox(width: 8),
        Text(value, style: TextStyle(fontSize: 13,
          fontWeight: strong ? FontWeight.w900 : FontWeight.w700)),
      ]));


  Future<void> _transactionDetails(PayMongoTransaction txn) async {
    final values = <MapEntry<String,String>>[
      MapEntry('Source', txn.isManual ? 'Manual direct payment' : 'Imported transaction'),
      MapEntry('Transaction ID', txn.id),
      if (txn.isManual && txn.reference.isNotEmpty)
        MapEntry('Payment reference', txn.reference),
      if (txn.isManual) MapEntry('Product / service', txn.description),
      if (txn.isManual && txn.customer.isNotEmpty)
        MapEntry('Customer', txn.customer),
      if (txn.isManual && txn.depositAccount.isNotEmpty)
        MapEntry('Received into', txn.depositAccount),
      if (txn.isManual && txn.notes.isNotEmpty)
        MapEntry('Notes', txn.notes),
      MapEntry(txn.isManual ? 'Payment date/time' : 'Date/time (as exported)',
        DateFormat('yyyy-MM-dd HH:mm:ss').format(txn.occurredAt)),
      MapEntry('Type', txn.type),
      MapEntry('Status', txn.status),
      MapEntry('Payment method', txn.paymentMethod),
      MapEntry('Gross amount', _php(txn.grossCentavos)),
      MapEntry('Processing fee (incl. VAT)', _php(txn.feeCentavos)),
      MapEntry('Fee VAT component', _php(txn.vatCentavos)),
      MapEntry('Net amount', _php(txn.netCentavos)),
    ];
    await showDialog<void>(context: context, builder: (dialog) =>
      AlertDialog(title: Text('Sales transaction details'),
        content: SizedBox(width: 520, child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final value in values)
                Padding(padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(value.key, style: TextStyle(
                      color: HyperionColors.muted, fontSize: 11)),
                    SelectableText(value.value, style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13)),
                  ])),
              Divider(),
              Text(txn.isManual
                ? 'Manual receipt recorded locally; verify against bank/QR evidence. '
                  'A JSON backup may contain optional customer details.'
                : 'The original sales file may contain additional columns. '
                  'Only non-personal accounting fields are stored locally.',
                style: TextStyle(color: HyperionColors.muted, fontSize: 11)),
            ]))),
        actions: [
          if (txn.isManual && widget.onDeleteManual != null)
            TextButton(onPressed: () {
              Navigator.pop(dialog);
              widget.onDeleteManual?.call(txn);
            }, child: Text('Delete')),
          if (txn.isManual && widget.onEditManual != null)
            TextButton(onPressed: () {
              Navigator.pop(dialog);
              widget.onEditManual?.call(txn);
            }, child: Text('Edit')),
          TextButton(onPressed: () => Navigator.pop(dialog), child: Text('Close')),
        ]));
  }

  Widget _transactionTable(List<PayMongoTransaction> items) {
    const pageSize = 40;
    final maxPage = (items.length - 1) ~/ pageSize;
    final page = _tablePage.clamp(0, maxPage);
    final from = page * pageSize;
    final until = (from + pageSize).clamp(0, items.length);
    final visible = items.sublist(from, until);
    final columns = ['Timestamp', 'Transaction ID', 'Type', 'Status',
      'Method', 'Gross', 'Fees (incl VAT)', 'VAT portion', 'Net'];
    return Card(child: Padding(padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text('Drag scrollbar or use arrows to see all columns',
            style: TextStyle(fontSize: 11, color: HyperionColors.muted))),
          IconButton(tooltip: 'Scroll columns left',
            onPressed: () => _moveTable(-380),
            icon: Icon(Icons.chevron_left)),
          IconButton(tooltip: 'Scroll columns right',
            onPressed: () => _moveTable(380),
            icon: Icon(Icons.chevron_right)),
        ]),
        Scrollbar(controller: _tableHorizontal,
          thumbVisibility: true, trackVisibility: true,
          interactive: true, thickness: 12,
          scrollbarOrientation: ScrollbarOrientation.bottom,
          child: SingleChildScrollView(
            controller: _tableHorizontal,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 18),
            child: DataTable(
              horizontalMargin: 12, columnSpacing: 17,
              headingTextStyle: TextStyle(
                fontWeight: FontWeight.w900, color: HyperionColors.ink),
              columns: [for (final label in columns)
                DataColumn(label: Text(label))],
              rows: [
                for (final txn in visible) DataRow(
                  onSelectChanged: (_) => _transactionDetails(txn),
                  cells: [
                    DataCell(Text(DateFormat('yyyy-MM-dd HH:mm').format(txn.occurredAt))),
                    DataCell(ConstrainedBox(constraints: BoxConstraints(maxWidth: 240),
                      child: Text(txn.id, maxLines: 2, overflow: TextOverflow.ellipsis))),
                    DataCell(Text(txn.isManual ? 'Manual sale' : txn.type)),
                    DataCell(Text(txn.status)),
                    DataCell(Text(txn.paymentMethod)),
                    DataCell(Text(_php(txn.grossCentavos))),
                    DataCell(Text(_php(txn.feeCentavos))),
                    DataCell(Text(_php(txn.vatCentavos))),
                    DataCell(Text(_php(txn.netCentavos))),
                  ]),
              ],
            ),
          ),
        ),
        if (items.length > pageSize) Row(children: [
          Expanded(child: Text('Rows ${from + 1}–$until of ${items.length}',
            style: TextStyle(fontSize: 12))),
          IconButton(tooltip: 'Previous page',
            onPressed: page == 0 ? null : () => setState(() => _tablePage = page - 1),
            icon: Icon(Icons.chevron_left)),
          Text('${page + 1} / ${maxPage + 1}'),
          IconButton(tooltip: 'Next page',
            onPressed: page == maxPage ? null : () => setState(() => _tablePage = page + 1),
            icon: Icon(Icons.chevron_right)),
        ]),
      ])));
  }

  void _moveTable(double delta) {
    if (!_tableHorizontal.hasClients) return;
    _tableHorizontal.animateTo((_tableHorizontal.offset + delta)
      .clamp(0.0, _tableHorizontal.position.maxScrollExtent),
      duration: Duration(milliseconds: 220), curve: Curves.easeOut);
  }

  Widget _transactionTile(PayMongoTransaction txn) {
    final payment = txn.isPayment;
    final primary = payment ? HyperionColors.accent : HyperionColors.danger;
    final dateText = DateFormat('MMM d, yyyy  •  h:mm a').format(txn.occurredAt);
    return Card(margin: const EdgeInsets.only(bottom: 8),
      child: Padding(padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(payment ? Icons.payments_outlined : Icons.tune_outlined,
              color: primary, size: 20),
            SizedBox(width: 9),
            Expanded(child: Text(txn.isManual
              ? (txn.description.isEmpty ? 'Manual sale' : txn.description)
              : txn.type, style: TextStyle(
              fontWeight: FontWeight.w800, fontSize: 14))),
            Text(_php(txn.netCentavos), style: TextStyle(
              color: primary, fontWeight: FontWeight.w900, fontSize: 15)),
            if (txn.isManual && widget.onEditManual != null)
              IconButton(tooltip: 'Edit manual sale',
                onPressed: () => widget.onEditManual?.call(txn),
                icon: Icon(Icons.edit_outlined, size: 19)),
            IconButton(tooltip: 'View all saved transaction fields',
              onPressed: () => _transactionDetails(txn),
              icon: Icon(Icons.open_in_full_outlined, size: 19)),
          ]),
          SizedBox(height: 6),
          Text(dateText, style: TextStyle(
            color: HyperionColors.muted, fontSize: 12)),
          SizedBox(height: 6),
          Text('Gross ${_php(txn.grossCentavos)}   •   Fee ${_php(txn.feeCentavos)}'
            '   •   VAT portion ${_php(txn.vatCentavos)}',
            style: TextStyle(color: HyperionColors.muted, fontSize: 11.5)),
          SizedBox(height: 5),
          Text('${txn.isManual ? 'MANUAL' : 'IMPORTED'}   •   '
            '${txn.isManual && txn.reference.isNotEmpty ? txn.reference : txn.id}   •   ${txn.status}'
            '${txn.paymentMethod.isEmpty ? '' : '   •   ${txn.paymentMethod}'}',
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: HyperionColors.muted, fontSize: 10.5)),
        ])));
  }
}
