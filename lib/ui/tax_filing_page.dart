import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/hyperion_theme.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/book_entry.dart';
import '../models/business_workspace.dart';
import '../models/paymongo_transaction.dart';
import '../models/tax_period_summary.dart';
import 'accounting_books_page.dart';

final _php = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
String _pesos(int c) => _php.format(c / 100);

/// Offline tax preparation hub. Local registers and reminders must never be
/// represented as filed returns, BIR-registered invoices or validated deadlines.
class TaxFilingPage extends StatefulWidget {
  final List<BookEntry> entries;
  final List<PayMongoTransaction> transactions;
  final BusinessWorkspace workspace;
  final Future<void> Function(BusinessWorkspace) save;
  final int initialSection;
  const TaxFilingPage({super.key, required this.entries,
    required this.transactions, required this.workspace,
    required this.save, this.initialSection = 0});
  @override State<TaxFilingPage> createState() => _TaxFilingPageState();
}

class _TaxFilingPageState extends State<TaxFilingPage> {
  late int section;
  DateTime viewing = DateTime(DateTime.now().year, DateTime.now().month);
  bool busy = false;
  @override void initState() {
    super.initState();
    section = widget.initialSection.clamp(0, 6);
  }

  static const sections = [
    'Calendar','Monthly','Quarterly','Annual',
    '2307 Certificates','e-Invoicing','Books of Accounts',
  ];

