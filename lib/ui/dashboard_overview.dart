import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/book_entry.dart';
import '../models/paymongo_transaction.dart';
import '../models/dashboard_metrics.dart';
import '../models/business_analytics.dart';
import '../theme/hyperion_theme.dart';

final _money = NumberFormat.currency(
  locale: 'en_PH', symbol: '₱', decimalDigits: 2);
String _pesos(int centavos) => _money.format(centavos / 100);
String _compact(int centavos) {
  final value = centavos / 100;
  if (value.abs() >= 1000000) return '₱${(value / 1000000).toStringAsFixed(1)}m';
  if (value.abs() >= 1000) return '₱${(value / 1000).toStringAsFixed(1)}k';
  return _pesos(centavos);
}

/// CPAlly-inspired proportions, but Hyperion-themed and powered entirely by
/// local receipts, imported sales and manual business entries. No sample data.
class DashboardOverview extends StatefulWidget {
  final List<BookEntry> entries;
  final List<PayMongoTransaction> sales;
  final VoidCallback onSales;
  final VoidCallback onExpenses;
  final VoidCallback onBooks;
  final VoidCallback onReports;
  final VoidCallback onAddSale;
  final VoidCallback onAddExpense;
  final VoidCallback onAddPayout;
  final VoidCallback onExport;
  final VoidCallback onBackup;
  const DashboardOverview({
    super.key, required this.entries, required this.sales,
    required this.onSales, required this.onExpenses,
    required this.onBooks, required this.onReports,
    required this.onAddSale, required this.onAddExpense,
    required this.onAddPayout, required this.onExport,
    required this.onBackup,
  });
  @override
  State<DashboardOverview> createState() => _DashboardOverviewState();
}

