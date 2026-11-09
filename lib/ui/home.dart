import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/book_entry.dart';
import '../models/accounting_books.dart';
import '../models/paymongo_transaction.dart';
import '../models/reports.dart';
import '../services/export_service.dart';
import '../services/backup_service.dart';
import '../services/paymongo_csv_service.dart';
import '../services/expense_csv_service.dart';
import '../services/paymongo_import_plan.dart';
import '../state/books_controller.dart';
import 'entry_dialog.dart';
import 'paymongo_screen.dart';
import 'business_insights_panel.dart';
import 'business_tools.dart';
import 'accounting_books_page.dart';
import 'record_search.dart';
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
    final value = await showEntryEditor(context, id, kind,
      initial: initial, categories: widget.controller.workspace.expenseCategories);
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
          paymongo: widget.controller.paymongoTransactions,
          workspace: widget.controller.workspace));
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
      final title = const ['Overview', 'Transactions', 'Books & reports', 'PayMongo activity', 'Business tools'][_page];
      final body = switch (_page) {
        0 => _overview(context),
        1 => _transactions(context),
        2 => _books(context),
        3 => PayMongoScreen(
          transactions: ctrl.paymongoTransactions,
          onImport: () => _importPayMongo(context),
          onExport: () => _export(context),
        ),
        _ => BusinessTools(
          workspace: ctrl.workspace,
          save: ctrl.saveWorkspace,
          backupPage: _settings(context),
        ),
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
              tooltip: 'Search local records',
              onPressed: () => _searchRecords(context),
              icon: const Icon(Icons.search_outlined)),
            PopupMenuButton<String>(
              tooltip: 'Quick record',
              icon: const Icon(Icons.add_circle_outline),
              onSelected: (action) {
                if (action == 'payout') {
                  _edit(context, EntryKind.payout);
                } else if (action == 'expense') {
                  _edit(context, EntryKind.expense);
                } else if (action == 'csv') {
                  _importPayMongo(context);
                } else if (action == 'expenseCsv') {
                  _importExpenses(context);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'payout', child: Text('Add bank payout')),
                PopupMenuItem(value: 'expense', child: Text('Add expense')),
                PopupMenuItem(value: 'csv', child: Text('Import PayMongo CSV')),
                PopupMenuItem(value: 'expenseCsv', child: Text('Import expenses CSV')),
              ],
            ),
            IconButton(
              tooltip: 'Back up your records',
              onPressed: () => _backup(context),
              icon: const Icon(Icons.backup_outlined)),
            const SizedBox(width: 5),
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
              NavigationRailDestination(icon: Icon(Icons.business_center_outlined),
                selectedIcon: Icon(Icons.business_center), label: Text('Tools')),
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
            NavigationDestination(icon: Icon(Icons.business_center_outlined), label: 'Tools'),
          ]),
        floatingActionButton: _page == 1 ? FloatingActionButton.extended(
          backgroundColor: _green, foregroundColor: Colors.white,
          onPressed: () => _edit(context, EntryKind.payout),
          icon: const Icon(Icons.add), label: const Text('Payout')) : null,
      );
    });
  }

  Future<void> _searchRecords(BuildContext context) =>
      openRecordSearch(context,
        entries: widget.controller.entries,
        paymongo: widget.controller.paymongoTransactions,
        workspace: widget.controller.workspace,
        onEntries: () => _navigate(1),
        onPayMongo: () => _navigate(3),
        onTools: () => _navigate(4));

  Future<void> _downloadExpenseTemplate(BuildContext context) async {
    try {
      await ExpenseCsvService.downloadTemplate();
      if (context.mounted) _message(context, 'Expense CSV template downloaded.');
    } catch (error) {
      if (context.mounted) _message(context, 'Could not download template: $error');
    }
  }

  Future<void> _importExpenses(BuildContext context) async {
    try {
      final records = await ExpenseCsvService.select();
      if (records == null || !context.mounted) return;
      final oldById = {
        for (final entry in widget.controller.entries) entry.id: entry,
      };
      final novel = records.where((row) => !oldById.containsKey(row.id)).toList();
      final conflicts = records.where((row) {
        final old = oldById[row.id];
        return old != null && (
          old.amountCentavos != row.amountCentavos ||
          old.dateKey != row.dateKey ||
          old.description != row.description ||
          old.category != row.category);
      }).length;
      final amount = novel.fold<int>(0, (s, r) => s + r.amountCentavos);
      final skipped = records.length - novel.length;
      final accept = await showDialog<bool>(context: context, builder: (dialog) =>
        AlertDialog(
          title: const Text('Import expense CSV?'),
          content: Text(
            'New expenses: ${novel.length}\n'
            'Previously imported (skipped): $skipped\n'
            'Same IDs with changed details (preserved): $conflicts\n'
            'Total new expenses: ${php(amount)}\n\n'
            'The Reference field is required to avoid duplicates. '
            'Imported entries appear in your Expenses and accounting books. '
            'Existing records are never overwritten.\n\n'
            'Customer/vendor information is not sent to any server.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancel')),
            if (novel.isNotEmpty)
              FilledButton(onPressed: () => Navigator.pop(dialog, true),
                child: Text('Import ${novel.length} expenses')),
          ]));
      if (accept != true || !context.mounted) return;
      final count = await HyperionLoading.whileRunning(
        'Importing expense CSV', () => widget.controller.importExpenses(novel));
      if (context.mounted) {
        _message(context,
          'Imported $count expenses; skipped ${skipped + novel.length - count} existing.');
      }
    } catch (error) {
      if (context.mounted) {
        _message(context, 'Expense CSV import failed: $error');
      }
    }
  }

  Future<void> _importPayMongo(BuildContext context) async {
    try {
      final preview = await PayMongoCsvService.select();
      if (preview == null || !context.mounted) return;
      final plan = PayMongoImportPlan.prepare(
        incoming: preview.transactions,
        existing: widget.controller.paymongoTransactions,
      );
      final newRows = plan.newTransactions;
      final duplicates = plan.alreadyImported;
      final totals = PayMongoTotals.fromTransactions(newRows);
      final duplicateNotice = newRows.isEmpty
          ? 'All successful transactions in this CSV were already imported. '
            'No records will be changed.\n\n'
          : '';
      final changedNotice = plan.conflictingExisting == 0
          ? ''
          : '${plan.conflictingExisting} existing transaction ID(s) have different '
            'details in this export. Their previously saved values will NOT '
            'be overwritten.\n\n';
      final proceed = await showDialog<bool>(context: context, builder: (dialog) =>
        AlertDialog(
          title: const Text('Import PayMongo transactions?'),
          content: SingleChildScrollView(child: Text(
            'New successful payments: ${totals.payments}\n'
            'New adjustments/refunds: ${totals.adjustments}\n'
            'Already imported (skipped): $duplicates\n'
            'Unsuccessful / unsupported rows (skipped): ${preview.ignored}\n\n'
            '$duplicateNotice'
            '$changedNotice'
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
            if (newRows.isNotEmpty)
              FilledButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: Text('Import ${newRows.length} new records')),
          ],
        ));
      if (proceed != true || !context.mounted) return;
      final added = await HyperionLoading.whileRunning(
        'Importing PayMongo transactions', () => widget.controller.importPayMongo(newRows));
      if (context.mounted) {
        final skipped = duplicates + (newRows.length - added);
        _message(context, 'Imported $added new PayMongo transactions; '
          'skipped $skipped already imported. Export a JSON backup.');
      }
    } catch (error) {
      if (context.mounted) _message(context, 'PayMongo CSV import failed: $error');
    }
  }

  Future<void> _backup(BuildContext context) async {
    try {
      await HyperionLoading.whileRunning(
        'Exporting backup', () => BackupService.export(widget.controller.entries,
          paymongo: widget.controller.paymongoTransactions,
          workspace: widget.controller.workspace));
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
          'Your ${current.length} current entries, business lists, reminders and '
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
          paymongo: incoming.paymongo, workspace: incoming.workspace));
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
    final importedAll = widget.controller.paymongoTransactions;
    final available = <String>{...report.months.map((m) => m.month),
      ...importedAll.map((t) => t.month)}.toList()..sort((a, b) => b.compareTo(a));
    final period = _month == 'All time' || available.contains(_month) ? _month : 'All time';
    final selected = period == 'All time' ? report : BooksReport.fromEntries(
      widget.controller.entries.where((e) => e.dateKey.startsWith(period)));
    final importedInPeriod = importedAll.where(
      (t) => period == 'All time' || t.month == period).toList();
    final importedTotals = PayMongoTotals.fromTransactions(importedInPeriod);
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
          _importedPanel(context, importedTotals, importedInPeriod.length),
          const SizedBox(height: 20),
          BusinessInsightsPanel(
            entries: widget.controller.entries,
            transactions: widget.controller.paymongoTransactions,
            onSales: () => _navigate(3),
            onExpenses: () => _navigate(1),
          ),
          const SizedBox(height: 20),
          const Text('Bank and cash movements', style: TextStyle(
            color: _ink, fontWeight: FontWeight.w800, fontSize: 17)),
          const SizedBox(height: 6),
          const Text('These totals come from manually entered bank payouts and expenses, '
            'not from imported customer payments.', style: TextStyle(
              fontSize: 12, color: Color(0xFF64758A))),
          const SizedBox(height: 13),
          LayoutBuilder(builder: (context, size) {
            final columns = size.maxWidth >= 790 ? 3 : size.maxWidth >= 490 ? 2 : 1;
            const spacing = 13.0;
            final cardWidth = (size.maxWidth - (columns - 1) * spacing) / columns;
            return Wrap(spacing: spacing, runSpacing: spacing, children: [
              SizedBox(width: cardWidth, child: _statCard('Bank payouts', php(selected.netPayouts),
                '${selected.payouts.length} recorded payouts',
                Icons.south_west, _green)),
              SizedBox(width: cardWidth, child: _statCard('Expenses paid', php(selected.totalExpenses),
                '${selected.expenses.length} recorded expenses',
                Icons.north_east, const Color(0xFFB35D55))),
              SizedBox(width: cardWidth, child: _statCard('Net cash movement', php(selected.netCashMovement),
                'Manual bank payouts minus expenses',
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

  Widget _importedPanel(BuildContext context, PayMongoTotals totals, int rows) =>
    _dashboardPanel(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: const Color(0xFFE0F5EC),
              borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.receipt_long_outlined, color: _green)),
          const SizedBox(width: 11),
          const Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Imported PayMongo activity', style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w800, color: _ink)),
              SizedBox(height: 3),
              Text('Customer collections, fees and adjustments — not bank deposits',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF64758A))),
            ],
          )),
        ]),
        const SizedBox(height: 15),
        if (rows == 0) ...[
          const Text('No PayMongo transactions in this period. Import a CSV to see sales activity.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF64758A))),
          const SizedBox(height: 9),
        ] else ...[
          LayoutBuilder(builder: (context, constraints) {
            final columns = constraints.maxWidth > 840 ? 4 :
              constraints.maxWidth > 470 ? 2 : 1;
            const gap = 12.0;
            final width = (constraints.maxWidth - (columns - 1) * gap) / columns;
            return Wrap(spacing: gap, runSpacing: gap, children: [
              SizedBox(width: width, child: _activityKpi(
                'Gross customer payments', php(totals.grossPaymentsCentavos),
                '${totals.payments} paid transactions')),
              SizedBox(width: width, child: _activityKpi(
                'Processing fees (incl. VAT)', php(totals.paymentFeesCentavos),
                'VAT portion: ${php(totals.paymentVatCentavos)}')),
              SizedBox(width: width, child: _activityKpi(
                'Net customer payments', php(totals.netPaymentsCentavos),
                'Held/settled via PayMongo')),
              SizedBox(width: width, child: _activityKpi(
                'Adjustments / refunds', php(totals.adjustmentsNetCentavos),
                '${totals.adjustments} review items')),
            ]);
          }),
          const SizedBox(height: 11),
        ],
        Wrap(spacing: 10, runSpacing: 8, children: [
          TextButton.icon(onPressed: () => _navigate(3),
            icon: const Icon(Icons.visibility_outlined, size: 18),
            label: Text(rows == 0 ? 'View PayMongo activity' :
              'View $rows transactions')),
          OutlinedButton.icon(onPressed: () => _importPayMongo(context),
            icon: const Icon(Icons.upload_file_outlined, size: 17),
            label: const Text('Import CSV')),
        ]),
      ],
    ));

  Widget _activityKpi(String label, String value, String note) =>
    Container(
      width: double.infinity, padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: const Color(0xFFF6F9FB),
        border: Border.all(color: const Color(0xFFE5EBF1)),
        borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11.5,
          color: Color(0xFF60748A), fontWeight: FontWeight.w700)),
        const SizedBox(height: 7),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
          child: Text(value, style: const TextStyle(
            fontSize: 22, fontWeight: FontWeight.w900, color: _ink))),
        const SizedBox(height: 5),
        Text(note, style: const TextStyle(fontSize: 11,
          color: Color(0xFF60748A))),
      ]),
    );

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
        OutlinedButton.icon(onPressed: () => _importExpenses(context),
          icon: const Icon(Icons.upload_file_outlined), label: const Text('Import expenses CSV')),
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

  Widget _books(BuildContext context) => AccountingBooksPage(
    entries: widget.controller.entries,
    transactions: widget.controller.paymongoTransactions,
    workspace: widget.controller.workspace,
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
        Text('${ctrl.workspace.masters.length} master-list items, '
          '${ctrl.workspace.reminders.length} reminders, '
          '${ctrl.entries.length} cash entries and '
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
          OutlinedButton.icon(onPressed: () => _importExpenses(context),
            icon: const Icon(Icons.upload_file_outlined), label: const Text('Import expenses CSV')),
          OutlinedButton.icon(onPressed: () => _downloadExpenseTemplate(context),
            icon: const Icon(Icons.description_outlined), label: const Text('Expense CSV template')),
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
