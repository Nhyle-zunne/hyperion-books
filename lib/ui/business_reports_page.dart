import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/accounting_books.dart';
import '../models/book_entry.dart';
import '../models/business_workspace.dart';
import '../models/paymongo_transaction.dart';
import '../models/business_analytics.dart';
import 'business_insights_panel.dart';

const _navy = Color(0xFF042353);
const _ink = Color(0xFF112940);
const _muted = Color(0xFF60738A);
final _php = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
String _fmt(int cents) => _php.format(cents / 100);

/// Readiness of the LOCAL records, not a legal BIR compliance score.
class CompliancePage extends StatelessWidget {
  final BusinessWorkspace workspace;
  final List<BookEntry> entries;
  final List<PayMongoTransaction> transactions;
  final ValueChanged<String> navigate;
  const CompliancePage({super.key, required this.workspace,
    required this.entries, required this.transactions, required this.navigate});

  @override Widget build(BuildContext context) {
    final books = AccountingBooks.fromSources(entries, transactions);
    final items = <({String label, String detail, bool done, String route})>[
      (label: 'Business name', detail: 'Business details maintained locally',
        done: workspace.businessName.trim().isNotEmpty, route: 'my-business'),
      (label: 'Business TIN', detail: 'User-entered reference, not BIR-validated',
        done: workspace.businessTin.trim().isNotEmpty, route: 'my-business'),
      (label: 'Registered address', detail: 'Optional local business profile',
        done: workspace.businessAddress.trim().isNotEmpty, route: 'my-business'),
      (label: 'Tax classification selected',
        detail: 'Reference only; obligations are not verified automatically',
        done: workspace.taxStatus != 'Not specified', route: 'my-business'),
      (label: 'Payments imported', detail: 'PayMongo CSV source references available',
        done: transactions.isNotEmpty, route: 'sales'),
      (label: 'Books with entries', detail: 'At least one provisional journal posting',
        done: books.journal.isNotEmpty, route: 'tax-books'),
      (label: 'Journal debit / credit balances',
        detail: 'Double-entry arithmetic (not reconciled balances)',
        done: books.balanced, route: 'journal'),
      (label: 'All source references reviewed',
        detail: 'Manual review flags only, not external verification',
        done: books.journal.isNotEmpty && books.journal.every(
          (e) => workspace.verifiedReferences.contains(e.reference)),
        route: 'journal'),
      (label: 'Local tax planner', detail: 'User-entered reminders reviewed',
        done: workspace.reminders.isNotEmpty &&
          workspace.reminders.every((r) => r.completed),
        route: 'tax-calendar'),
      (label: 'Unresolved accounting notices', detail: 'Review provisional issues',
        done: books.warnings.isEmpty, route: 'tax-books'),
    ];
    final complete = items.where((x) => x.done).length;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 50), children: [
      const Text('Compliance & Record Readiness', style: TextStyle(
        fontSize: 23, color: _ink, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      const Text('Local bookkeeping health checks · not official BIR compliance',
        style: TextStyle(color: _muted, fontSize: 12)),
      const SizedBox(height: 14),
      Card(child: Padding(padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$complete of ${items.length} local checks complete',
            style: const TextStyle(color: _navy,
              fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: complete / items.length, minHeight: 9),
          const SizedBox(height: 8),
          const Text('Status depends only on device records and manually entered '
            'flags. It does not confirm forms are filed, taxes are paid, '
            'invoices are valid or books are BIR-authorized.',
            style: TextStyle(color: _muted, fontSize: 12)),
        ]))),
      const SizedBox(height: 10),
      for (final check in items)
        Card(child: ListTile(
          leading: Icon(check.done ? Icons.check_circle_outline :
            Icons.info_outline, color: check.done ?
            const Color(0xFF16754B) : const Color(0xFFB27439)),
          title: Text(check.label, style: const TextStyle(
            fontWeight: FontWeight.w800)),
          subtitle: Text(check.detail),
          trailing: const Icon(Icons.chevron_right, size: 19),
          onTap: () => navigate(check.route),
        )),
      const SizedBox(height: 10),
      const Text('Real BIR filing, invoice issuance, permits, tax dates and '
        'reconciliations require independent verification with the BIR and '
        'underlying documentation.',
        style: TextStyle(fontSize: 11, color: _muted)),
    ]);
  }
}

