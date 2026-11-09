import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/book_entry.dart';
import '../models/paymongo_transaction.dart';
import '../models/reports.dart';
import '../services/export_service.dart';
import '../services/backup_service.dart';
import '../services/paymongo_csv_service.dart';
import '../state/books_controller.dart';
import 'entry_dialog.dart';
import 'paymongo_screen.dart';
import 'hyperion_loading.dart';

final _peso = NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 2);
String php(int centavos) => _peso.format(centavos / 100);
String prettyDate(DateTime date) => DateFormat('MMM d, yyyy').format(date);
const _ink = Color(0xFF112940);
const _green = Color(0xFF16865B);

class BooksHome extends StatefulWidget {
  final BooksController controller;
  const BooksHome({super.key, required this.controller});
  @override
  State<BooksHome> createState() => _BooksHomeState();
}

class _BooksHomeState extends State<BooksHome> {
  int _page = 0;
  String _filter = 'All';
  String _month = 'All time';

  void _navigate(int page) {
    if (_page == page) return;
    setState(() => _page = page);
    HyperionLoading.pageTransition(
      const ['Loading overview', 'Loading entries', 'Loading books', 'Loading PayMongo activity', 'Loading settings'][page],
    );
  }

  Future<void> _edit(BuildContext context, EntryKind kind, {BookEntry? initial}) async {
    final id = widget.controller.userId;
    final value = await showEntryEditor(context, id, kind, initial: initial);
    if (value == null || !context.mounted) return;
    try {
      await HyperionLoading.whileRunning('Saving entry', () => widget.controller.save(value));
    } catch (e) {
      if (context.mounted) _message(context, 'Could not save: $e');
    }
  }