class _DashboardOverviewState extends State<DashboardOverview> {
  int days = 30;
  int cashDays = 7;
  bool byCategory = true;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final data = DashboardMetrics.calculate(
      entries: widget.entries, transactions: widget.sales,
      days: days, now: now);
    final cash = cashDays == days ? data : DashboardMetrics.calculate(
      entries: widget.entries, transactions: widget.sales,
      now: now, days: cashDays);
    return LayoutBuilder(builder: (context, size) {
      final compact = size.maxWidth < 620;
      final pad = compact ? 13.0 : 22.0;
      return ListView(
        key: const PageStorageKey<String>('hyperion-dashboard'),
        padding: EdgeInsets.fromLTRB(pad, 16, pad, 26),
        children: [
          _header(compact, data),
          const SizedBox(height: 15),
          _kpiRow(data),
          const SizedBox(height: 15),
          LayoutBuilder(builder: (context, row) {
            if (row.maxWidth < 790) {
              return Column(children: [
                _trendPanel(data), const SizedBox(height: 14),
                _breakdownPanel(data),
              ]);
            }
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 7, child: _trendPanel(data)),
              const SizedBox(width: 14),
              Expanded(flex: 4, child: _breakdownPanel(data)),
            ]);
          }),
          const SizedBox(height: 15),
          LayoutBuilder(builder: (context, row) {
            if (row.maxWidth < 870) {
              return Column(children: [
                _recentSales(data), const SizedBox(height: 14),
                _recentExpenses(data), const SizedBox(height: 14),
                _cashPanel(cash),
              ]);
            }
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _recentSales(data)),
              const SizedBox(width: 14),
              Expanded(child: _recentExpenses(data)),
              const SizedBox(width: 14),
              Expanded(child: _cashPanel(cash)),
            ]);
          }),
          const SizedBox(height: 15),
          _quickActions(),
          const SizedBox(height: 12),
          Text('Working figures only · Tracked revenue includes imported paid '
            'sales, manually entered sales and provisional Google Play receipts. '
            'Payout transfers are not additional sales. Known costs include '
            'recorded expenses and processor fees. Figures are not audited '
            'profit or verified taxable sales. All data remains on this device.',
            style: TextStyle(color: HyperionColors.muted,
              fontSize: 11, height: 1.5)),
        ],
      );
    });
  }

  Widget _header(bool compact, DashboardMetrics data) {
    final heading = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Financial overview', style: TextStyle(
        fontSize: compact ? 23 : 26, fontWeight: FontWeight.w900,
        color: HyperionColors.ink, height: 1.12)),
      const SizedBox(height: 5),
      Text('Your business at a glance · ${DateFormat('MMM d, yyyy').format(DateTime.now())}',
        style: TextStyle(fontSize: 12, color: HyperionColors.muted)),
    ]);
    final controls = Wrap(spacing: 7, runSpacing: 7,
      crossAxisAlignment: WrapCrossAlignment.center, children: [
        for (final duration in [7, 30, 90])
          ChoiceChip(
            key: ValueKey('dashboard-days-$duration'),
            label: Text('${duration}D', style: const TextStyle(fontSize: 11)),
            selected: days == duration,
            onSelected: (_) => setState(() => days = duration)),
        FilledButton.icon(
          onPressed: widget.onAddSale,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add sale')),
      ]);
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          heading, const SizedBox(height: 11), controls,
        ]);
    }
    return Row(children: [
      Expanded(child: heading),
      controls,
    ]);
  }

  Widget _card({required Widget child, double? height}) => Container(
    height: height, width: double.infinity, padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(color: HyperionColors.card,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: HyperionColors.border.withValues(alpha: .76))),
    child: child);

  Widget _kpiRow(DashboardMetrics data) =>
      LayoutBuilder(builder: (context, size) {
    final count = size.maxWidth >= 770 ? 4 : 2;
    const gap = 12.0;
    final width = (size.maxWidth - gap * (count - 1)) / count;
    return Wrap(spacing: gap, runSpacing: gap, children: [
      SizedBox(width: width, child: _kpi('Tracked revenue',
        _pesos(data.revenue), 'Paid sales + provisional receipts',
        Icons.trending_up, HyperionColors.accent, widget.onSales)),
      SizedBox(width: width, child: _kpi('Indicative result',
        _pesos(data.indicativeResult), 'Revenue less known costs',
        Icons.account_balance_wallet_outlined,
        data.indicativeResult >= 0
          ? HyperionColors.accent : HyperionColors.danger,
        widget.onReports)),
      SizedBox(width: width, child: _kpi('Known costs',
        _pesos(data.knownCosts), 'Expenses + processing fees',
        Icons.receipt_long_outlined, HyperionColors.danger,
        widget.onExpenses)),
      SizedBox(width: width, child: _kpi('Paid sales',
        NumberFormat.decimalPattern().format(data.salesCount),
        '$days-day transaction count',
        Icons.shopping_bag_outlined, HyperionColors.chartBlue,
        widget.onSales)),
    ]);
  });

  Widget _kpi(String title, String amount, String caption,
      IconData icon, Color accent, VoidCallback onTap) {
    return Material(color: Colors.transparent, child: InkWell(
      key: ValueKey('kpi-${title.toLowerCase().replaceAll(' ', '-')}'),
      borderRadius: BorderRadius.circular(13), onTap: onTap,
      child: _card(height: 123, child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(title,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: HyperionColors.muted, fontSize: 11.5,
              fontWeight: FontWeight.w600))),
          Icon(icon, size: 17, color: accent),
        ]),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: FittedBox(
          alignment: Alignment.centerLeft, fit: BoxFit.scaleDown,
          child: Text(amount, style: TextStyle(color: HyperionColors.ink,
            fontSize: 23, fontWeight: FontWeight.w900)))),
        const Spacer(),
        Text(caption, maxLines: 2, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: HyperionColors.muted, fontSize: 10.5)),
      ])),
    ));
  }

  Widget _panelTitle(String title, {Widget? trailing, String? subtitle}) =>
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 14,
            fontWeight: FontWeight.w900, color: HyperionColors.ink)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle, maxLines: 2,
              style: TextStyle(fontSize: 10.5, color: HyperionColors.muted)),
          ],
        ])),
      ?trailing,
    ]);

  Widget _trendPanel(DashboardMetrics data) {
    final timeline = data.analytics.timeline;
    final hasActivity = timeline.any(
      (day) => day.trackedReceipts > 0 || day.trackedCosts > 0);
    return _card(height: 330, child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _panelTitle('Revenue vs Expenses', subtitle:
          'Real dated receipts against recorded expenses and processor fees'),
        const SizedBox(height: 13),
        Wrap(spacing: 15, runSpacing: 4, children: [
          _legend('Revenue', HyperionColors.accent),
          _legend('Known costs', HyperionColors.danger),
        ]),
        const SizedBox(height: 8),
        Expanded(child: hasActivity
          ? Semantics(label: 'Revenue versus known costs for $days days',
              child: CustomPaint(
                painter: _RevenueChartPainter(
                  timeline,
                  revenueColor: HyperionColors.accent,
                  costsColor: HyperionColors.danger,
                  gridColor: HyperionColors.border,
                )))
          : Center(child: Text('No sales or expenses in this period',
              textAlign: TextAlign.center, style: TextStyle(
                color: HyperionColors.muted, fontSize: 12)))),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(DateFormat('MMM d').format(data.analytics.start)),
          Text('Period: $days days'),
          Text(DateFormat('MMM d').format(data.analytics.end)),
        ].map((x) => DefaultTextStyle(
          style: TextStyle(color: HyperionColors.muted, fontSize: 10),
          child: x)).toList()),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _inlineMetric('Revenue', data.revenue)),
          Expanded(child: _inlineMetric('Known costs', data.knownCosts)),
        ]),
      ],
    ));
  }

  Widget _inlineMetric(String label, int amount) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: HyperionColors.muted, fontSize: 10)),
      const SizedBox(height: 3),
      Text(_pesos(amount), overflow: TextOverflow.ellipsis,
        maxLines: 1, style: TextStyle(fontSize: 12,
          fontWeight: FontWeight.w800, color: HyperionColors.ink)),
    ]);

  Widget _legend(String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min, children: [
      Container(width: 9, height: 9, decoration: BoxDecoration(
        color: color, borderRadius: BorderRadius.circular(20))),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(color: HyperionColors.muted, fontSize: 10.5)),
    ]);

  static const _donutPalette = <Color>[
    Color(0xFF168252), Color(0xFF57B78B), Color(0xFF245986),
    Color(0xFF82A7C6), Color(0xFFAB9567), Color(0xFF9B7398),
  ];

  Widget _breakdownPanel(DashboardMetrics data) {
    final entries = (byCategory
      ? data.salesByCategory : data.salesByMethod).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (sum, item) => sum + item.value);
    final slices = entries.take(5).toList();
    final rest = entries.skip(5).fold<int>(
      0, (sum, entry) => sum + entry.value);
    if (rest > 0) slices.add(MapEntry('Other', rest));
    return _card(height: 330, child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _panelTitle(byCategory ? 'Sales by Category' : 'Sales by Payment Method',
          trailing: PopupMenuButton<bool>(
            key: const ValueKey('dashboard-breakdown-mode'),
            tooltip: 'Choose sales breakdown',
            icon: Icon(Icons.tune_outlined,
              size: 17, color: HyperionColors.muted),
            onSelected: (value) => setState(() => byCategory = value),
            itemBuilder: (_) => const [
              PopupMenuItem(value: true, child: Text('By category')),
              PopupMenuItem(value: false, child: Text('By payment method')),
            ],
          ),
          subtitle: byCategory
            ? 'Manual product descriptions · imported sales unclassified'
            : 'Paid sales by recorded channel'),
        const SizedBox(height: 8),
        if (total <= 0)
          Expanded(child: Center(child: Text('No sales to categorize yet',
            textAlign: TextAlign.center, style: TextStyle(
              color: HyperionColors.muted, fontSize: 12))))
        else ...[
          SizedBox(height: 143, child: Center(child: SizedBox(
            width: 143, height: 143,
            child: Stack(alignment: Alignment.center, children: [
              CustomPaint(size: const Size(143, 143),
                painter: _DonutPainter(
                  values: slices.map((item) => item.value).toList(),
                  colors: _donutPalette,
                  track: HyperionColors.elevated)),
              Padding(padding: const EdgeInsets.all(27),
                child: Column(mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(fit: BoxFit.scaleDown,
                      child: Text(_compact(total), style: TextStyle(
                        color: HyperionColors.ink, fontSize: 18,
                        fontWeight: FontWeight.w900))),
                    Text('PAID SALES', style: TextStyle(
                      color: HyperionColors.muted,
                      fontSize: 9, fontWeight: FontWeight.w700)),
                  ])),
            ]),
          ))),
          const SizedBox(height: 8),
          Expanded(child: ListView.builder(
            itemCount: slices.length,
            itemBuilder: (context, i) {
              final item = slices[i];
              final share = total == 0 ? 0 : item.value * 100 / total;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Container(width: 8, height: 8,
                    decoration: BoxDecoration(color: _donutPalette[i],
                      shape: BoxShape.circle)),
                  const SizedBox(width: 7),
                  Expanded(child: Text(item.key,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10.5,
                      color: HyperionColors.muted))),
                  Text('${share.toStringAsFixed(0)}%  ·  ${_compact(item.value)}',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                      color: HyperionColors.ink)),
                ]),
              );
            },
          )),
        ],
      ],
    ));
  }

  Widget _recentSales(DashboardMetrics data) {
    final rows = data.analytics.recentSales;
    return _card(height: 288, child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _panelTitle('Recent Transactions',
          trailing: TextButton(onPressed: widget.onSales,
            child: const Text('View all'))),
        const SizedBox(height: 5),
        _listHeader('Customer / Reference', 'Amount'),
        Expanded(child: rows.isEmpty
          ? _noRows('No paid sales in this period')
          : ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: math.min(5, rows.length),
              separatorBuilder: (_, _) => Divider(
                height: 1, color: HyperionColors.border),
              itemBuilder: (context, index) {
                final row = rows[index];
                return InkWell(onTap: widget.onSales, child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(row.customer.isNotEmpty ? row.customer
                          : row.description.isNotEmpty ? row.description : row.id,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: HyperionColors.ink)),
                        Text('${DateFormat('MMM d').format(row.occurredAt)} · ${row.id}',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 9.5,
                            color: HyperionColors.muted)),
                      ])),
                    const SizedBox(width: 6),
                    Text(_pesos(row.grossCentavos),
                      style: TextStyle(fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: HyperionColors.accent)),
                  ]),
                ));
              },
            )),
      ],
    ));
  }

  Widget _recentExpenses(DashboardMetrics data) {
    final rows = data.analytics.recentExpenses;
    return _card(height: 288, child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _panelTitle('Recent Expenses',
          trailing: TextButton(onPressed: widget.onExpenses,
            child: const Text('View all'))),
        const SizedBox(height: 5),
        _listHeader('Description / Category', 'Amount'),
        Expanded(child: rows.isEmpty
          ? _noRows('No expenses in this period')
          : ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: math.min(5, rows.length),
              separatorBuilder: (_, _) => Divider(
                height: 1, color: HyperionColors.border),
              itemBuilder: (context, index) {
                final row = rows[index];
                return InkWell(onTap: widget.onExpenses, child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(row.description.isEmpty ? 'Expense' : row.description,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: HyperionColors.ink)),
                        Text('${DateFormat('MMM d').format(row.date)} · ${row.category}',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 9.5,
                            color: HyperionColors.muted)),
                      ])),
                    const SizedBox(width: 6),
                    Text(_pesos(row.amountCentavos), style: TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.w800,
                      color: HyperionColors.danger)),
                  ]),
                ));
              },
            )),
      ],
    ));
  }

  Widget _listHeader(String left, String right) => Padding(
    padding: const EdgeInsets.only(bottom: 6, top: 3),
    child: Row(children: [
      Expanded(child: Text(left, style: TextStyle(
        fontSize: 10, color: HyperionColors.muted,
        fontWeight: FontWeight.w700))),
      Text(right, style: TextStyle(
        fontSize: 10, color: HyperionColors.muted,
        fontWeight: FontWeight.w700)),
    ]),
  );

  Widget _noRows(String message) => Center(child: Text(message,
    textAlign: TextAlign.center, style: TextStyle(
      color: HyperionColors.muted, fontSize: 11.5)));

  Widget _cashPanel(DashboardMetrics data) {
    final hasActivity = data.cashDays.any((item) => item.net != 0);
    final deposits = data.cashDays.fold<int>(
      0, (sum, item) => sum + item.deposits);
    final expenses = data.cashDays.fold<int>(
      0, (sum, item) => sum + item.expenses);
    return _card(height: 288, child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _panelTitle('Cash Flow',
          subtitle: 'Bank payouts + direct receipts − cash expenses',
          trailing: SizedBox(width: 75, child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              key: const ValueKey('dashboard-cash-days'),
              value: cashDays, isDense: true, isExpanded: true,
              style: TextStyle(fontSize: 11, color: HyperionColors.ink),
              items: [7, 30, 90].map((d) => DropdownMenuItem(
                value: d, child: Text('${d}D'))).toList(),
              onChanged: (value) => setState(
                () => cashDays = value ?? 7),
            ),
          )),
        ),
        const SizedBox(height: 8),
        Text(_pesos(data.cashMovement), maxLines: 1,
          overflow: TextOverflow.ellipsis, style: TextStyle(
          fontSize: 19, fontWeight: FontWeight.w900,
          color: data.cashMovement >= 0
            ? HyperionColors.accent : HyperionColors.danger)),
        const SizedBox(height: 7),
        Expanded(child: hasActivity
          ? Semantics(label: 'Net cash movement for $cashDays days',
              child: CustomPaint(painter: _CashFlowPainter(
                data.cashDays,
                positive: HyperionColors.accent,
                negative: HyperionColors.danger,
                gridColor: HyperionColors.border)))
          : _noRows('No recorded cash flow in this period')),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
          Text(DateFormat('MMM d').format(data.analytics.start)),
          Text(DateFormat('MMM d').format(data.analytics.end)),
        ].map((e) => DefaultTextStyle(
          style: TextStyle(color: HyperionColors.muted, fontSize: 10),
          child: e)).toList()),
        const SizedBox(height: 8),
        Divider(height: 1, color: HyperionColors.border),
        const SizedBox(height: 7),
        Text('Cash received ${_compact(deposits)} · Paid ${_compact(expenses)}',
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: HyperionColors.muted, fontSize: 10.5)),
      ],
    ));
  }

  Widget _quickActions() => _card(child: Wrap(
    spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Padding(padding: const EdgeInsets.only(right: 5),
        child: Text('Quick actions', style: TextStyle(
          color: HyperionColors.ink, fontSize: 12.5,
          fontWeight: FontWeight.w900))),
      OutlinedButton.icon(onPressed: widget.onAddSale,
        icon: const Icon(Icons.add, size: 16),
        label: const Text('Add sale')),
      OutlinedButton.icon(onPressed: widget.onAddExpense,
        icon: const Icon(Icons.receipt_outlined, size: 16),
        label: const Text('Add expense')),
      OutlinedButton.icon(onPressed: widget.onAddPayout,
        icon: const Icon(Icons.account_balance_outlined, size: 16),
        label: const Text('Add payout')),
      OutlinedButton.icon(onPressed: widget.onBooks,
        icon: const Icon(Icons.menu_book_outlined, size: 16),
        label: const Text('Books')),
      TextButton.icon(onPressed: widget.onExport,
        icon: const Icon(Icons.file_download_outlined, size: 16),
        label: const Text('Export Excel')),
      TextButton.icon(onPressed: widget.onBackup,
        icon: const Icon(Icons.backup_outlined, size: 16),
        label: const Text('Back up')),
    ],
  ));
}

