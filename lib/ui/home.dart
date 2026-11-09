import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/book_entry.dart';
import '../models/reports.dart';
import '../services/export_service.dart';
import '../services/backup_service.dart';
import '../state/books_controller.dart';
import 'entry_dialog.dart';

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

  Future<void> _edit(BuildContext context, EntryKind kind, {BookEntry? initial}) async {
    final id = widget.controller.userId;
    final value = await showEntryEditor(context, id, kind, initial: initial);
    if (value == null || !context.mounted) return;
    try {
      await widget.controller.save(value);
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
    if (confirmed == true) await widget.controller.remove(entry);
  }

  void _message(BuildContext context, String text) => ScaffoldMessenger.of(context)
    .showSnackBar(SnackBar(content: Text(text)));

  Future<void> _export(BuildContext context) async {
    try {
      await ExportService.export(widget.controller.report);
      if (context.mounted) _message(context, 'Excel workbook exported.');
    } catch (error) {
      if (context.mounted) _message(context, 'Excel export failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: widget.controller, builder: (context, _) {
      final ctrl = widget.controller;
      if (ctrl.loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
      if (!ctrl.ready) return Scaffold(body: Center(child: Padding(
        padding: const EdgeInsets.all(25), child: Text(ctrl.status, textAlign: TextAlign.center))));
      final isWide = MediaQuery.sizeOf(context).width >= 850;
      final title = const ['Overview', 'Transactions', 'Books & reports', 'Settings'][_page];
      final body = switch (_page) {
        0 => _overview(context),
        1 => _transactions(context),
        2 => _books(context),
        _ => _settings(context),
      };
      return Scaffold(
        appBar: AppBar(
          leading: isWide ? const Icon(Icons.anchor_outlined) : null,
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('HYPERION BOOKS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.3, fontSize: 17)),
            Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ]),
          actions: [
            IconButton(tooltip: 'Back up your records',
              onPressed: () => _backup(context), icon: const Icon(Icons.backup_outlined)),
            const SizedBox(width: 10),
          ],
        ),
        body: Row(children: [
          if (isWide) NavigationRail(
            selectedIndex: _page, onDestinationSelected: (v) => setState(() => _page = v),
            backgroundColor: Colors.white, labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.space_dashboard_outlined),
                selectedIcon: Icon(Icons.space_dashboard), label: Text('Overview')),
              NavigationRailDestination(icon: Icon(Icons.swap_vert_outlined),
                selectedIcon: Icon(Icons.swap_vert), label: Text('Entries')),
              NavigationRailDestination(icon: Icon(Icons.menu_book_outlined),
                selectedIcon: Icon(Icons.menu_book), label: Text('Books')),
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
          selectedIndex: _page, onDestinationSelected: (v) => setState(() => _page = v),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.swap_vert), label: 'Entries'),
            NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: 'Books'),
            NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
          ]),
        floatingActionButton: _page == 1 ? FloatingActionButton.extended(
          backgroundColor: _green, foregroundColor: Colors.white,
          onPressed: () => _edit(context, EntryKind.payout),
          icon: const Icon(Icons.add), label: const Text('Payout')) : null,
      );
    });
  }

  Future<void> _backup(BuildContext context) async {
    try {
      await BackupService.export(widget.controller.entries);
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
      final summary = BooksReport.fromEntries(incoming);
      final accepted = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
        title: const Text('Replace all local records?'),
        content: Text('This JSON backup contains ${incoming.length} entries.\n'
          'Payouts: ${php(summary.netPayouts)}\n'
          'Expenses: ${php(summary.totalExpenses)}\n\n'
          'Your ${current.length} current entries on this device will be REPLACED, not merged. '
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
      await widget.controller.restore(incoming);
      if (context.mounted) _message(context, 'Restored ${incoming.length} entries from backup.');
    } catch (error) {
      if (context.mounted) _message(context, 'Backup import failed: $error');
    }
  }

  Widget _section(String title, {Widget? trailing}) => Row(children: [
    Expanded(child: Text(title, style: const TextStyle(fontSize: 20,
      fontWeight: FontWeight.w800, color: _ink))),
    if (trailing != null) trailing,
  ]);

  Widget _overview(BuildContext context) {
    final report = widget.controller.report;
    final available = report.months.map((m) => m.month).toList();
    if (_month != 'All time' && !available.contains(_month)) _month = 'All time';
    final selected = _month == 'All time'
      ? report
      : BooksReport.fromEntries(widget.controller.entries.where((e) => e.dateKey.startsWith(_month)));
    final receipts = selected.payouts.fold<int>(0, (s, e) => s + e.receiptsCentavos);
    final deductions = selected.payouts.fold<int>(0, (s, e) => s + e.deductionCentavos);
    return ListView(padding: const EdgeInsets.all(20), children: [
      _welcomeCard(context),
      const SizedBox(height: 22),
      _section('Cashflow overview', trailing: DropdownButton<String>(
        value: _month, items: ['All time', ...available]
        .map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
        onChanged: (m) => setState(() => _month = m ?? 'All time'))),
      const SizedBox(height: 14),
      LayoutBuilder(builder: (context, size) {
        final wide = size.maxWidth > 730;
        final cards = [
          _statCard('Net payouts', php(selected.netPayouts), Icons.account_balance_wallet_outlined, _green),
          _statCard('Expenses', php(selected.totalExpenses), Icons.receipt_long_outlined, const Color(0xFFC25751)),
          _statCard('Net cash movement', php(selected.netCashMovement), Icons.trending_up, _ink),
        ];
        return wide ? Row(children: [for (final c in cards) Expanded(child: Padding(
          padding: const EdgeInsets.only(right: 10), child: c))])
          : Column(children: [for (final c in cards) Padding(padding: const EdgeInsets.only(bottom: 10), child: c)]);
      }),
      const SizedBox(height: 18),
      Card(child: Padding(padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Quick entry', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 13),
          Wrap(spacing: 12, runSpacing: 10, children: [
            FilledButton.icon(onPressed: () => _edit(context, EntryKind.payout),
              icon: const Icon(Icons.add_circle_outline), label: const Text('Add PayMongo / Google Play payout')),
            OutlinedButton.icon(onPressed: () => _edit(context, EntryKind.expense),
              icon: const Icon(Icons.remove_circle_outline), label: const Text('Add expense')),
          ]),
        ]))),
      const SizedBox(height: 14),
      Card(child: Padding(padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Platform reconciliation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('Provisional receipts: ${php(receipts)}   •   Known deductions: ${php(deductions)}'),
          const SizedBox(height: 8),
          const Text('Gross defaults to net when no settlement figure is supplied. This is cash tracking, not a substitute for tax sales records.',
            style: TextStyle(fontSize: 12)),
        ]))),
      const SizedBox(height: 21),
      _section('Recent entries', trailing: TextButton(onPressed: () => setState(() => _page = 1), child: const Text('View all'))),
      ...widget.controller.entries.take(6).map((e) => _entryTile(context, e)),
      if (widget.controller.entries.isEmpty) const _EmptyState('No entries yet', 'Add a payout or expense to begin.'),
    ]);
  }

  Widget _welcomeCard(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(color: const Color(0xFF0B294A), borderRadius: BorderRadius.circular(20)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.anchor, color: Color(0xFF8DDFC0), size: 34),
      const SizedBox(height: 10),
      const Text('Bookkeeping, minus the paperwork.',
        style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w800)),
      const SizedBox(height: 7),
      const Text('Just payouts + expenses. Your records and accounting views update automatically.',
        style: TextStyle(color: Color(0xFFD3E3F0))),
      const SizedBox(height: 12),
      Text(widget.controller.status, style: const TextStyle(color: Color(0xFFA6DAC5), fontSize: 12)),
    ]),
  );

  Widget _statCard(String label, String value, IconData icon, Color color) => Card(
    child: Padding(padding: const EdgeInsets.all(19), child: Row(children: [
      CircleAvatar(backgroundColor: color.withValues(alpha: .10), child: Icon(icon, color: color)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
        const SizedBox(height: 3),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: _ink))),
      ])),
    ])),
  );

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
          onSelected: (v) { if (v == 'edit') _edit(context, e.kind, initial: e); else _delete(context, e); },
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
        Text('${ctrl.entries.length} entries saved in this browser.'),
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