  Future<void> _save(BusinessWorkspace next) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await widget.save(next);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Saved in this browser. Export a backup to protect this data.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not save: $error')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  DateTime get first {
    if (section == 2) {
      final q = (viewing.month - 1) ~/ 3;
      return DateTime(viewing.year, q * 3 + 1);
    }
    return section == 3 ? DateTime(viewing.year) :
      DateTime(viewing.year, viewing.month);
  }
  DateTime get last {
    if (section == 2) return DateTime(first.year, first.month + 3, 0);
    if (section == 3) return DateTime(viewing.year, 12, 31);
    return DateTime(viewing.year, viewing.month + 1, 0);
  }
  String get periodKey {
    if (section == 2) return '${viewing.year}-Q${((viewing.month - 1) ~/ 3) + 1}';
    if (section == 3) return '${viewing.year}';
    return DateFormat('yyyy-MM').format(viewing);
  }
  String get periodLabel {
    if (section == 2) return 'Q${((viewing.month - 1) ~/ 3) + 1} ${viewing.year}';
    if (section == 3) return '${viewing.year}';
    return DateFormat('MMMM yyyy').format(viewing);
  }
  void _step(int dir) => setState(() {
    final delta = section == 2 ? 3 * dir : section == 3 ? 12 * dir : dir;
    viewing = DateTime(viewing.year, viewing.month + delta);
  });

  @override Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(color: Colors.white, padding: const EdgeInsets.fromLTRB(18, 17, 18, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Tax Filing', style: TextStyle(color: HyperionColors.ink,
            fontSize: 22, fontWeight: FontWeight.w900)),
          SizedBox(height: 4),
          Text('Local preparation, filing logs and supporting records',
            style: TextStyle(color: HyperionColors.muted, fontSize: 12)),
          SizedBox(height: 14),
          SingleChildScrollView(scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (var i = 0; i < sections.length; i++) ...[
                _choice(i), SizedBox(width: 7),
              ],
            ])),
        ])),
      Expanded(child: switch (section) {
        0 => _calendar(),
        1 || 2 || 3 => _periodOverview(),
        4 => _register('2307'),
        5 => _register('Invoice'),
        _ => AccountingBooksPage(entries: widget.entries,
          transactions: widget.transactions, workspace: widget.workspace,
          save: widget.save),
      }),
    ]);
  }

  Widget _choice(int i) => OutlinedButton(
    onPressed: () => setState(() => section = i),
    style: OutlinedButton.styleFrom(
      backgroundColor: section == i ? HyperionColors.brand : Colors.white,
      foregroundColor: section == i ? Colors.white : HyperionColors.brand,
      side: BorderSide(color: section == i ? HyperionColors.brand : HyperionColors.border)),
    child: Text(sections[i]));

  Widget _periodPicker() => Row(mainAxisSize: MainAxisSize.min, children: [
    IconButton(tooltip: 'Previous period', onPressed: () => _step(-1),
      icon: Icon(Icons.chevron_left)),
    Text(periodLabel, style: TextStyle(fontSize: 16,
      fontWeight: FontWeight.w900, color: HyperionColors.brand)),
    IconButton(tooltip: 'Next period', onPressed: () => _step(1),
      icon: Icon(Icons.chevron_right)),
  ]);

  Widget _calendar() {
    final tasks = widget.workspace.reminders.where((r) =>
      r.dueDate.year == viewing.year && r.dueDate.month == viewing.month).toList()
      ..sort((a,b) => a.dueDate.compareTo(b.dueDate));
    final filings = widget.workspace.taxRecords.where((r) =>
      r.kind == 'Filing' && r.date.year == viewing.year &&
      r.date.month == viewing.month).toList()
      ..sort((a,b) => a.date.compareTo(b.date));
    final allTasks = widget.workspace.reminders;
    final lateTasks = allTasks.where((r) =>
      !r.completed && r.dueDate.isBefore(DateTime.now())).length;
    return ListView(padding: const EdgeInsets.all(16), children: [
      _panel([
        Text('Tax Calendar', style: TextStyle(fontSize: 19,
          color: HyperionColors.ink, fontWeight: FontWeight.w900)),
        Text('Only dates you enter appear here; no filing deadline is inferred.',
          style: TextStyle(color: HyperionColors.muted, fontSize: 12)),
        _periodPicker(),
        Wrap(spacing: 8, children: [
          FilledButton.icon(onPressed: busy ? null : () => _editReminder(),
            icon: Icon(Icons.add), label: Text('Add reminder')),
          OutlinedButton.icon(onPressed: busy ? null :
            () => _editTax('Filing', proposedPeriod: periodKey),
            icon: Icon(Icons.description_outlined),
            label: Text('Record filing')),
        ]),
      ]),
      SizedBox(height: 12),
      _panel([
        Text('${tasks.length} reminders · ${filings.length} filing logs this month',
          style: TextStyle(color: HyperionColors.ink, fontWeight: FontWeight.w800)),
        if (lateTasks > 0) Text('$lateTasks open reminders are past their manually selected dates.',
          style: TextStyle(fontSize: 12, color: HyperionColors.warning)),
        if (tasks.isEmpty && filings.isEmpty)
          Padding(padding: EdgeInsets.all(18),
            child: Text('No items recorded for this month.')),
        for (final task in tasks)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Checkbox(value: task.completed, onChanged: busy ? null :
              (v) => _save(widget.workspace.copyWith(reminders: [
                for (final item in widget.workspace.reminders)
                  if (item.id == task.id)
                    item.copyWith(completed: v ?? false)
                  else item,
              ]))),
            title: Text(task.title),
            subtitle: Text('${DateFormat('MMM d, yyyy').format(task.dueDate)} · Reminder'),
            trailing: IconButton(tooltip: 'Edit reminder',
              onPressed: () => _editReminder(task),
              icon: Icon(Icons.edit_outlined))),
        for (final filing in filings) _taxTile(filing),
      ]),
      SizedBox(height: 12),
      Text('Manual calendar only. Filing dates, holiday extensions, '
        'registration obligations and actual BIR acceptance must be checked '
        'outside this app.', style: TextStyle(color: HyperionColors.muted, fontSize: 12)),
    ]);
  }

  Widget _periodOverview() {
    final s = TaxPeriodSummary.between(entries: widget.entries,
      transactions: widget.transactions, first: first, last: last);
    final entries = widget.workspace.taxRecords.where(
      (r) => r.kind == 'Filing' && r.period == periodKey).toList();
    final ytd = TaxPeriodSummary.between(entries: widget.entries,
      transactions: widget.transactions, first: DateTime(viewing.year),
      last: last);
    final eightPercent = widget.workspace.taxStatus == '8% income tax (if elected)';
    final illustration = (math.max(0, ytd.trackedReceipts - 25000000) * 0.08).round();
    return ListView(padding: const EdgeInsets.all(16), children: [
      _panel([
        Text('${sections[section]} Tax Working Papers',
          style: TextStyle(fontSize: 19, color: HyperionColors.ink,
            fontWeight: FontWeight.w900)),
        _periodPicker(),
        Text('Coverage: ${DateFormat('MMM d, yyyy').format(first)} – '
          '${DateFormat('MMM d, yyyy').format(last)}',
          style: TextStyle(color: HyperionColors.muted, fontSize: 12)),
        SizedBox(height: 13),
        Wrap(spacing: 10, runSpacing: 10, children: [
          _metric('Tracked gross receipts', s.trackedReceipts),
          _metric('Processor fees', s.processorFees),
          _metric('Manual expenses', s.manualExpenses),
          _metric('Bank cash movement', s.bankMovement),
        ]),
        SizedBox(height: 12),
        Text('${s.paymentCount} imported PayMongo customer payments; '
          'other receipts are provisional. PayMongo bank transfers are '
          'not counted twice.',
          style: TextStyle(color: HyperionColors.muted, fontSize: 12)),
        if (s.adjustmentsPendingReview != 0) Text(
          'Refunds/adjustments require review: ${_pesos(s.adjustmentsPendingReview)}',
          style: TextStyle(color: HyperionColors.warning, fontSize: 12)),
      ]),
      SizedBox(height: 12),
      if (eightPercent) _panel([
        Text('8% income tax — illustration only', style: TextStyle(
          fontWeight: FontWeight.w900, color: HyperionColors.ink)),
        SizedBox(height: 6),
        Text('Year-to-date tracked receipts: ${_pesos(ytd.trackedReceipts)}'),
        Text('Illustration: 8% × max(₱0, tracked receipts − ₱250,000) = '
          '${_pesos(illustration)}'),
        SizedBox(height: 6),
        Text('This example assumes an eligible purely self-employed '
          'individual who elected the 8% method and qualifies for the '
          '₱250,000 reduction. Do not use as a filing amount. It excludes '
          'refund adjustments, tax credits, previous payments and other '
          'income and relies on provisional source records.',
          style: TextStyle(fontSize: 12, color: HyperionColors.muted)),
      ]),
      if (eightPercent) SizedBox(height: 12),
      _panel([
        Row(children: [
          Expanded(child: Text('Filing log — $periodKey',
            style: TextStyle(color: HyperionColors.ink,
              fontWeight: FontWeight.w900, fontSize: 16))),
          FilledButton.icon(
            onPressed: busy ? null : () => _editTax('Filing',
              proposedPeriod: periodKey),
            icon: Icon(Icons.add), label: Text('Add record')),
        ]),
        SizedBox(height: 7),
        if (entries.isEmpty)
          Text('No filing records saved for this period.',
            style: TextStyle(color: HyperionColors.muted)),
        for (final record in entries) _taxTile(record),
      ]),
      SizedBox(height: 12),
      _panel([
        Text('Filing guide', style: TextStyle(
          fontWeight: FontWeight.w900, color: HyperionColors.ink)),
        SizedBox(height: 7),
        Text(section == 1
          ? 'Common monthly withholding/remittance forms include 0619-E, '
            '0619-F and 1601-C when applicable. Requirements depend on registration.'
          : section == 2
          ? 'Examples include Form 1701Q for eligible individuals and '
            '2551Q or 2550Q where applicable. Q4 treatment differs by tax type.'
          : 'Annual returns vary by taxpayer type (for example, 1701/1701A '
            'for eligible individuals or 1702 variants for corporations).'),
        SizedBox(height: 7),
        Text('These are references, not automatically assigned '
          'obligations. The app does not create or submit official BIR returns, '
          'verify tax credits or generate statutory .DAT attachments.',
          style: TextStyle(fontSize: 12, color: HyperionColors.muted)),
      ]),
      SizedBox(height: 24),
    ]);
  }

  Widget _register(String kind) {
    final records = widget.workspace.taxRecords.where((r) => r.kind == kind).toList()
      ..sort((a,b) => b.date.compareTo(a.date));
    return ListView(padding: const EdgeInsets.all(16), children: [
      _panel([
        Text(kind == '2307' ? '2307 Certificates' : 'e-Invoicing',
          style: TextStyle(color: HyperionColors.ink,
            fontSize: 19, fontWeight: FontWeight.w900)),
        SizedBox(height: 6),
        Text(kind == '2307'
          ? 'Track certificates received from customers or issued to vendors.'
          : 'Maintain a manual invoice reference register and draft list.',
          style: TextStyle(color: HyperionColors.muted, fontSize: 12)),
        SizedBox(height: 13),
        FilledButton.icon(
          onPressed: busy ? null : () => _editTax(kind),
          icon: Icon(Icons.add), label: Text(kind == '2307'
            ? 'Add 2307 record' : 'Add invoice record')),
      ]),
      SizedBox(height: 12),
      _panel([
        Text('${records.length} saved records', style: TextStyle(
          fontWeight: FontWeight.w900, color: HyperionColors.ink)),
        SizedBox(height: 8),
        if (records.isEmpty)
          Text('No records yet. Add an entry manually.',
            style: TextStyle(color: HyperionColors.muted)),
        for (final record in records) _taxTile(record),
      ]),
      SizedBox(height: 12),
      Text(kind == '2307'
        ? 'Records and withheld amounts are user-entered and not validated '
          'against BIR systems. Retain the actual signed 2307 documents.'
        : 'An invoice record here is NOT a BIR-authorized invoice or official '
          'electronic invoice. Hyperion Books does not issue invoice numbers '
          'on your behalf or transmit data to BIR.',
        style: TextStyle(color: HyperionColors.muted, fontSize: 12)),
    ]);
  }

  Widget _taxTile(TaxRecord item) => Card(
    color: HyperionColors.elevated, elevation: 0,
    child: ListTile(
      title: Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis,
        style: TextStyle(color: HyperionColors.ink, fontWeight: FontWeight.w700)),
      subtitle: Text([
        item.reference, item.period, item.direction, item.status,
        DateFormat('MMM d, yyyy').format(item.date),
      ].where((s) => s.isNotEmpty).join(' · ')),
      trailing: PopupMenuButton<String>(onSelected: (action) {
        if (action == 'edit') { _editTax(item.kind, original: item); }
        else { _remove(item); }
      }, itemBuilder: (_) => [
        PopupMenuItem(value: 'edit', child: Text('Edit')),
        PopupMenuItem(value: 'delete', child: Text('Delete')),
      ]),
      onTap: () => _editTax(item.kind, original: item),
    ));

  Widget _metric(String label, int value) => Container(
    width: 205, padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(color: HyperionColors.elevated,
      borderRadius: BorderRadius.circular(12)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: HyperionColors.muted, fontSize: 12)),
      SizedBox(height: 4),
      Text(_pesos(value), style: TextStyle(
        fontWeight: FontWeight.w900, color: HyperionColors.brand, fontSize: 16)),
    ]));
  Widget _panel(List<Widget> children) => Card(child: Padding(
    padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: children)));

  Future<void> _remove(TaxRecord item) async {
    final okay = await showDialog<bool>(context: context, builder: (d) =>
      AlertDialog(title: Text('Delete local record?'),
        content: Text('This removes only the Hyperion Books registry item.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false),
            child: Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(d, true),
            child: Text('Delete')),
        ]));
    if (okay == true) {
      await _save(widget.workspace.copyWith(taxRecords: [
        for (final r in widget.workspace.taxRecords)
          if (r.id != item.id) r,
      ]));
    }
  }

  Future<void> _editTax(String kind, {TaxRecord? original,
      String proposedPeriod = ''}) async {
    var name = original?.name ?? '';
    var ref = original?.reference ?? '';
    var period = original?.period ?? proposedPeriod;
    var status = original?.status ?? 'Draft';
    var direction = original?.direction ?? (kind == '2307' ? 'Incoming' : '');
    var notes = original?.notes ?? '';
    var amount = original == null ? '' :
      (original.amountCentavos / 100).toStringAsFixed(2);
    var date = original?.date ?? DateTime.now();
    DateTime? dueDate = original?.dueDate;
    String? errorText;
    final result = await showDialog<TaxRecord>(context: context,
      builder: (d) => StatefulBuilder(builder: (d, refresh) => AlertDialog(
        title: Text(original == null ? 'New $kind record' : 'Edit $kind record'),
        content: SizedBox(width: 450, child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(initialValue: name,
              maxLength: 180, decoration: InputDecoration(
                labelText: kind == 'Filing' ? 'BIR form / filing name'
                  : kind == '2307' ? 'Customer or vendor' : 'Buyer / recipient'),
              onChanged: (v) => name = v),
            TextFormField(initialValue: ref, maxLength: 160,
              decoration: InputDecoration(labelText: kind == '2307'
                ? 'Certificate reference' : kind == 'Invoice'
                ? 'Invoice reference (manual)' : 'Filing reference / receipt'),
              onChanged: (v) => ref = v),
            TextFormField(initialValue: period, maxLength: 40,
              decoration: InputDecoration(
                labelText: 'Covered period (e.g. 2026-Q3)'),
              onChanged: (v) => period = v),
            SizedBox(height: 12),
            OutlinedButton.icon(onPressed: () async {
              final chosen = await showDatePicker(context: d, initialDate: date,
                firstDate: DateTime(2000), lastDate: DateTime(2100));
              if (chosen != null) refresh(() => date = chosen);
            }, icon: Icon(Icons.event),
              label: Text(DateFormat('MMM d, yyyy').format(date))),
            if (kind == 'Invoice') ...[
              SizedBox(height: 8),
              OutlinedButton.icon(onPressed: () async {
                final chosen = await showDatePicker(context: d,
                  initialDate: dueDate ?? date, firstDate: DateTime(2000),
                  lastDate: DateTime(2100));
                if (chosen != null) refresh(() => dueDate = chosen);
              }, icon: Icon(Icons.schedule_outlined),
                label: Text(dueDate == null ? 'Set payment due date' :
                  'Due: ${DateFormat('MMM d, yyyy').format(dueDate!)}')),
              if (dueDate != null) TextButton(
                onPressed: () => refresh(() => dueDate = null),
                child: Text('Clear due date')),
            ],
            SizedBox(height: 8),
            TextFormField(initialValue: amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: kind == '2307'
                ? 'Tax withheld PHP' : kind == 'Invoice'
                ? 'Invoice amount PHP' : 'Tax paid PHP (if known)'),
              onChanged: (v) => amount = v),
            SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: status, isExpanded: true,
              decoration: InputDecoration(labelText: 'Manually recorded status'),
              items: [
                for (final s in taxRecordStatuses)
                  DropdownMenuItem(value: s, child: Text(s)),
              ], onChanged: (v) => refresh(() => status = v ?? status)),
            if (kind == '2307') ...[
              SizedBox(height: 10),
              DropdownButtonFormField<String>(initialValue: direction,
                decoration: InputDecoration(labelText: 'Certificate direction'),
                items: [
                  DropdownMenuItem(value: 'Incoming', child: Text('Received from customer')),
                  DropdownMenuItem(value: 'Outgoing', child: Text('Issued to vendor')),
                ], onChanged: (v) => refresh(() => direction = v ?? direction)),
            ],
            SizedBox(height: 10),
            TextFormField(initialValue: notes, maxLength: 1500, maxLines: 3,
              decoration: InputDecoration(labelText: 'Notes / source document'),
              onChanged: (v) => notes = v),
            if (errorText != null) Text(errorText!,
              style: TextStyle(color: Colors.red, fontSize: 12)),
          ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d),
            child: Text('Cancel')),
          FilledButton(onPressed: () {
            final parsed = amount.trim().isEmpty ? 0 : parsePesos(amount);
            if (name.trim().isEmpty || name.length > 180 ||
                ref.length > 160 || period.length > 40 || parsed == null ||
                parsed < 0 || notes.length > 1500 ||
                (ref.trim().isNotEmpty && widget.workspace.taxRecords.any((x) =>
                  x.id != original?.id && x.kind == kind &&
                  x.reference.toLowerCase() == ref.trim().toLowerCase()))) {
              refresh(() => errorText = 'Enter a name, valid amount and unique reference.');
              return;
            }
            Navigator.pop(d, TaxRecord(
              id: original?.id ?? Uuid().v4(),
              kind: kind, name: name.trim(), reference: ref.trim(),
              date: date, dueDate: dueDate, period: period.trim(), status: status,
              direction: direction, notes: notes.trim(),
              amountCentavos: parsed));
          }, child: Text('Save locally')),
        ])));
    if (result == null) return;
    await _save(widget.workspace.copyWith(taxRecords: [
      for (final r in widget.workspace.taxRecords)
        if (r.id != result.id) r,
      result,
    ]));
  }

  Future<void> _editReminder([BusinessReminder? original]) async {
    var name = original?.title ?? '';
    var notes = original?.notes ?? '';
    var due = original?.dueDate ?? DateTime.now();
    String? error;
    final result = await showDialog<BusinessReminder>(context: context,
      builder: (d) => StatefulBuilder(builder: (d, refresh) => AlertDialog(
        title: Text(original == null ? 'New reminder' : 'Edit reminder'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(initialValue: name, maxLength: 160,
            decoration: InputDecoration(labelText: 'Task name'),
            onChanged: (v) => name = v),
          TextFormField(initialValue: notes, maxLength: 1000,
            decoration: InputDecoration(labelText: 'Notes'),
            onChanged: (v) => notes = v),
          SizedBox(height: 10),
          OutlinedButton.icon(onPressed: () async {
            final chosen = await showDatePicker(context: d, initialDate: due,
              firstDate: DateTime(2000), lastDate: DateTime(2100));
            if (chosen != null) refresh(() => due = chosen);
          }, icon: Icon(Icons.event),
            label: Text(DateFormat('MMM d, yyyy').format(due))),
          if (error != null) Text(error!,
            style: TextStyle(color: Colors.red)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d),
            child: Text('Cancel')),
          FilledButton(onPressed: () {
            if (name.trim().isEmpty || name.length > 160 || notes.length > 1000) {
              refresh(() => error = 'Provide a valid task title.');
              return;
            }
            Navigator.pop(d, BusinessReminder(
              id: original?.id ?? Uuid().v4(),
              title: name.trim(), notes: notes,
              dueDate: due, completed: original?.completed ?? false));
          }, child: Text('Save')),
        ])));
    if (result == null) return;
    await _save(widget.workspace.copyWith(reminders: [
      for (final r in widget.workspace.reminders)
        if (r.id != result.id) r,
      result,
    ]));
  }
}