class _RevenueChartPainter extends CustomPainter {
  final List<DailyBusinessMetric> values;
  final Color revenueColor, costsColor, gridColor;
  const _RevenueChartPainter(this.values, {
    required this.revenueColor, required this.costsColor,
    required this.gridColor,
  });
  @override void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || values.isEmpty) return;
    final maxY = math.max(1, values.fold<int>(0, (best, d) =>
      math.max(best, math.max(d.trackedReceipts, d.trackedCosts))));
    final left = 3.0, top = 8.0, bottom = size.height - 8.0;
    final width = math.max(1.0, size.width - left - 3);
    final height = math.max(1.0, bottom - top);
    final grid = Paint()..color = gridColor.withValues(alpha: .55)
      ..strokeWidth = .65;
    for (var i = 0; i <= 3; i++) {
      final y = top + (height * i / 3);
      canvas.drawLine(Offset(left, y),
        Offset(left + width, y), grid);
    }
    void paintLine(int Function(DailyBusinessMetric) amount, Color color) {
      final path = Path();
      for (var i = 0; i < values.length; i++) {
        final x = left + width * (values.length == 1
          ? .5 : i / (values.length - 1));
        final y = bottom - height * (amount(values[i]) / maxY);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, Paint()
        ..color = color ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round);
    }
    paintLine((d) => d.trackedReceipts, revenueColor);
    paintLine((d) => d.trackedCosts, costsColor);
  }
  @override bool shouldRepaint(covariant _RevenueChartPainter old) =>
    old.values != values || old.revenueColor != revenueColor ||
    old.costsColor != costsColor || old.gridColor != gridColor;
}

