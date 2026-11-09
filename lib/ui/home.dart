import 'package:flutter/material.dart';
import '../theme/hyperion_theme.dart';
import 'package:intl/intl.dart';
import '../models/book_entry.dart';
import '../models/paymongo_transaction.dart';
import '../models/reports.dart';
import '../services/export_service.dart';
import '../services/backup_service.dart';
import '../services/sales_import_service.dart';
import '../services/expense_csv_service.dart';
import '../services/paymongo_import_plan.dart';
import '../state/books_controller.dart';
import 'entry_dialog.dart';
import 'paymongo_screen.dart';
import 'business_insights_panel.dart';
import 'business_tools.dart';
import 'accounting_books_page.dart';
import 'hyperion_sidebar.dart';
import 'operation_records_page.dart';
import 'business_reports_page.dart';
import 'tax_filing_page.dart';
import 'record_search.dart';
import 'hyperion_loading.dart';

final _peso = NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 2);
String php(int centavos) => _peso.format(centavos / 100);
String prettyDate(DateTime date) => DateFormat('MMM d, yyyy').format(date);

class BooksHome extends StatefulWidget {
  final BooksController controller;
  const BooksHome({super.key, required this.controller});
  @override
  State<BooksHome> createState() => _BooksHomeState();
}

class _BooksHomeState extends State<BooksHome> {
  int _page = 0;
  String _route = 'dashboard';
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _filter = 'All';
  String _month = 'All time';

  void _navigate(int page) {
    final target = switch (page) {
      0 => 'dashboard',
      1 => 'entries',
      2 => 'books',
      3 => 'sales',
      4 => 'my-business',
      5 => 'tax-calendar',
      _ => 'dashboard',
    };
    _openRoute(target);
  }

  void _openRoute(String route) {
    final page = switch (route) {
      'dashboard' => 0,
      'entries' || 'daily-expenses' => 1,
      'books' || 'tax-books' || 'journal' || 'ledger' => 2,
      'sales' => 3,
      'my-business' || 'product-to-sell' || 'master-customers' ||
      'master-vendors' || 'master-products' || 'master-categories' ||
      'backups' => 4,
      'tax-calendar' || 'tax-monthly' || 'tax-quarterly' ||
      'tax-annual' || 'tax-2307' || 'tax-invoices' => 5,
      _ => 6,
    };
    if (_route == route) return;
    setState(() {
      _route = route;
      _page = page;
      if (route == 'daily-expenses') _filter = 'Expenses';
      if (route == 'entries') _filter = 'All';
    });
    HyperionLoading.pageTransition('Opening business workspace');
  }

  String get _routeTitle => const <String,String>{
    'dashboard': 'Dashboard',
    'entries': 'Transactions',
    'books': 'Books of Accounts',
    'my-business': 'My Business',
    'backups': 'Backups & Exports',
    'compliance': 'Compliance',
    'sales': 'Sales',
    'product-to-sell': 'Product to Sell',
    'purchase-records': 'Purchase Records',
    'business-assets': 'Business Assets',
    'daily-expenses': 'Daily Expenses',
    'payroll': 'Payroll',
    'tax-calendar': 'Tax Calendar',
    'tax-monthly': 'Monthly Tax',
    'tax-quarterly': 'Quarterly Tax',
    'tax-annual': 'Annual Tax',
    'tax-2307': '2307 Certificates',
    'tax-invoices': 'e-Invoicing',
    'tax-books': 'Books of Accounts',
    'journal': 'Journal Entries',
    'ledger': 'General Ledger',
    'financial-reports': 'Financial Reports',
    'management-reports': 'Management Reports',
    'aging-reports': 'Aging Reports',
    'master-customers': 'Customers',
    'master-vendors': 'Vendors',
    'master-products': 'Products',
    'master-categories': 'Expense Categories',
    'bulk-import': 'Bulk Import',
  }[_route] ?? 'Business Workspace';

  int get _taxSection => switch (_route) {
    'tax-monthly' => 1,
    'tax-quarterly' => 2,
    'tax-annual' => 3,
    'tax-2307' => 4,
    'tax-invoices' => 5,
    _ => 0,
  };

  int get _businessTab => switch (_route) {
    'product-to-sell' || 'master-customers' || 'master-vendors' ||
    'master-products' || 'master-categories' => 1,
    _ => 0,
  };

