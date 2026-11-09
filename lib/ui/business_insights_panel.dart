import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/hyperion_theme.dart';
import 'package:intl/intl.dart';
import '../models/book_entry.dart';
import '../models/paymongo_transaction.dart';
import '../models/business_analytics.dart';

const navy = HyperionColors.ink;
const green = HyperionColors.accent;
const coral = HyperionColors.danger;
const muted = HyperionColors.muted;
final currency = NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 2);
String pesos(int c) => currency.format(c / 100);

class BusinessInsightsPanel extends StatefulWidget {
  final List<BookEntry> entries;
  final List<PayMongoTransaction> transactions;
  final VoidCallback onSales;
  final VoidCallback onExpenses;
  const BusinessInsightsPanel({super.key, required this.entries,
    required this.transactions, required this.onSales, required this.onExpenses});

  @override
  State<BusinessInsightsPanel> createState() => _BusinessInsightsPanelState();
}

class _BusinessInsightsPanelState extends State<BusinessInsightsPanel> {
  int days = 30;
  @override
  Widget build(BuildContext context) {
    final a = BusinessAnalytics.fromSources(
      entries: widget.entries, paymongo: widget.transactions,
      now: DateTime.now(), days: days);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Business performance', style: TextStyle(
        fontSize: 20, color: navy, fontWeight: FontWeight.w900)),
      SizedBox(height: 4),
      Text('Revenue, expenses and cash flow trends — calculated locally',
        style: TextStyle(color: muted, fontSize: 12)),
      SizedBox(height: 9),
      Wrap(spacing: 8, children: [
        for (final d in [7, 30, 90])
          ChoiceChip(label: Text('Last $d days'), selected: days == d,
            onSelected: (_) => setState(() => days = d)),
      ]),
      SizedBox(height: 13),
      LayoutBuilder(builder: (context, size) {
        final count = size.maxWidth >= 850 ? 4 :
          size.maxWidth >= 490 ? 2 : 1;
        const gap = 12.0;
        final width = (size.maxWidth - (count - 1) * gap) / count;
        return Wrap(spacing: gap, runSpacing: gap, children: [
          SizedBox(width: width, child: _kpi('Tracked receipts',
            pesos(a.trackedReceipts), 'PayMongo gross + provisional Play', green)),
          SizedBox(width: width, child: _kpi('Indicative result',
            pesos(a.indicativeResult), 'Not audited net profit', navy)),
          SizedBox(width: width, child: _kpi('Known costs',
            pesos(a.trackedCosts), 'PayMongo fees + expenses', coral)),
          SizedBox(width: width, child: _kpi('Bank cash movement',
            pesos(a.cashMovement), 'Manual payouts − expenses',
            HyperionColors.chartBlue)),
        ]);
      }),
      SizedBox(height: 13),
      LayoutBuilder(builder: (context, size) {
        if (size.maxWidth < 770) {
          return Column(children: [
            _trend(a), SizedBox(height: 13), _categories(a),
          ]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 7, child: _trend(a)),
          SizedBox(width: 13),
          Expanded(flex: 4, child: _categories(a)),
        ]);
      }),
      SizedBox(height: 13),
      LayoutBuilder(builder: (context, size) {
        if (size.maxWidth < 770) {
          return Column(children: [
            _recentSales(a), SizedBox(height: 13), _recentExpenses(a),
          ]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _recentSales(a)),
          SizedBox(width: 13),
          Expanded(child: _recentExpenses(a)),
        ]);
      }),
      SizedBox(height: 12),
      Text('Tracked receipts are not verified taxable sales. '
        'Google Play amounts are provisional. Bank payouts do not create '
        'additional sales. Imported PayMongo fees include VAT.',
        style: TextStyle(color: muted, fontSize: 11.5, height: 1.45)),
    ]);
  }

  Widget _box(Widget child) => Container(width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white,
      border: Border.all(color: HyperionColors.border),
      borderRadius: BorderRadius.circular(17)),
    child: child);

  Widget _kpi(String label, String amount, String note, Color accent) =>
    _box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 29, height: 4, decoration: BoxDecoration(
        color: accent, borderRadius: BorderRadius.circular(4))),
      SizedBox(height: 12),
      Text(label, style: TextStyle(
        fontSize: 12, color: muted, fontWeight: FontWeight.w700)),
      SizedBox(height: 5),
      FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
        child: Text(amount, style: TextStyle(
          fontSize: 24, color: navy, fontWeight: FontWeight.w900))),
      SizedBox(height: 7),
      Text(note, maxLines: 2, overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, color: muted)),
    ]));

  Widget _trend(BusinessAnalytics a) {
    final maxValue = math.max(1, a.timeline.fold<int>(0, (best, d) =>
      math.max(best, math.max(d.trackedReceipts, d.trackedCosts))));
    return _box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Receipts vs known costs',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: navy)),
      SizedBox(height: 5),
      Text('Daily trend; indicative only',
        style: TextStyle(fontSize: 11, color: muted)),
      SizedBox(height: 14),
      Row(children: [
        _legend(green, 'Receipts'), SizedBox(width: 13),
        _legend(coral, 'Costs'),
      ]),
      SizedBox(height: 14),
      SizedBox(height: 130, child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final d in a.timeline)
            Expanded(child: Row(
              crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(child: _bar(d.trackedReceipts, maxValue, green)),
                SizedBox(width: 1),
                Expanded(child: _bar(d.trackedCosts, maxValue, coral)),
              ])),
        ],
      )),
      SizedBox(height: 6),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(DateFormat('MMM d').format(a.start),
          style: TextStyle(fontSize: 11, color: muted)),
        Text('Peak ${pesos(maxValue)}',
          style: TextStyle(fontSize: 11, color: muted)),
        Text(DateFormat('MMM d').format(a.end),
          style: TextStyle(fontSize: 11, color: muted)),
      ]),
      Divider(height: 23),
      Row(children: [
        Expanded(child: _smallAmount('Bank payouts', a.bankPayouts)),
        Expanded(child: _smallAmount('Cash expenses', a.manualExpenses)),
        Expanded(child: _smallAmount('Net bank', a.cashMovement)),
      ]),
    ]));
  }

  Widget _bar(int value, int maximum, Color color) =>
    Align(alignment: Alignment.bottomCenter,
      child: FractionallySizedBox(
        heightFactor: math.max(.015, (value / maximum).clamp(0.0, 1.0)),
        child: DecoratedBox(decoration: BoxDecoration(
          color: value == 0 ? HyperionColors.elevated : color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(2)))),
      ));

  Widget _legend(Color color, String title) => Row(
    mainAxisSize: MainAxisSize.min, children: [
      Container(width: 9, height: 9, color: color),
      SizedBox(width: 5),
      Text(title, style: TextStyle(fontSize: 11, color: muted)),
    ]);

  Widget _smallAmount(String label, int amount) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 11, color: muted)),
      SizedBox(height: 4),
      FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
        child: Text(pesos(amount), style: TextStyle(
          fontWeight: FontWeight.w800, fontSize: 12, color: navy))),
    ]);

  Widget _categories(BusinessAnalytics a) {
    final items = a.expenseCategories.entries.toList()
      ..sort((x, y) => y.value.compareTo(x.value));
    final largest = items.isEmpty ? 1 : math.max(1, items.first.value);
    return _box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Expense categories', style: TextStyle(
        fontWeight: FontWeight.w800, fontSize: 16, color: navy)),
      SizedBox(height: 5),
      Text('Manually recorded costs',
        style: TextStyle(color: muted, fontSize: 11)),
      SizedBox(height: 16),
      if (items.isEmpty)
        Padding(padding: EdgeInsets.symmetric(vertical: 22),
          child: Text('No expenses in this period.',
            style: TextStyle(fontSize: 12, color: muted)))
      else
        for (final item in items.take(6)) ...[
          Row(children: [
            Expanded(child: Text(item.key, maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
            Text(pesos(item.value),
              style: TextStyle(fontSize: 11, color: muted)),
          ]),
          SizedBox(height: 7),
          ClipRRect(borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: item.value / largest, color: coral,
              backgroundColor: HyperionColors.elevated, minHeight: 7)),
          SizedBox(height: 15),
        ],
      Divider(height: 22),
      Text('Additional processor fees: ${pesos(a.fees)}',
        style: TextStyle(color: muted, fontSize: 11)),
    ]));
  }

  Widget _recentSales(BusinessAnalytics a) => _box(Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text('Recent sales', style: TextStyle(
          fontSize: 15, color: navy, fontWeight: FontWeight.w800))),
        TextButton(onPressed: widget.onSales, child: Text('View all')),
      ]),
      if (a.recentSales.isEmpty)
        Padding(padding: EdgeInsets.symmetric(vertical: 19),
          child: Text('No imported sales in this period.',
            style: TextStyle(fontSize: 12, color: muted))),
      for (final item in a.recentSales) ...[
        Divider(height: 1),
        ListTile(dense: true, contentPadding: EdgeInsets.zero,
          title: Text(item.id, maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12)),
          subtitle: Text(DateFormat('MMM d, h:mm a').format(item.occurredAt)),
          trailing: Text(pesos(item.grossCentavos),
            style: TextStyle(color: green,
              fontWeight: FontWeight.w800, fontSize: 12))),
      ],
    ]));

  Widget _recentExpenses(BusinessAnalytics a) => _box(Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text('Recent expenses', style: TextStyle(
          fontSize: 15, color: navy, fontWeight: FontWeight.w800))),
        TextButton(onPressed: widget.onExpenses, child: Text('View all')),
      ]),
      if (a.recentExpenses.isEmpty)
        Padding(padding: EdgeInsets.symmetric(vertical: 19),
          child: Text('No recorded expenses in this period.',
            style: TextStyle(fontSize: 12, color: muted))),
      for (final e in a.recentExpenses) ...[
        Divider(height: 1),
        ListTile(dense: true, contentPadding: EdgeInsets.zero,
          title: Text(e.description, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12)),
          subtitle: Text('${DateFormat('MMM d').format(e.date)} · ${e.category}'),
          trailing: Text(pesos(e.amountCentavos),
            style: TextStyle(color: coral,
              fontWeight: FontWeight.w800, fontSize: 12))),
      ],
    ]));
}