/// Book-derived financial, management and invoice due-date reports.
/// Asset valuation, accruals, inventory and withholding credits are not
/// inferred when source documents don't supply them.
class BusinessReportsPage extends StatelessWidget {
  final String mode;
  final BusinessWorkspace workspace;
  final List<BookEntry> entries;
  final List<PayMongoTransaction> transactions;
  final ValueChanged<String> navigate;
  const BusinessReportsPage({super.key, required this.mode,
    required this.workspace, required this.entries,
    required this.transactions, required this.navigate});

  @override Widget build(BuildContext context) {
    if (mode == 'aging') return _aging();
    if (mode == 'management') {
      return ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Management Reports', style: TextStyle(
          fontWeight: FontWeight.w900, fontSize: 23, color: _ink)),
        const SizedBox(height: 6),
        const Text('Revenue, costs and bank movements from locally entered data',
          style: TextStyle(color: _muted, fontSize: 12)),
        const SizedBox(height: 16),
        BusinessInsightsPanel(entries: entries, transactions: transactions,
          onSales: () => navigate('sales'),
          onExpenses: () => navigate('daily-expenses')),
        const SizedBox(height: 25),
      ]);
    }
    final books = AccountingBooks.fromSources(entries, transactions);
    final accounts = books.ledger.keys.toList()..sort();
    final debit = accounts.fold<int>(0, (n,a) {
      final bal = books.accountBalance(a);
      return n + (bal > 0 ? bal : 0);
    });
    final credit = accounts.fold<int>(0, (n,a) {
      final bal = books.accountBalance(a);
      return n + (bal < 0 ? -bal : 0);
    });
    final bank = books.accountBalance(AccountingBooks.bank);
    final clearing = books.accountBalance(AccountingBooks.clearing);
    final sales = -books.accountBalance(AccountingBooks.sales);
    final play = -books.accountBalance(AccountingBooks.google);
    final fees = books.accountBalance(AccountingBooks.fees);
    final expenses = entries.where((e) => e.kind == EntryKind.expense && !e.deleted)
      .fold<int>(0, (n,e) => n + e.amountCentavos);
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 45), children: [
      const Text('Financial Reports', style: TextStyle(
        fontSize: 23, fontWeight: FontWeight.w900, color: _ink)),
      const SizedBox(height: 5),
      const Text('Provisional source-based trial balance and account summary',
        style: TextStyle(color: _muted, fontSize: 12)),
      const SizedBox(height: 12),
      Card(child: Padding(padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('TRIAL BALANCE', style: TextStyle(
            fontWeight: FontWeight.w900, color: _navy)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _metric('Total debits', _fmt(debit))),
            Expanded(child: _metric('Total credits', _fmt(credit))),
          ]),
          const SizedBox(height: 8),
          Text(debit == credit ? 'Debits and credits balance mathematically.'
            : 'Trial balance does not balance: review the source records.',
            style: const TextStyle(color: _muted, fontSize: 12)),
          const SizedBox(height: 12),
          Scrollbar(thumbVisibility: false, child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(columns: const [
              DataColumn(label: Text('Account')),
              DataColumn(label: Text('Debit balance')),
              DataColumn(label: Text('Credit balance')),
            ], rows: [
              for (final account in accounts) DataRow(cells: [
                DataCell(Text(account)),
                DataCell(Text(_fmt(books.accountBalance(account) > 0 ?
                  books.accountBalance(account) : 0))),
                DataCell(Text(_fmt(books.accountBalance(account) < 0 ?
                  -books.accountBalance(account) : 0))),
              ]),
            ]))),
        ]))),
      const SizedBox(height: 12),
      Card(child: Padding(padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('SOURCE-BASED FINANCIAL SNAPSHOT', style: TextStyle(
            fontWeight: FontWeight.w900, color: _navy)),
          const SizedBox(height: 8),
          _line('Cash / bank (book balance)', bank),
          _line('PayMongo settlement clearing', clearing),
          const Divider(),
          _line('Gross PayMongo sales (provisional)', sales),
          _line('Google Play receipts (provisional)', play),
          _line('Processor fees', fees),
          _line('Manual cash expenses', expenses),
          const Divider(),
          _line('Indicative receipts less known costs',
            sales + play - fees - expenses, bold: true),
        ]))),
      const SizedBox(height: 12),
      if (books.warnings.isNotEmpty)
        Card(child: ExpansionTile(title: Text(
          'Accounting review notices (${books.warnings.length})'),
          children: [for (final w in books.warnings)
            ListTile(title: Text(w, style: const TextStyle(fontSize: 12)))])),
      const SizedBox(height: 10),
      const Text('This is NOT a formal income statement or balance sheet. '
        'Opening balances, inventory, receivables, taxes, refunds, payroll '
        'liabilities and year-end adjustments are not fully captured. '
        'Do not use provisional amounts for tax filing without reconciliation.',
        style: TextStyle(color: _muted, fontSize: 12)),
    ]);
  }

  Widget _aging() {
    final today = DateTime.now();
    final invoices = workspace.taxRecords.where((r) =>
      r.kind == 'Invoice' && r.status != 'Paid' &&
      r.status != 'Cancelled' && r.status != 'Draft').toList();
    final due = invoices.where((r) => r.dueDate != null).toList()
      ..sort((a,b) => a.dueDate!.compareTo(b.dueDate!));
    final undated = invoices.where((r) => r.dueDate == null).toList();
    int age(TaxRecord r) {
      final d = r.dueDate!;
      return DateTime(today.year, today.month, today.day).difference(
        DateTime(d.year, d.month, d.day)).inDays;
    }
    int band(int min, int max) => due.where((r) =>
      age(r) >= min && age(r) <= max).fold<int>(
        0,(n,r) => n + r.amountCentavos);
    final open = due.fold<int>(0, (n,r) => n + r.amountCentavos);
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 45), children: [
      const Text('Aging Reports', style: TextStyle(
        fontSize: 23, fontWeight: FontWeight.w900, color: _ink)),
      const SizedBox(height: 5),
      const Text('Manual invoice register · unpaid amounts grouped by due date',
        style: TextStyle(color: _muted, fontSize: 12)),
      const SizedBox(height: 13),
      Card(child: Padding(padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('OPEN INVOICE AMOUNTS  ·  ${_fmt(open)}', style: const TextStyle(
            fontWeight: FontWeight.w900, color: _navy, fontSize: 16)),
          const Divider(height: 20),
          _line('Not yet due', band(-100000, -1)),
          _line('Due today — 30 days past due', band(0,30)),
          _line('31–60 days past due', band(31,60)),
          _line('61–90 days past due', band(61,90)),
          _line('More than 90 days past due', band(91,100000)),
          Text('${undated.length} open invoice(s) have no due date and are excluded.',
            style: const TextStyle(color: _muted, fontSize: 12)),
        ]))),
      const SizedBox(height: 12),
      Card(child: Column(children: [
        if (invoices.isEmpty) const ListTile(title: Text(
          'No issued, unpaid invoices in the local register.')),
        for (final invoice in invoices)
          ListTile(
            title: Text(invoice.name),
            subtitle: Text([
              invoice.reference,
              invoice.dueDate == null
                ? 'No due date'
                : 'Due ${DateFormat('MMM d, yyyy').format(invoice.dueDate!)}',
              invoice.status,
            ].where((s) => s.isNotEmpty).join(' · ')),
            trailing: Text(_fmt(invoice.amountCentavos),
              style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
      ])),
      const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: () => navigate('tax-invoices'),
        icon: const Icon(Icons.receipt_long_outlined),
        label: const Text('Manage invoice records and due dates')),
      const SizedBox(height: 9),
      const Text('Aging reflects manually entered invoice due dates and '
        'statuses only. No live receivables reconciliation or collection '
        'validation exists. Draft/paid/cancelled invoices are excluded.',
        style: TextStyle(color: _muted, fontSize: 12)),
    ]);
  }

  Widget _metric(String label,String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: _muted, fontSize: 11)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(color: _navy,
        fontWeight: FontWeight.w900, fontSize: 16)),
    ]);
  Widget _line(String label,int value,{bool bold=false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7), child: Row(children: [
      Expanded(child: Text(label, style: TextStyle(
        fontWeight: bold ? FontWeight.w900 : FontWeight.w500))),
      const SizedBox(width: 9),
      Text(_fmt(value), style: TextStyle(
        color: _navy, fontWeight: bold ? FontWeight.w900 : FontWeight.w700)),
    ]));
}