class _DonutPainter extends CustomPainter {
  final List<int> values;
  final List<Color> colors;
  final Color track;
  const _DonutPainter({
    required this.values, required this.colors, required this.track,
  });
  @override void paint(Canvas canvas, Size size) {
    final total = values.fold<int>(0, (sum, item) => sum + item);
    if (total <= 0 || size.width <= 0 || size.height <= 0) return;
    final stroke = math.min(size.width, size.height) * .12;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2,
      size.width - stroke, size.height - stroke);
    final bg = Paint()..color = track ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(rect, 0, math.pi * 2, false, bg);
    var angle = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = 2 * math.pi * values[i] / total;
      canvas.drawArc(rect, angle, sweep, false, Paint()
        ..color = colors[i % colors.length] ..strokeWidth = stroke
        ..style = PaintingStyle.stroke);
      angle += sweep;
    }
  }
  @override bool shouldRepaint(covariant _DonutPainter old) =>
      old.values != values || old.track != track;
}

class _CashFlowPainter extends CustomPainter {
  final List<DashboardCashDay> values;
  final Color positive, negative, gridColor;
  const _CashFlowPainter(this.values, {
    required this.positive, required this.negative,
    required this.gridColor,
  });
  @override void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || values.isEmpty) return;
    final maxAbs = math.max(1, values.fold<int>(0, (best, day) =>
      math.max(best, day.net.abs())));
    final middle = size.height / 2;
    final grid = Paint()..color = gridColor ..strokeWidth = .8;
    canvas.drawLine(Offset(0, middle), Offset(size.width, middle), grid);
    final spacing = size.width / values.length;
    final barWidth = (spacing * .58).clamp(2.0, 23.0);
    for (var i = 0; i < values.length; i++) {
      final value = values[i].net;
      if (value == 0) continue;
      final h = (value.abs() / maxAbs) * (middle - 6);
      final x = spacing * (i + .5) - barWidth / 2;
      final y = value > 0 ? middle - h : middle;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, h),
        const Radius.circular(3));
      canvas.drawRRect(rect, Paint()
        ..color = value > 0 ? positive : negative);
    }
  }
  @override bool shouldRepaint(covariant _CashFlowPainter old) =>
    old.values != values || old.positive != positive ||
    old.negative != negative;
}