  Future<void> _delete(BuildContext context, BookEntry entry) async {
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete entry?'),
      content: const Text('This removes the entry from this device. Export a new backup afterward.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'))],
    ));
    if (confirmed == true) {
      try {
        await HyperionLoading.whileRunning('Deleting entry', () => widget.controller.remove(entry));
      } catch (error) {
        if (context.mounted) _message(context, 'Could not delete: $error');
      }
    }
  }

  void _message(BuildContext context, String text) => ScaffoldMessenger.of(context)
    .showSnackBar(SnackBar(content: Text(text)));

  Future<void> _export(BuildContext context) async {
    try {
      await HyperionLoading.whileRunning(
        'Exporting Excel books', () => ExportService.export(widget.controller.report,
          paymongo: widget.controller.paymongoTransactions));
      if (context.mounted) _message(context, 'Excel workbook exported.');
    } catch (error) {
      if (context.mounted) _message(context, 'Excel export failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: widget.controller, builder: (context, _) {
      final ctrl = widget.controller;
      if (ctrl.loading) {
        return const Scaffold(body: Center(child: Text('Opening your local books…')));
      }
      if (!ctrl.ready) {
        return Scaffold(body: Center(child: Padding(
          padding: const EdgeInsets.all(25), child: Text(ctrl.status, textAlign: TextAlign.center))));
      }
      final isWide = MediaQuery.sizeOf(context).width >= 850;
      final title = const ['Overview', 'Transactions', 'Books & reports', 'PayMongo activity', 'Settings'][_page];
      final body = switch (_page) {
        0 => _overview(context),
        1 => _transactions(context),
        2 => _books(context),
        3 => PayMongoScreen(
          transactions: ctrl.paymongoTransactions,
          onImport: () => _importPayMongo(context),
          onExport: () => _export(context),
        ),
        _ => _settings(context),
      };
      return Scaffold(
        appBar: AppBar(
          toolbarHeight: 72,
          automaticallyImplyLeading: false,
          titleSpacing: isWide ? 23 : 14,
          title: Row(children: [
            InkWell(
              onTap: () => _navigate(0),
              borderRadius: BorderRadius.circular(12),
              child: Tooltip(
                message: 'Hyperion Books home',
                child: Container(
                  width: 44, height: 44,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(color: const Color(0xFF0B294A),
                    borderRadius: BorderRadius.circular(11)),
                  child: ClipRRect(borderRadius: BorderRadius.circular(8),
                    child: Image.asset('assets/brand/logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.anchor_rounded, color: Color(0xFFF2CB55)))),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('HYPERION BOOKS', style: TextStyle(
                  fontWeight: FontWeight.w900, letterSpacing: .2, fontSize: 16)),
                const SizedBox(height: 2),
                Text(title, style: const TextStyle(
                  color: Color(0xFF64758A), fontSize: 11.5,
                  fontWeight: FontWeight.w500)),
              ],
            )),
            if (isWide) ...[
              const Icon(Icons.circle, color: Color(0xFF16865B), size: 8),
              const SizedBox(width: 7),
              const Text('Local & offline', style: TextStyle(
                color: Color(0xFF64758A), fontSize: 12)),
              const SizedBox(width: 18),
            ],
          ]),
          actions: [
            IconButton(
              tooltip: 'Back up your records',
              onPressed: () => _backup(context),
              icon: const Icon(Icons.backup_outlined)),
            const SizedBox(width: 8),
          ],
        ),
        body: Row(children: [
          if (isWide) NavigationRail(
            selectedIndex: _page, onDestinationSelected: _navigate,
            backgroundColor: Colors.white, labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.space_dashboard_outlined),
                selectedIcon: Icon(Icons.space_dashboard), label: Text('Overview')),
              NavigationRailDestination(icon: Icon(Icons.swap_vert_outlined),
                selectedIcon: Icon(Icons.swap_vert), label: Text('Entries')),
              NavigationRailDestination(icon: Icon(Icons.menu_book_outlined),
                selectedIcon: Icon(Icons.menu_book), label: Text('Books')),
              NavigationRailDestination(icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long), label: Text('PayMongo')),
              NavigationRailDestination(icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings), label: Text('Settings')),
            ],
          ),
          Expanded(child: Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1260),
            child: body,
          ))),
        ]),
        bottomNavigationBar: isWide ? null : NavigationBar(
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          selectedIndex: _page, onDestinationSelected: _navigate,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.swap_vert), label: 'Entries'),
            NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: 'Books'),
            NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'PayMongo'),
            NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
          ]),
        floatingActionButton: _page == 1 ? FloatingActionButton.extended(
          backgroundColor: _green, foregroundColor: Colors.white,
          onPressed: () => _edit(context, EntryKind.payout),
          icon: const Icon(Icons.add), label: const Text('Payout')) : null,
      );
    });
  }

  Future<void> _importPayMongo(BuildContext context) async {
    try {
      final preview = await PayMongoCsvService.select();
      if (preview == null || !context.mounted) return;
      final oldIds = widget.controller.paymongoTransactions.map((t) => t.id).toSet();
      final newRows = preview.transactions.where((t) => !oldIds.contains(t.id)).toList();
      final duplicates = preview.transactions.length - newRows.length;
      final totals = PayMongoTotals.fromTransactions(newRows);
      final proceed = await showDialog<bool>(context: context, builder: (dialog) =>
        AlertDialog(
          title: const Text('Import PayMongo transactions?'),
          content: SingleChildScrollView(child: Text(
            'New successful payments: ${totals.payments}\n'
            'New adjustments/refunds: ${totals.adjustments}\n'
            'Already imported (skipped): $duplicates\n'
            'Unsuccessful / unsupported rows (skipped): ${preview.ignored}\n\n'
            'Gross new payment sales: ${php(totals.grossPaymentsCentavos)}\n'
            'PayMongo fees (including VAT): ${php(totals.paymentFeesCentavos)}\n'
            'VAT portion (already included): ${php(totals.paymentVatCentavos)}\n'
            'Net new payment activity, including adjustments: '
            '${php(totals.activityNetCentavos)}\n\n'
            'Records are sorted by the exact date/time shown in the CSV. '
            'Only transaction IDs, amounts, type, status and method are kept: '
            'customer names/emails are not saved.\n\n'
            'These are customer transactions, NOT bank payouts. '
            'They will NOT be added to the cashflow or journal. '
            'Keep entering actual bank payouts under Entries.',
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancel')),
            FilledButton(onPressed: newRows.isEmpty ? null :
              () => Navigator.pop(dialog, true),
              child: Text('Import ${newRows.length} records')),
          ],
        ));
      if (proceed != true || !context.mounted) return;
      final added = await HyperionLoading.whileRunning(
        'Importing PayMongo transactions', () => widget.controller.importPayMongo(newRows));
      if (context.mounted) {
        _message(context, 'Imported $added PayMongo transactions. Export a JSON backup.');
      }
    } catch (error) {
      if (context.mounted) _message(context, 'PayMongo CSV import failed: $error');
    }
  }

  Future<void> _backup(BuildContext context) async {
    try {
      await HyperionLoading.whileRunning(
        'Exporting backup', () => BackupService.export(widget.controller.entries,
          paymongo: widget.controller.paymongoTransactions));
      if (context.mounted) _message(context, 'JSON backup saved. Keep it somewhere safe.');
    } catch (error) {
      if (context.mounted) _message(context, 'Could not save backup: $error');
    }
  }

  Future<void> _restore(BuildContext context) async {
    try {
      final incoming = await BackupService.selectAndRead();
      if (incoming == null || !context.mounted) return;
      final current = widget.controller.entries;
      final summary = BooksReport.fromEntries(incoming.entries);
      final accepted = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
        title: const Text('Replace all local records?'),
        content: Text('This JSON backup contains ${incoming.entries.length} payout/expense entries '
          'and ${incoming.paymongo.length} imported PayMongo transactions.\n'
          'Payouts: ${php(summary.netPayouts)}\n'
          'Expenses: ${php(summary.totalExpenses)}\n\n'
          'Your ${current.length} current entries and '
          '${widget.controller.paymongoTransactions.length} imported PayMongo transactions '
          'will be REPLACED, not merged. '
          'Export a JSON backup of your current records first. '
          'This will not change other devices.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Replace my local records')),
        ],
      ));
      if (accepted != true || !context.mounted) return;
      await HyperionLoading.whileRunning(
        'Restoring local books', () => widget.controller.restore(incoming.entries,
          paymongo: incoming.paymongo));
      if (context.mounted) {
        _message(context, 'Restored ${incoming.entries.length} entries and '
          '${incoming.paymongo.length} PayMongo transactions from backup.');
      }
    } catch (error) {
      if (context.mounted) _message(context, 'Backup import failed: $error');
    }
  }

  Widget _section(String title, {Widget? trailing}) => Row(children: [
    Expanded(child: Text(title, style: const TextStyle(fontSize: 20,
      fontWeight: FontWeight.w800, color: _ink))),
    ?trailing,
  ]);

  Widget _overview(BuildContext context) {
    final report = widget.controller.report;
    final available = report.months.map((m) => m.month).toList();
    final period = _month == 'All time' || available.contains(_month) ? _month : 'All time';
    final selected = period == 'All time' ? report : BooksReport.fromEntries(
      widget.controller.entries.where((e) => e.dateKey.startsWith(period)));
    final recent = widget.controller.entries.where(
      (e) => period == 'All time' || e.dateKey.startsWith(period)).take(5).toList();
    final paymongo = selected.payouts.where((e) => e.platform == 'PayMongo')
      .fold<int>(0, (sum, e) => sum + e.amountCentavos);
    final play = selected.payouts.where((e) => e.platform == 'Google Play')
      .fold<int>(0, (sum, e) => sum + e.amountCentavos);
    final deductions = selected.payouts.fold<int>(0, (sum, e) => sum + e.deductionCentavos);
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 930;
      final margin = constraints.maxWidth < 520 ? 16.0 : 28.0;
      return ListView(
        key: const PageStorageKey<String>('hyperion-dashboard'),
        padding: EdgeInsets.fromLTRB(margin, 22, margin, 32),
        children: [
          if (wide)
            Row(children: [
              Expanded(child: _dashboardHeading()),
              _periodPicker(period, available),
            ])
          else
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _dashboardHeading(),
              const SizedBox(height: 13),
              _periodPicker(period, available),
            ]),
          const SizedBox(height: 20),
          _welcomeCard(wide),
          const SizedBox(height: 20),
          LayoutBuilder(builder: (context, size) {
            final columns = size.maxWidth >= 790 ? 3 : size.maxWidth >= 490 ? 2 : 1;
            const spacing = 13.0;
            final cardWidth = (size.maxWidth - (columns - 1) * spacing) / columns;
            return Wrap(spacing: spacing, runSpacing: spacing, children: [
              SizedBox(width: cardWidth, child: _statCard('Net payouts', php(selected.netPayouts),
                '${selected.payouts.length} recorded payouts',
                Icons.south_west, _green)),
              SizedBox(width: cardWidth, child: _statCard('Expenses paid', php(selected.totalExpenses),
                '${selected.expenses.length} recorded expenses',
                Icons.north_east, const Color(0xFFB35D55))),
              SizedBox(width: cardWidth, child: _statCard('Net cash movement', php(selected.netCashMovement),
                'Payouts minus expenses',
                Icons.account_balance_wallet_outlined, _ink)),
            ]);
          }),
          const SizedBox(height: 20),
          if (wide)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 7, child: _recentPanel(context, recent)),
              const SizedBox(width: 16),
              Expanded(flex: 4, child: Column(children: [
                _actionsPanel(context),
                const SizedBox(height: 16),
                _sourcesPanel(selected, paymongo, play, deductions),
              ])),
            ])
          else ...[
            _actionsPanel(context),
            const SizedBox(height: 16),
            _recentPanel(context, recent),
            const SizedBox(height: 16),
            _sourcesPanel(selected, paymongo, play, deductions),
          ],
          const SizedBox(height: 18),
          const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline, size: 16, color: Color(0xFF64758A)),
            SizedBox(width: 8),
            Expanded(child: Text(
              'These figures track net payouts by settlement date, not necessarily gross sales. '
              'The generated books are provisional personal records.',
              style: TextStyle(color: Color(0xFF64758A), fontSize: 11.5, height: 1.45))),
          ]),
        ],
      );
    });
  }

  Widget _dashboardHeading() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Financial overview', style: TextStyle(
      color: _ink, fontSize: 25, fontWeight: FontWeight.w900, height: 1.15)),
    const SizedBox(height: 5),
    Text(DateFormat('EEEE, MMM d, yyyy').format(DateTime.now()),
      style: const TextStyle(color: Color(0xFF64758A), fontSize: 13)),
  ]);

  Widget _periodPicker(String period, List<String> available) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(color: Colors.white,
      border: Border.all(color: const Color(0xFFE0E7ED)),
      borderRadius: BorderRadius.circular(12)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.calendar_month_outlined, color: _green, size: 18),
      const SizedBox(width: 9),
      DropdownButtonHideUnderline(child: DropdownButton<String>(
        value: period, isDense: true,
        borderRadius: BorderRadius.circular(12),
        style: const TextStyle(fontSize: 13, color: _ink, fontWeight: FontWeight.w700),
        items: ['All time', ...available]
          .map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
        onChanged: (m) => setState(() => _month = m ?? 'All time'),
      )),
    ]),
  );

  Widget _welcomeCard(bool wide) => Container(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF0B294A), Color(0xFF11506B)],
        begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(20)),
    child: ClipRRect(borderRadius: BorderRadius.circular(20),
      child: Stack(children: [
        Positioned(right: -16, top: -45,
          child: IgnorePointer(child: Icon(Icons.anchor_rounded,
            size: wide ? 230 : 170,
            color: Colors.white.withValues(alpha: .055)))),
        Padding(padding: EdgeInsets.all(wide ? 28 : 22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .11),
                borderRadius: BorderRadius.circular(20)),
              child: const Text('YOUR PERSONAL BOOKKEEPING SPACE',
                style: TextStyle(color: Color(0xFFD0F4E5), fontSize: 10,
                  letterSpacing: 1, fontWeight: FontWeight.w800))),
            const SizedBox(height: 13),
            Text('A clearer picture of your money.',
              style: TextStyle(color: Colors.white,
                fontSize: wide ? 30 : 24, fontWeight: FontWeight.w900, height: 1.12)),
            const SizedBox(height: 8),
            const Text('Record payouts and expenses. Your books update automatically.',
              style: TextStyle(color: Color(0xFFD3E5ED), fontSize: 13)),
            const SizedBox(height: 19),
            Wrap(spacing: 10, runSpacing: 10, children: [
              FilledButton.icon(onPressed: () => _edit(context, EntryKind.payout),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF25A875), foregroundColor: Colors.white),
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Add payout')),
              OutlinedButton.icon(onPressed: () => _edit(context, EntryKind.expense),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF8AAEC0))),
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                label: const Text('Add expense')),
            ]),
            const SizedBox(height: 16),
            const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.offline_bolt_outlined, size: 14, color: Color(0xFFACDFC8)),
              SizedBox(width: 7),
              Flexible(child: Text('Saved on this device · Works offline',
                style: TextStyle(color: Color(0xFFACDFC8), fontSize: 11.5))),
            ]),
          ])),
      ])),
  );

  Widget _statCard(String title, String amount, String detail, IconData icon, Color accent) =>
    _dashboardPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(color: accent.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(11)),
        child: Icon(icon, size: 21, color: accent)),
      const SizedBox(height: 14),
      Text(title, style: const TextStyle(color: Color(0xFF64758A), fontSize: 12.5,
        fontWeight: FontWeight.w600)),
      const SizedBox(height: 5),
      FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
        child: Text(amount, style: const TextStyle(
          color: _ink, fontSize: 25, fontWeight: FontWeight.w900))),
      const SizedBox(height: 8),
      Text(detail, style: const TextStyle(color: Color(0xFF64758A), fontSize: 11.5)),
    ]));

  Widget _recentPanel(BuildContext context, List<BookEntry> entries) =>
    _dashboardPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Expanded(child: Text('Recent activity', style: TextStyle(
          color: _ink, fontWeight: FontWeight.w800, fontSize: 17))),
        TextButton(onPressed: () => _navigate(1), child: const Text('View all')),
      ]),
      if (entries.isEmpty)
        const Padding(padding: EdgeInsets.symmetric(vertical: 28),
          child: Column(children: [
            Icon(Icons.inbox_outlined, color: Color(0xFF8AA0B2), size: 40),
            SizedBox(height: 10),
            Text('Your activity will show up here.',
              style: TextStyle(color: _ink, fontWeight: FontWeight.w800)),
            SizedBox(height: 5),
            Text('Add your first payout or expense to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64758A), fontSize: 12)),
          ]))
      else
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: Color(0xFFE4EBF0)),
          _activityRow(context, entries[i]),
        ],
    ]));

  Widget _activityRow(BuildContext context, BookEntry e) {
    final payout = e.kind == EntryKind.payout;
    final accent = payout ? _green : const Color(0xFFB35D55);
    final name = payout ? e.platform : (e.description.isEmpty ? 'Expense' : e.description);
    return InkWell(onTap: () => _edit(context, e.kind, initial: e),
      borderRadius: BorderRadius.circular(10),
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(children: [
          Container(width: 38, height: 38,
            decoration: BoxDecoration(color: accent.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(11)),
            child: Icon(payout ? Icons.south_west : Icons.north_east, color: accent, size: 18)),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, overflow: TextOverflow.ellipsis, maxLines: 1,
              style: const TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(prettyDate(e.date),
              style: const TextStyle(color: Color(0xFF64758A), fontSize: 11.5)),
          ])),
          const SizedBox(width: 8),
          Flexible(child: Text('${payout ? '+' : '−'}${php(e.amountCentavos)}',
            overflow: TextOverflow.ellipsis, maxLines: 1, textAlign: TextAlign.end,
            style: TextStyle(fontSize: 13, color: accent, fontWeight: FontWeight.w900))),
        ])));
  }

  Widget _actionsPanel(BuildContext context) => _dashboardPanel(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Tools & shortcuts', style: TextStyle(
        color: _ink, fontWeight: FontWeight.w800, fontSize: 17)),
      const SizedBox(height: 8),
      _shortcut(Icons.menu_book_outlined, 'Open your books',
        'Journal, ledger and cash books', () => _navigate(2)),
      const Divider(height: 1, color: Color(0xFFE4EBF0)),
      _shortcut(Icons.file_download_outlined, 'Export Excel',
        'Download your accounting reports', () => _export(context)),
      const Divider(height: 1, color: Color(0xFFE4EBF0)),
      _shortcut(Icons.backup_outlined, 'Back up records',
        'Save a restorable JSON file', () => _backup(context)),
    ]));

  Widget _shortcut(IconData icon, String title, String detail, VoidCallback onTap) =>
    InkWell(onTap: onTap, borderRadius: BorderRadius.circular(10),
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Icon(icon, size: 20, color: _green),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(
              color: _ink, fontSize: 13, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(detail, style: const TextStyle(
              color: Color(0xFF64758A), fontSize: 11.5)),
          ])),
          const Icon(Icons.chevron_right, size: 19, color: Color(0xFF64758A)),
        ])));

  Widget _sourcesPanel(BooksReport report, int paymongo, int play, int deductions) =>
    _dashboardPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Payout sources', style: TextStyle(
        color: _ink, fontWeight: FontWeight.w800, fontSize: 17)),
      const SizedBox(height: 4),
      const Text('Net deposits by payment platform',
        style: TextStyle(color: Color(0xFF64758A), fontSize: 11.5)),
      const SizedBox(height: 18),
      _sourceBar('PayMongo', paymongo, report.netPayouts, _green),
      const SizedBox(height: 16),
      _sourceBar('Google Play', play, report.netPayouts, const Color(0xFF376B9A)),
      const Divider(height: 28, color: Color(0xFFE4EBF0)),
      Row(children: [
        const Expanded(child: Text('Known platform deductions',
          style: TextStyle(color: Color(0xFF64758A), fontSize: 11))),
        Text(php(deductions), style: const TextStyle(
          color: _ink, fontWeight: FontWeight.w800, fontSize: 12)),
      ]),
    ]));

  Widget _sourceBar(String name, int value, int total, Color color) {
    final share = total <= 0 ? 0.0 : (value / total).clamp(0.0, 1.0);
    return Column(children: [
      Row(children: [
        Expanded(child: Text(name,
          style: const TextStyle(color: _ink, fontWeight: FontWeight.w700, fontSize: 12.5))),
        Text(php(value), style: const TextStyle(
          color: _ink, fontWeight: FontWeight.w800, fontSize: 12.5)),
      ]),
      const SizedBox(height: 9),
      ClipRRect(borderRadius: BorderRadius.circular(20),
        child: LinearProgressIndicator(value: share, minHeight: 7,
          backgroundColor: const Color(0xFFEDF2F5), color: color)),
    ]);
  }

  Widget _dashboardPanel({required Widget child}) => Container(
    width: double.infinity, padding: const EdgeInsets.all(19),
    decoration: BoxDecoration(color: Colors.white,
      border: Border.all(color: const Color(0xFFE2E9F0)),
      borderRadius: BorderRadius.circular(18),
      boxShadow: [BoxShadow(
        color: _ink.withValues(alpha: .035),
        blurRadius: 18, offset: const Offset(0, 5))]),
    child: child);

  Widget _transactions(BuildContext context) {
    final entries = widget.controller.entries.where((e) => switch (_filter) {
      'Payouts' => e.kind == EntryKind.payout,
      'Expenses' => e.kind == EntryKind.expense,
      _ => true,
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
    return ListView(padding: const EdgeInsets.fromLTRB(20, 18, 20, 110), children: [
      _section('Your entries'),
      const SizedBox(height: 8),
      const Text('Tap an entry to edit. Changes stay on this device until you export a backup.'),
      const SizedBox(height: 15),
      Wrap(spacing: 8, children: [
        for (final label in ['All', 'Payouts', 'Expenses']) ChoiceChip(
          label: Text(label), selected: _filter == label,
          onSelected: (_) => setState(() => _filter = label)),
        OutlinedButton.icon(onPressed: () => _edit(context, EntryKind.expense),
          icon: const Icon(Icons.add), label: const Text('Expense')),
        OutlinedButton.icon(onPressed: () => _navigate(3),
          icon: const Icon(Icons.receipt_long_outlined), label: const Text('PayMongo CSV')),
      ]),
      const SizedBox(height: 10),
      if (entries.isEmpty) const _EmptyState('No matching entries', 'Use the buttons above to add your first transaction.'),
      ...entries.map((e) => _entryTile(context, e, editable: true)),
    ]);
  }

  Widget _entryTile(BuildContext context, BookEntry e, {bool editable = false}) {
    final payout = e.kind == EntryKind.payout;
    return Card(margin: const EdgeInsets.only(bottom: 9), child: ListTile(
      onTap: () => _edit(context, e.kind, initial: e),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 3),
      leading: CircleAvatar(backgroundColor: payout ? const Color(0xFFE0F5EC) : const Color(0xFFFAE9E6),
        child: Icon(payout ? Icons.south_west : Icons.north_east,
          color: payout ? _green : const Color(0xFFC25751))),
      title: Text(payout ? e.platform : e.description, maxLines: 2, overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text('${prettyDate(e.date)}${payout && e.description.isNotEmpty ? ' · ${e.description}' : ''}'
        '', maxLines: 2),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('${payout ? '+' : '−'}${php(e.amountCentavos)}', style: TextStyle(
          fontWeight: FontWeight.w800, color: payout ? _green : const Color(0xFFC25751))),
        if (editable) PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') {
              _edit(context, e.kind, initial: e);
            } else {
              _delete(context, e);
            }
          },
          itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete'))],
        ),
      ]),
    ));
  }

  Widget _books(BuildContext context) {
    final report = widget.controller.report;
    return DefaultTabController(length: 4, child: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(18, 12, 18, 5), child: Row(children: [
        const Expanded(child: Text('Auto-generated books', style: TextStyle(
          fontWeight: FontWeight.w900, fontSize: 20, color: _ink))),
        FilledButton.icon(onPressed: () => _export(context), icon: const Icon(Icons.download_outlined),
          label: const Text('Excel')),
      ])),
      const Padding(padding: EdgeInsets.symmetric(horizontal: 18),
        child: Align(alignment: Alignment.centerLeft,
          child: Text('View-only. Every line is generated from your payout and expense entries.',
            style: TextStyle(fontSize: 12)))),
      const TabBar(isScrollable: true, tabs: [
        Tab(text: 'Monthly'), Tab(text: 'Cash books'), Tab(text: 'Journal'), Tab(text: 'Ledger'),
      ]),
      Expanded(child: TabBarView(children: [
        _reportTable(context, ['Month','Payouts','Expenses','Cash movement'],
          report.months.map((m) => [m.month,php(m.payoutNet),php(m.expenses),php(m.netCashFlow)]).toList()),
        ListView(padding: const EdgeInsets.all(12), children: [
          const Text('Cash receipts', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          _staticTable(['Date','Platform','Net received'],
            report.payouts.map((e) => [e.dateKey,e.platform,php(e.amountCentavos)]).toList()),
          const SizedBox(height: 18),
          const Text('Cash disbursements', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          _staticTable(['Date','Description','Cash paid'],
            report.expenses.map((e) => [e.dateKey,e.description,php(e.amountCentavos)]).toList()),
        ]),
        _reportTable(context, ['Date','Account','Narration','Debit','Credit'],
          report.journal.map((l) => [BookEntry.dateKeyOf(l.date),l.account,l.narration,
            l.debit == 0 ? '' : php(l.debit),l.credit == 0 ? '' : php(l.credit)]).toList()),
        ListView(padding: const EdgeInsets.all(12), children: [
          for (final account in report.ledger.keys.toList()..sort()) ...[
            Padding(padding: const EdgeInsets.only(top: 12, bottom: 6),
              child: Text(account, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
            _staticTable(['Date','Debit','Credit','Debit−credit balance'],
              report.ledger[account]!.map((l) => [BookEntry.dateKeyOf(l.journal.date),
                php(l.journal.debit),php(l.journal.credit),php(l.debitMinusCreditBalance)]).toList()),
          ],
        ]),
      ])),
    ]));
  }

  Widget _reportTable(BuildContext context, List<String> headers, List<List<String>> rows) =>
    ListView(padding: const EdgeInsets.all(12), children: [_staticTable(headers, rows)]);

  Widget _staticTable(List<String> headers, List<List<String>> rows) => Card(
    child: SingleChildScrollView(scrollDirection: Axis.horizontal,
      child: DataTable(
        headingTextStyle: const TextStyle(fontWeight: FontWeight.w800, color: _ink),
        columns: headers.map((s) => DataColumn(label: Text(s))).toList(),
        rows: (rows.isEmpty ? [List.filled(headers.length, '—')] : rows).map((row) => DataRow(cells:
          row.map((v) => DataCell(ConstrainedBox(constraints: const BoxConstraints(maxWidth: 260),
            child: Text(v, overflow: TextOverflow.ellipsis)))).toList())).toList(),
      ),
    ),
  );

  Widget _settings(BuildContext context) {
    final ctrl = widget.controller;
    return ListView(padding: const EdgeInsets.all(20), children: [
      _section('Your records & backups'),
      const SizedBox(height: 14),
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Private device storage', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('${ctrl.entries.length} cash entries and '
          '${ctrl.paymongoTransactions.length} imported PayMongo transactions in this browser.'),
        Text(ctrl.status),
        const SizedBox(height: 12),
        const Text('To move records between devices, export a JSON backup here, '
          'then import it on the other device. Excel exports are for reading and printing, '
          'and cannot be restored into the app.'),
        const SizedBox(height: 14),
        Wrap(spacing: 10, runSpacing: 10, children: [
          FilledButton.icon(onPressed: () => _backup(context),
            icon: const Icon(Icons.save_alt), label: const Text('Export JSON backup')),
          OutlinedButton.icon(onPressed: () => _restore(context),
            icon: const Icon(Icons.restore_page_outlined), label: const Text('Import JSON backup')),
          OutlinedButton.icon(onPressed: () => _export(context),
            icon: const Icon(Icons.file_download_outlined), label: const Text('Export Excel books')),
          OutlinedButton.icon(onPressed: () => _importPayMongo(context),
            icon: const Icon(Icons.upload_file), label: const Text('Import PayMongo CSV')),
        ]),
      ]))),
      const SizedBox(height: 15),
      Card(child: Padding(padding: const EdgeInsets.all(17), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Important notes', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('• No Google login, Supabase, cloud sync or external financial database.\n'
            '• Records are kept in this browser’s IndexedDB and are not encrypted. Use a trusted, screen-locked device.\n'
            '• Browser cleanup, device loss, or changing the hosting URL can erase local records. Make JSON backups regularly.\n'
            '• Import REPLACES all local records. Export your current backup before importing another one.\n'
            '• Never commit your JSON backup or Excel records to a public GitHub repository.\n'
            '• Payout dates are not necessarily the original sales dates, and net payouts may differ from gross sales.\n'
            '• Journals and ledgers are provisional personal reports, not automatically compliant tax books.'),
        ]))),
    ]);
  }

}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  const _EmptyState(this.title, this.subtitle);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 38), child: Column(children: [
      Icon(Icons.inbox_outlined, size: 48, color: Theme.of(context).colorScheme.outline),
      const SizedBox(height: 8),
      Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      Text(subtitle, textAlign: TextAlign.center),
    ]),
  );
}