  String get _masterKind => switch (_route) {
    'product-to-sell' || 'master-products' => 'Product',
    'master-vendors' => 'Vendor',
    'master-categories' => 'Expense category',
    _ => 'Customer',
  };

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
      title: Text('Delete entry?'),
      content: Text('This removes the entry from this device. Export a new backup afterward.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Delete'))],
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
        return Scaffold(body: Center(child: Text('Opening your local books…')));
      }
      if (!ctrl.ready) {
        return Scaffold(body: Center(child: Padding(
          padding: const EdgeInsets.all(25), child: Text(ctrl.status, textAlign: TextAlign.center))));
      }
      final isWide = MediaQuery.sizeOf(context).width >= 850;
      final title = _routeTitle;
      final body = switch (_route) {
        'dashboard' => _overview(context),
        'entries' || 'daily-expenses' => _transactions(context),
        'books' || 'tax-books' || 'journal' || 'ledger' =>
          AccountingBooksPage(
            key: ValueKey(_route),
            entries: ctrl.entries,
            transactions: ctrl.paymongoTransactions,
            workspace: ctrl.workspace, save: ctrl.saveWorkspace,
            initialTab: _route == 'ledger' ? 1 : 0),
        'sales' => PayMongoScreen(
          key: ValueKey(_route),
          transactions: ctrl.paymongoTransactions,
          onImport: () => _importSales(context),
          onExport: () => _export(context),
          onTemplate: () => _downloadSalesTemplate(context),
        ),
        'compliance' => CompliancePage(
          workspace: ctrl.workspace,
          entries: ctrl.entries,
          transactions: ctrl.paymongoTransactions,
          navigate: _openRoute),
        'purchase-records' || 'business-assets' || 'payroll' =>
          OperationRecordsPage(
            key: ValueKey(_route),
            kind: _route == 'business-assets' ? 'Asset' :
              _route == 'payroll' ? 'Payroll' : 'Purchase',
            workspace: ctrl.workspace, save: ctrl.saveWorkspace,
            recordExpense: () => _edit(context, EntryKind.expense)),
        'financial-reports' || 'management-reports' || 'aging-reports' =>
          BusinessReportsPage(
            mode: _route == 'financial-reports' ? 'financial' :
              _route == 'aging-reports' ? 'aging' : 'management',
            workspace: ctrl.workspace,
            entries: ctrl.entries,
            transactions: ctrl.paymongoTransactions,
            navigate: _openRoute),
        'tax-calendar' || 'tax-monthly' || 'tax-quarterly' ||
        'tax-annual' || 'tax-2307' || 'tax-invoices' =>
          TaxFilingPage(
            key: ValueKey(_route),
            initialSection: _taxSection,
            entries: ctrl.entries,
            transactions: ctrl.paymongoTransactions,
            workspace: ctrl.workspace,
            save: ctrl.saveWorkspace,
          ),
        'my-business' || 'product-to-sell' || 'master-customers' ||
        'master-vendors' || 'master-products' || 'master-categories' =>
          BusinessTools(
            key: ValueKey(_route), initialTab: _businessTab,
            initialKind: _masterKind,
            workspace: ctrl.workspace,
            save: ctrl.saveWorkspace,
            backupPage: _settings(context),
          ),
        'backups' => _settings(context),
        'bulk-import' => _bulkImport(context),
        _ => _overview(context),
      };
      return Scaffold(
        key: _scaffoldKey,
        drawer: isWide ? null : Drawer(
          child: SafeArea(child: HyperionSidebar(
            selected: _route,
            onSelect: (route) {
              Navigator.of(context).pop();
              _openRoute(route);
            })),
        ),
        appBar: AppBar(
          toolbarHeight: 72,
          automaticallyImplyLeading: false,
          titleSpacing: isWide ? 23 : 14,
          title: Row(children: [
            if (!isWide) ...[
              IconButton(
                tooltip: 'Open business navigation',
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                icon: Icon(Icons.menu)),
              SizedBox(width: 4),
            ],
            InkWell(
              onTap: () => _navigate(0),
              borderRadius: BorderRadius.circular(12),
              child: Tooltip(
                message: 'Hyperion Books home',
                child: Container(
                  width: 44, height: 44,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(color: Color(0xFF0B294A),
                    borderRadius: BorderRadius.circular(11)),
                  child: ClipRRect(borderRadius: BorderRadius.circular(8),
                    child: Image.asset('assets/brand/logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.anchor_rounded, color: Color(0xFFF2CB55)))),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('HYPERION BOOKS', style: TextStyle(
                  fontWeight: FontWeight.w900, letterSpacing: .2, fontSize: 16)),
                SizedBox(height: 2),
                Text(title, style: TextStyle(
                  color: HyperionColors.muted, fontSize: 11.5,
                  fontWeight: FontWeight.w500)),
              ],
            )),
            if (isWide) ...[
              Icon(Icons.circle, color: HyperionColors.accent, size: 8),
              SizedBox(width: 7),
              Text('Local & offline', style: TextStyle(
                color: HyperionColors.muted, fontSize: 12)),
              SizedBox(width: 18),
            ],
          ]),
          actions: [
            if (isWide) HyperionThemeToggle(),
            IconButton(
              tooltip: 'Search local records',
              onPressed: () => _searchRecords(context),
              icon: Icon(Icons.search_outlined)),
            PopupMenuButton<String>(
              tooltip: 'Quick record',
              icon: Icon(Icons.add_circle_outline),
              onSelected: (action) {
                if (action == 'payout') {
                  _edit(context, EntryKind.payout);
                } else if (action == 'expense') {
                  _edit(context, EntryKind.expense);
                } else if (action == 'csv') {
                  _importSales(context);
                } else if (action == 'expenseCsv') {
                  _importExpenses(context);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'payout', child: Text('Add bank payout')),
                PopupMenuItem(value: 'expense', child: Text('Add expense')),
                PopupMenuItem(value: 'csv', child: Text('Import sales CSV / Excel')),
                PopupMenuItem(value: 'expenseCsv', child: Text('Import expenses CSV')),
              ],
            ),
            IconButton(
              tooltip: 'Back up your records',
              onPressed: () => _backup(context),
              icon: Icon(Icons.backup_outlined)),
            SizedBox(width: 5),
          ],
        ),
        body: Row(children: [
          if (isWide) HyperionSidebar(
            selected: _route, onSelect: _openRoute),
          if (isWide) VerticalDivider(width: 1),
          Expanded(child: Center(child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 1260),
            child: body,
          ))),
        ]),
        bottomNavigationBar: isWide ? null : NavigationBar(
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          selectedIndex: switch (_page) {
            0 => 0, 1 => 1, 2 => 2, 5 => 3, _ => 4,
          },
          onDestinationSelected: (index) {
            if (index == 4) {
              _scaffoldKey.currentState?.openDrawer();
            } else {
              _navigate(index == 3 ? 5 : index);
            }
          },
          destinations: [
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.swap_vert), label: 'Entries'),
            NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: 'Books'),
            NavigationDestination(icon: Icon(Icons.account_balance_outlined), label: 'Tax Filing'),
            NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
          ]),
        floatingActionButton: _page == 1 ? FloatingActionButton.extended(
          backgroundColor: HyperionColors.accent, foregroundColor: HyperionColors.onAccent,
          onPressed: () => _edit(context, _route == 'daily-expenses'
            ? EntryKind.expense : EntryKind.payout),
          icon: Icon(Icons.add),
          label: Text(_route == 'daily-expenses' ? 'Expense' : 'Payout')) : null,
      );
    });
  }

  Widget _bulkImport(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 55),
    children: [
      Text('Bulk Import', style: TextStyle(
        color: HyperionColors.ink, fontSize: 23, fontWeight: FontWeight.w900)),
      SizedBox(height: 6),
      Text('Import transaction files locally, preview changes and '
        'skip existing source references automatically.',
        style: TextStyle(color: HyperionColors.muted)),
      SizedBox(height: 14),
      Card(child: Padding(padding: const EdgeInsets.all(15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('SALES TRANSACTIONS', style: TextStyle(
            color: HyperionColors.ink, fontWeight: FontWeight.w900)),
          SizedBox(height: 7),
          Text('${widget.controller.paymongoTransactions.length} imported records '
            'in this browser'),
          SizedBox(height: 10),
          FilledButton.icon(onPressed: () => _importSales(context),
            icon: Icon(Icons.upload_file_outlined),
            label: Text('Import sales CSV / Excel')),
          OutlinedButton.icon(onPressed: () => _downloadSalesTemplate(context),
            icon: Icon(Icons.description_outlined),
            label: Text('Sales CSV template')),
        ]))),
      SizedBox(height: 10),
      Card(child: Padding(padding: const EdgeInsets.all(15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('EXPENSE TRANSACTIONS', style: TextStyle(
            color: HyperionColors.ink, fontWeight: FontWeight.w900)),
          SizedBox(height: 7),
          Text('${widget.controller.entries.where(
            (e) => e.kind == EntryKind.expense).length} expense entries'),
          SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(onPressed: () => _importExpenses(context),
              icon: Icon(Icons.upload_file),
              label: Text('Import expense CSV')),
            OutlinedButton.icon(onPressed: () => _downloadExpenseTemplate(context),
              icon: Icon(Icons.description_outlined),
              label: Text('Download CSV template')),
          ]),
        ]))),
      SizedBox(height: 10),
      Card(child: Padding(padding: const EdgeInsets.all(15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('BACKUP & ACCOUNTING EXPORT', style: TextStyle(
            fontWeight: FontWeight.w900, color: HyperionColors.ink)),
          SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(onPressed: () => _backup(context),
              icon: Icon(Icons.backup_outlined),
              label: Text('Export JSON backup')),
            OutlinedButton.icon(onPressed: () => _restore(context),
              icon: Icon(Icons.restore),
              label: Text('Restore JSON backup')),
            OutlinedButton.icon(onPressed: () => _export(context),
              icon: Icon(Icons.table_view_outlined),
              label: Text('Export Excel reports')),
          ]),
        ]))),
      SizedBox(height: 12),
      Text('Source imports do not automatically move bank cash. '
        'Importing a JSON backup is different: it REPLACES local records '
        'after explicit confirmation. Keep a fresh backup before restoring.',
        style: TextStyle(color: HyperionColors.muted, fontSize: 12)),
    ]);

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
          title: Text('Import expense CSV?'),
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
              child: Text('Cancel')),
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

  Future<void> _downloadSalesTemplate(BuildContext context) async {
    try {
      await SalesImportService.downloadTemplate();
      if (context.mounted) _message(context, 'Sales import CSV template downloaded.');
    } catch (error) {
      if (context.mounted) _message(context, 'Could not download sales template: $error');
    }
  }

  Future<void> _importSales(BuildContext context) async {
    try {
      final preview = await SalesImportService.select();
      if (preview == null || !context.mounted) return;
      final plan = PayMongoImportPlan.prepare(
        incoming: preview.transactions,
        existing: widget.controller.paymongoTransactions,
      );
      final newRows = plan.newTransactions;
      final duplicates = plan.alreadyImported;
      final totals = PayMongoTotals.fromTransactions(newRows);
      final duplicateNotice = newRows.isEmpty
          ? 'All eligible transactions in this file were already imported. '
            'No records will be changed.\n\n'
          : '';
      final changedNotice = plan.conflictingExisting == 0
          ? ''
          : '${plan.conflictingExisting} existing transaction ID(s) have different '
            'details in this file. Their previously saved values will NOT '
            'be overwritten.\n\n';
      final proceed = await showDialog<bool>(context: context, builder: (dialog) =>
        AlertDialog(
          title: Text('Import sales transactions?'),
          content: SingleChildScrollView(child: Text(
            'New successful payments: ${totals.payments}\n'
            'New adjustments/refunds: ${totals.adjustments}\n'
            'Already imported (skipped): $duplicates\n'
            'Unpaid / unsupported rows (skipped): ${preview.ignored}\n\n'
            '$duplicateNotice'
            '$changedNotice'
            'Gross new sales: ${php(totals.grossPaymentsCentavos)}\n'
            'Processing fees (including VAT): ${php(totals.paymentFeesCentavos)}\n'
            'VAT portion (already included): ${php(totals.paymentVatCentavos)}\n'
            'Net new payment activity, including adjustments: '
            '${php(totals.activityNetCentavos)}\n\n'
            'Records are sorted by the exact date/time shown in the file. '
            'Only transaction IDs, amounts, type, status and method are kept: '
            'customer names/emails are not saved.\n\n'
            'These are customer transactions, NOT bank payouts. '
            'They will NOT be added to the cashflow or journal. '
            'Keep entering actual bank payouts under Entries.',
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog, false),
              child: Text('Cancel')),
            if (newRows.isNotEmpty)
              FilledButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: Text('Import ${newRows.length} new records')),
          ],
        ));
      if (proceed != true || !context.mounted) return;
      final added = await HyperionLoading.whileRunning(
        'Importing sales transactions', () => widget.controller.importPayMongo(newRows));
      if (context.mounted) {
        final skipped = duplicates + (newRows.length - added);
        _message(context, 'Imported $added new sales transactions; '
          'skipped $skipped already imported. Export a JSON backup.');
      }
    } catch (error) {
      if (context.mounted) _message(context, 'Sales spreadsheet import failed: $error');
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
        title: Text('Replace all local records?'),
        content: Text('This JSON backup contains ${incoming.entries.length} payout/expense entries '
          'and ${incoming.paymongo.length} imported sales transactions.\n'
          'Payouts: ${php(summary.netPayouts)}\n'
          'Expenses: ${php(summary.totalExpenses)}\n\n'
          'Your ${current.length} current entries, business lists, reminders and '
          '${widget.controller.paymongoTransactions.length} imported sales transactions '
          'will be REPLACED, not merged. '
          'Export a JSON backup of your current records first. '
          'This will not change other devices.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Replace my local records')),
        ],
      ));
      if (accepted != true || !context.mounted) return;
      await HyperionLoading.whileRunning(
        'Restoring local books', () => widget.controller.restore(incoming.entries,
          paymongo: incoming.paymongo, workspace: incoming.workspace));
      if (context.mounted) {
        _message(context, 'Restored ${incoming.entries.length} entries and '
          '${incoming.paymongo.length} sales transactions from backup.');
      }
    } catch (error) {
      if (context.mounted) _message(context, 'Backup import failed: $error');
    }
  }

  Widget _section(String title, {Widget? trailing}) => Row(children: [
    Expanded(child: Text(title, style: TextStyle(fontSize: 20,
      fontWeight: FontWeight.w800, color: HyperionColors.ink))),
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
      // The expanded 250px business sidebar reduces the available content width.
      // Stack dashboard panels until the content area itself is comfortably wide.
      final wide = constraints.maxWidth >= 1100;
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
              SizedBox(height: 13),
              _periodPicker(period, available),
            ]),
          SizedBox(height: 20),
          _welcomeCard(wide),
          SizedBox(height: 20),
          _importedPanel(context, importedTotals, importedInPeriod.length),
          SizedBox(height: 20),
          BusinessInsightsPanel(
            entries: widget.controller.entries,
            transactions: widget.controller.paymongoTransactions,
            onSales: () => _navigate(3),
            onExpenses: () => _navigate(1),
          ),
          SizedBox(height: 20),
          Text('Bank and cash movements', style: TextStyle(
            color: HyperionColors.ink, fontWeight: FontWeight.w800, fontSize: 17)),
          SizedBox(height: 6),
          Text('These totals come from manually entered bank payouts and expenses, '
            'not from imported customer payments.', style: TextStyle(
              fontSize: 12, color: HyperionColors.muted)),
          SizedBox(height: 13),
          LayoutBuilder(builder: (context, size) {
            final columns = size.maxWidth >= 790 ? 3 : size.maxWidth >= 490 ? 2 : 1;
            const spacing = 13.0;
            final cardWidth = (size.maxWidth - (columns - 1) * spacing) / columns;
            return Wrap(spacing: spacing, runSpacing: spacing, children: [
              SizedBox(width: cardWidth, child: _statCard('Bank payouts', php(selected.netPayouts),
                '${selected.payouts.length} recorded payouts',
                Icons.south_west, HyperionColors.accent)),
              SizedBox(width: cardWidth, child: _statCard('Expenses paid', php(selected.totalExpenses),
                '${selected.expenses.length} recorded expenses',
                Icons.north_east, HyperionColors.danger)),
              SizedBox(width: cardWidth, child: _statCard('Net cash movement', php(selected.netCashMovement),
                'Manual bank payouts minus expenses',
                Icons.account_balance_wallet_outlined, HyperionColors.ink)),
            ]);
          }),
          SizedBox(height: 20),
          if (wide)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 7, child: _recentPanel(context, recent)),
              SizedBox(width: 16),
              Expanded(flex: 4, child: Column(children: [
                _actionsPanel(context),
                SizedBox(height: 16),
                _sourcesPanel(selected, paymongo, play, deductions),
              ])),
            ])
          else ...[
            _actionsPanel(context),
            SizedBox(height: 16),
            _recentPanel(context, recent),
            SizedBox(height: 16),
            _sourcesPanel(selected, paymongo, play, deductions),
          ],
          SizedBox(height: 18),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline, size: 16, color: HyperionColors.muted),
            SizedBox(width: 8),
            Expanded(child: Text(
              'These figures track net payouts by settlement date, not necessarily gross sales. '
              'The generated books are provisional personal records.',
              style: TextStyle(color: HyperionColors.muted, fontSize: 11.5, height: 1.45))),
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
            decoration: BoxDecoration(color: HyperionColors.accentSoft,
              borderRadius: BorderRadius.circular(11)),
            child: Icon(Icons.receipt_long_outlined, color: HyperionColors.accent)),
          SizedBox(width: 11),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sales activity', style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w800, color: HyperionColors.ink)),
              SizedBox(height: 3),
              Text('Customer collections, fees and adjustments — not bank deposits',
                style: TextStyle(fontSize: 11.5, color: HyperionColors.muted)),
            ],
          )),
        ]),
        SizedBox(height: 15),
        if (rows == 0) ...[
          Text('No sales in this period. Import a CSV or Excel file to get started.',
            style: TextStyle(fontSize: 12.5, color: HyperionColors.muted)),
          SizedBox(height: 9),
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
                'Before bank transfers')),
              SizedBox(width: width, child: _activityKpi(
                'Adjustments / refunds', php(totals.adjustmentsNetCentavos),
                '${totals.adjustments} review items')),
            ]);
          }),
          SizedBox(height: 11),
        ],
        Wrap(spacing: 10, runSpacing: 8, children: [
          TextButton.icon(onPressed: () => _navigate(3),
            icon: Icon(Icons.visibility_outlined, size: 18),
            label: Text(rows == 0 ? 'View sales' :
              'View $rows transactions')),
          OutlinedButton.icon(onPressed: () => _importSales(context),
            icon: Icon(Icons.upload_file_outlined, size: 17),
            label: Text('Import CSV / Excel')),
        ]),
      ],
    ));

  Widget _activityKpi(String label, String value, String note) =>
    Container(
      width: double.infinity, padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: HyperionColors.elevated,
        border: Border.all(color: HyperionColors.border),
        borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11.5,
          color: HyperionColors.muted, fontWeight: FontWeight.w700)),
        SizedBox(height: 7),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
          child: Text(value, style: TextStyle(
            fontSize: 22, fontWeight: FontWeight.w900, color: HyperionColors.ink))),
        SizedBox(height: 5),
        Text(note, style: TextStyle(fontSize: 11,
          color: HyperionColors.muted)),
      ]),
    );

  Widget _dashboardHeading() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('Financial overview', style: TextStyle(
      color: HyperionColors.ink, fontSize: 25, fontWeight: FontWeight.w900, height: 1.15)),
    SizedBox(height: 5),
    Text(DateFormat('EEEE, MMM d, yyyy').format(DateTime.now()),
      style: TextStyle(color: HyperionColors.muted, fontSize: 13)),
  ]);

  Widget _periodPicker(String period, List<String> available) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(color: HyperionColors.card,
      border: Border.all(color: HyperionColors.border),
      borderRadius: BorderRadius.circular(12)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.calendar_month_outlined, color: HyperionColors.accent, size: 18),
      SizedBox(width: 9),
      DropdownButtonHideUnderline(child: DropdownButton<String>(
        value: period, isDense: true,
        borderRadius: BorderRadius.circular(12),
        style: TextStyle(fontSize: 13, color: HyperionColors.ink, fontWeight: FontWeight.w700),
        items: ['All time', ...available]
          .map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
        onChanged: (m) => setState(() => _month = m ?? 'All time'),
      )),
    ]),
  );

  Widget _welcomeCard(bool wide) => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
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
              child: Text('YOUR PERSONAL BOOKKEEPING SPACE',
                style: TextStyle(color: Color(0xFFD0F4E5), fontSize: 10,
                  letterSpacing: 1, fontWeight: FontWeight.w800))),
            SizedBox(height: 13),
            Text('A clearer picture of your money.',
              style: TextStyle(color: Colors.white,
                fontSize: wide ? 30 : 24, fontWeight: FontWeight.w900, height: 1.12)),
            SizedBox(height: 8),
            Text('Record payouts and expenses. Your books update automatically.',
              style: TextStyle(color: Color(0xFFD3E5ED), fontSize: 13)),
            SizedBox(height: 19),
            Wrap(spacing: 10, runSpacing: 10, children: [
              FilledButton.icon(onPressed: () => _edit(context, EntryKind.payout),
                style: FilledButton.styleFrom(
                  backgroundColor: HyperionColors.accent, foregroundColor: HyperionColors.onAccent),
                icon: Icon(Icons.add_circle_outline, size: 18),
                label: Text('Add payout')),
              OutlinedButton.icon(onPressed: () => _edit(context, EntryKind.expense),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white,
                  side: BorderSide(color: Color(0xFF8AAEC0))),
                icon: Icon(Icons.receipt_long_outlined, size: 18),
                label: Text('Add expense')),
            ]),
            SizedBox(height: 16),
            Row(mainAxisSize: MainAxisSize.min, children: [
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
      SizedBox(height: 14),
      Text(title, style: TextStyle(color: HyperionColors.muted, fontSize: 12.5,
        fontWeight: FontWeight.w600)),
      SizedBox(height: 5),
      FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
        child: Text(amount, style: TextStyle(
          color: HyperionColors.ink, fontSize: 25, fontWeight: FontWeight.w900))),
      SizedBox(height: 8),
      Text(detail, style: TextStyle(color: HyperionColors.muted, fontSize: 11.5)),
    ]));

  Widget _recentPanel(BuildContext context, List<BookEntry> entries) =>
    _dashboardPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text('Recent activity', style: TextStyle(
          color: HyperionColors.ink, fontWeight: FontWeight.w800, fontSize: 17))),
        TextButton(onPressed: () => _navigate(1), child: Text('View all')),
      ]),
      if (entries.isEmpty)
        Padding(padding: EdgeInsets.symmetric(vertical: 28),
          child: Column(children: [
            Icon(Icons.inbox_outlined, color: HyperionColors.muted, size: 40),
            SizedBox(height: 10),
            Text('Your activity will show up here.',
              style: TextStyle(color: HyperionColors.ink, fontWeight: FontWeight.w800)),
            SizedBox(height: 5),
            Text('Add your first payout or expense to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(color: HyperionColors.muted, fontSize: 12)),
          ]))
      else
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) Divider(height: 1, color: HyperionColors.border),
          _activityRow(context, entries[i]),
        ],
    ]));

  Widget _activityRow(BuildContext context, BookEntry e) {
    final payout = e.kind == EntryKind.payout;
    final accent = payout ? HyperionColors.accent : HyperionColors.danger;
    final name = payout ? e.platform : (e.description.isEmpty ? 'Expense' : e.description);
    return InkWell(onTap: () => _edit(context, e.kind, initial: e),
      borderRadius: BorderRadius.circular(10),
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(children: [
          Container(width: 38, height: 38,
            decoration: BoxDecoration(color: accent.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(11)),
            child: Icon(payout ? Icons.south_west : Icons.north_east, color: accent, size: 18)),
          SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, overflow: TextOverflow.ellipsis, maxLines: 1,
              style: TextStyle(color: HyperionColors.ink, fontSize: 13, fontWeight: FontWeight.w800)),
            SizedBox(height: 3),
            Text(prettyDate(e.date),
              style: TextStyle(color: HyperionColors.muted, fontSize: 11.5)),
          ])),
          SizedBox(width: 8),
          Flexible(child: Text('${payout ? '+' : '−'}${php(e.amountCentavos)}',
            overflow: TextOverflow.ellipsis, maxLines: 1, textAlign: TextAlign.end,
            style: TextStyle(fontSize: 13, color: accent, fontWeight: FontWeight.w900))),
        ])));
  }

  Widget _actionsPanel(BuildContext context) => _dashboardPanel(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Tools & shortcuts', style: TextStyle(
        color: HyperionColors.ink, fontWeight: FontWeight.w800, fontSize: 17)),
      SizedBox(height: 8),
      _shortcut(Icons.menu_book_outlined, 'Open your books',
        'Journal, ledger and cash books', () => _navigate(2)),
      Divider(height: 1, color: HyperionColors.border),
      _shortcut(Icons.file_download_outlined, 'Export Excel',
        'Download your accounting reports', () => _export(context)),
      Divider(height: 1, color: HyperionColors.border),
      _shortcut(Icons.backup_outlined, 'Back up records',
        'Save a restorable JSON file', () => _backup(context)),
    ]));

  Widget _shortcut(IconData icon, String title, String detail, VoidCallback onTap) =>
    InkWell(onTap: onTap, borderRadius: BorderRadius.circular(10),
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Icon(icon, size: 20, color: HyperionColors.accent),
          SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(
              color: HyperionColors.ink, fontSize: 13, fontWeight: FontWeight.w800)),
            SizedBox(height: 3),
            Text(detail, style: TextStyle(
              color: HyperionColors.muted, fontSize: 11.5)),
          ])),
          Icon(Icons.chevron_right, size: 19, color: HyperionColors.muted),
        ])));

  Widget _sourcesPanel(BooksReport report, int paymongo, int play, int deductions) =>
    _dashboardPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Payout sources', style: TextStyle(
        color: HyperionColors.ink, fontWeight: FontWeight.w800, fontSize: 17)),
      SizedBox(height: 4),
      Text('Net deposits by payment platform',
        style: TextStyle(color: HyperionColors.muted, fontSize: 11.5)),
      SizedBox(height: 18),
      _sourceBar('Payment processors', paymongo, report.netPayouts, HyperionColors.accent),
      SizedBox(height: 16),
      _sourceBar('Google Play', play, report.netPayouts, HyperionColors.chartBlue),
      Divider(height: 28, color: HyperionColors.border),
      Row(children: [
        Expanded(child: Text('Known platform deductions',
          style: TextStyle(color: HyperionColors.muted, fontSize: 11))),
        Text(php(deductions), style: TextStyle(
          color: HyperionColors.ink, fontWeight: FontWeight.w800, fontSize: 12)),
      ]),
    ]));

  Widget _sourceBar(String name, int value, int total, Color color) {
    final share = total <= 0 ? 0.0 : (value / total).clamp(0.0, 1.0);
    return Column(children: [
      Row(children: [
        Expanded(child: Text(name,
          style: TextStyle(color: HyperionColors.ink, fontWeight: FontWeight.w700, fontSize: 12.5))),
        Text(php(value), style: TextStyle(
          color: HyperionColors.ink, fontWeight: FontWeight.w800, fontSize: 12.5)),
      ]),
      SizedBox(height: 9),
      ClipRRect(borderRadius: BorderRadius.circular(20),
        child: LinearProgressIndicator(value: share, minHeight: 7,
          backgroundColor: HyperionColors.elevated, color: color)),
    ]);
  }

  Widget _dashboardPanel({required Widget child}) => Container(
    width: double.infinity, padding: const EdgeInsets.all(19),
    decoration: BoxDecoration(color: HyperionColors.card,
      border: Border.all(color: HyperionColors.border),
      borderRadius: BorderRadius.circular(18),
      boxShadow: [BoxShadow(
        color: HyperionColors.ink.withValues(alpha: .035),
        blurRadius: 18, offset: Offset(0, 5))]),
    child: child);

  Widget _transactions(BuildContext context) {
    final entries = widget.controller.entries.where((e) => switch (_filter) {
      'Payouts' => e.kind == EntryKind.payout,
      'Expenses' => e.kind == EntryKind.expense,
      _ => true,
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
    return ListView(padding: const EdgeInsets.fromLTRB(20, 18, 20, 110), children: [
      _section('Your entries'),
      SizedBox(height: 8),
      Text('Tap an entry to edit. Changes stay on this device until you export a backup.'),
      SizedBox(height: 15),
      Wrap(spacing: 8, children: [
        for (final label in ['All', 'Payouts', 'Expenses']) ChoiceChip(
          label: Text(label), selected: _filter == label,
          onSelected: (_) => setState(() => _filter = label)),
        OutlinedButton.icon(onPressed: () => _edit(context, EntryKind.expense),
          icon: Icon(Icons.add), label: Text('Expense')),
        OutlinedButton.icon(onPressed: () => _navigate(3),
          icon: Icon(Icons.receipt_long_outlined), label: Text('Sales imports')),
        OutlinedButton.icon(onPressed: () => _importExpenses(context),
          icon: Icon(Icons.upload_file_outlined), label: Text('Import expenses CSV')),
      ]),
      SizedBox(height: 10),
      if (entries.isEmpty) _EmptyState('No matching entries', 'Use the buttons above to add your first transaction.'),
      ...entries.map((e) => _entryTile(context, e, editable: true)),
    ]);
  }

  Widget _entryTile(BuildContext context, BookEntry e, {bool editable = false}) {
    final payout = e.kind == EntryKind.payout;
    return Card(margin: const EdgeInsets.only(bottom: 9), child: ListTile(
      onTap: () => _edit(context, e.kind, initial: e),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 3),
      leading: CircleAvatar(backgroundColor: payout ? HyperionColors.accentSoft : HyperionColors.dangerSoft,
        child: Icon(payout ? Icons.south_west : Icons.north_east,
          color: payout ? HyperionColors.accent : HyperionColors.danger)),
      title: Text(payout ? e.platform : e.description, maxLines: 2, overflow: TextOverflow.ellipsis,
        style: TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text('${prettyDate(e.date)}${payout && e.description.isNotEmpty ? ' · ${e.description}' : ''}'
        '', maxLines: 2),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('${payout ? '+' : '−'}${php(e.amountCentavos)}', style: TextStyle(
          fontWeight: FontWeight.w800, color: payout ? HyperionColors.accent : HyperionColors.danger)),
        if (editable) PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') {
              _edit(context, e.kind, initial: e);
            } else {
              _delete(context, e);
            }
          },
          itemBuilder: (_) => [PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete'))],
        ),
      ]),
    ));
  }

  Widget _settings(BuildContext context) {
    final ctrl = widget.controller;
    return ListView(padding: const EdgeInsets.all(20), children: [
      _section('Your records & backups'),
      SizedBox(height: 14),
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Private device storage', style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Text('${ctrl.workspace.masters.length} master-list items, '
          '${ctrl.workspace.reminders.length} reminders, '
          '${ctrl.entries.length} cash entries and '
          '${ctrl.paymongoTransactions.length} imported sales transactions in this browser.'),
        Text(ctrl.status),
        SizedBox(height: 12),
        Text('To move records between devices, export a JSON backup here, '
          'then import it on the other device. Excel exports are for reading and printing, '
          'and cannot be restored into the app.'),
        SizedBox(height: 14),
        Wrap(spacing: 10, runSpacing: 10, children: [
          FilledButton.icon(onPressed: () => _backup(context),
            icon: Icon(Icons.save_alt), label: Text('Export JSON backup')),
          OutlinedButton.icon(onPressed: () => _restore(context),
            icon: Icon(Icons.restore_page_outlined), label: Text('Import JSON backup')),
          OutlinedButton.icon(onPressed: () => _export(context),
            icon: Icon(Icons.file_download_outlined), label: Text('Export Excel books')),
          OutlinedButton.icon(onPressed: () => _importSales(context),
            icon: Icon(Icons.upload_file), label: Text('Import sales CSV / Excel')),
          OutlinedButton.icon(onPressed: () => _downloadSalesTemplate(context),
            icon: Icon(Icons.description_outlined), label: Text('Sales CSV template')),
          OutlinedButton.icon(onPressed: () => _importExpenses(context),
            icon: Icon(Icons.upload_file_outlined), label: Text('Import expenses CSV')),
          OutlinedButton.icon(onPressed: () => _downloadExpenseTemplate(context),
            icon: Icon(Icons.description_outlined), label: Text('Expense CSV template')),
        ]),
      ]))),
      SizedBox(height: 15),
      Card(child: Padding(padding: const EdgeInsets.all(17), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Important notes', style: TextStyle(fontWeight: FontWeight.w800)),
          SizedBox(height: 8),
          Text('• No Google login, Supabase, cloud sync or external financial database.\n'
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
      SizedBox(height: 8),
      Text(title, style: TextStyle(fontWeight: FontWeight.w800)),
      Text(subtitle, textAlign: TextAlign.center),
    ]),
  );
}
