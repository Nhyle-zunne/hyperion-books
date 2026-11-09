import 'package:flutter/material.dart';
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
  const PayMongoScreen({
    super.key,
    required this.transactions,
    required this.onImport,
    required this.onExport,
  });

  @override
  State<PayMongoScreen> createState() => _PayMongoScreenState();
}

class _PayMongoScreenState extends State<PayMongoScreen> {
  bool _newestFirst = true;
  String _month = 'All time';

  @override
  Widget build(BuildContext context) {
    final months = widget.transactions.map((e) => e.month).toSet().toList()
      ..sort((a,b) => b.compareTo(a));
    final selectedMonth = months.contains(_month) ? _month : 'All time';
    final items = widget.transactions.where((e) =>
      selectedMonth == 'All time' || e.month == selectedMonth).toList()
      ..sort((a, b) {
        final cmp = a.occurredAt.compareTo(b.occurredAt);
        final timeCmp = _newestFirst ? -cmp : cmp;
        return timeCmp != 0 ? timeCmp : a.id.compareTo(b.id);
      });
    final totals = PayMongoTotals.fromTransactions(items);
    return LayoutBuilder(builder: (context, size) => ListView.builder(
      padding: EdgeInsets.fromLTRB(size.maxWidth < 500 ? 16 : 24, 20,
        size.maxWidth < 500 ? 16 : 24, 80),
      itemCount: items.length + 1,
      itemBuilder: (context, index) {
        if (index > 0) return _transactionTile(items[index - 1]);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('PayMongo transactions', style: TextStyle(
            fontSize: 23, fontWeight: FontWeight.w900, color: Color(0xFF112940))),
          const SizedBox(height: 7),
          const Text('Import successful customer payments and adjustments from '
            'a PayMongo Transactions CSV. These are NOT bank payouts.',
            style: TextStyle(color: Color(0xFF64758A), fontSize: 13)),
          const SizedBox(height: 15),
          Wrap(spacing: 10, runSpacing: 10, children: [
            FilledButton.icon(
              onPressed: widget.onImport, icon: const Icon(Icons.upload_file),
              label: const Text('Import PayMongo CSV')),
            OutlinedButton.icon(
              onPressed: widget.onExport, icon: const Icon(Icons.file_download_outlined),
              label: const Text('Export Excel books')),
          ]),
          const SizedBox(height: 16),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              _valueRow('Paid payments', '${totals.payments}'),
              _valueRow('Gross payment sales', _php(totals.grossPaymentsCentavos)),
              _valueRow('Total PayMongo fees (includes VAT)', _php(totals.paymentFeesCentavos)),
              _valueRow('VAT portion of those fees', _php(totals.paymentVatCentavos)),
              const Divider(),
              _valueRow('Net payments', _php(totals.netPaymentsCentavos), strong: true),
              _valueRow('Adjustments / refunds', _php(totals.adjustmentsNetCentavos)),
              _valueRow('Net activity including adjustments',
                _php(totals.activityNetCentavos), strong: true),
            ]))),
          const SizedBox(height: 12),
          const Card(child: Padding(padding: EdgeInsets.all(13),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline, color: Color(0xFF16865B), size: 19),
              SizedBox(width: 9),
              Expanded(child: Text('PayMongo transactions are stored on this device '
                'for reference and Excel export. They do NOT add to cash payouts, '
                'cashflow or the existing journal. Enter each actual PayMongo '
                'bank transfer once under Entries → Add payout. '
                'Transaction dates/times are shown as exported, without timezone conversion.',
                style: TextStyle(fontSize: 12, height: 1.45))),
            ]))),
          const SizedBox(height: 17),
          Wrap(spacing: 12, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownButton<String>(
                value: selectedMonth,
                items: ['All time', ...months].map((s) =>
                  DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => _month = v ?? 'All time'),
              ),
              OutlinedButton.icon(
                onPressed: () => setState(() => _newestFirst = !_newestFirst),
                icon: Icon(_newestFirst ? Icons.arrow_downward : Icons.arrow_upward, size: 17),
                label: Text(_newestFirst ? 'Newest first' : 'Oldest first')),
            ]),
          const SizedBox(height: 7),
          Text('${items.length} imported transaction(s) in this view',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64758A))),
          const SizedBox(height: 8),
          if (items.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 38),
            child: Center(child: Text('No PayMongo transactions imported yet.'))),
        ]);
      },
    ));
  }

  Widget _valueRow(String name, String value, {bool strong = false}) =>
    Padding(padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Expanded(child: Text(name,
          style: TextStyle(fontSize: 12, color: const Color(0xFF506579),
            fontWeight: strong ? FontWeight.w800 : FontWeight.w400))),
        const SizedBox(width: 8),
        Text(value, style: TextStyle(fontSize: 13,
          fontWeight: strong ? FontWeight.w900 : FontWeight.w700)),
      ]));

  Widget _transactionTile(PayMongoTransaction txn) {
    final payment = txn.isPayment;
    final primary = payment ? const Color(0xFF16865B) : const Color(0xFFAD6651);
    final dateText = DateFormat('MMM d, yyyy  •  h:mm a').format(txn.occurredAt);
    return Card(margin: const EdgeInsets.only(bottom: 8),
      child: Padding(padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(payment ? Icons.payments_outlined : Icons.tune_outlined,
              color: primary, size: 20),
            const SizedBox(width: 9),
            Expanded(child: Text(txn.type, style: const TextStyle(
              fontWeight: FontWeight.w800, fontSize: 14))),
            Text(_php(txn.netCentavos), style: TextStyle(
              color: primary, fontWeight: FontWeight.w900, fontSize: 15)),
          ]),
          const SizedBox(height: 6),
          Text(dateText, style: const TextStyle(
            color: Color(0xFF516579), fontSize: 12)),
          const SizedBox(height: 6),
          Text('Gross ${_php(txn.grossCentavos)}   •   Fee ${_php(txn.feeCentavos)}'
            '   •   VAT portion ${_php(txn.vatCentavos)}',
            style: const TextStyle(color: Color(0xFF64758A), fontSize: 11.5)),
          const SizedBox(height: 5),
          Text('ID: ${txn.id}   •   ${txn.status}'
            '${txn.paymentMethod.isEmpty ? '' : '   •   ${txn.paymentMethod}'}',
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF7C8B9B), fontSize: 10.5)),
        ])));
  }
}
