import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/book_entry.dart';
import '../models/business_workspace.dart';

const _navy = Color(0xFF042353);
const _ink = Color(0xFF112940);
const _muted = Color(0xFF64758A);
final _currency = NumberFormat.currency(locale: 'en_PH', symbol: '₱');

/// Local purchasing, fixed-asset and payroll reference registers.
/// Entries are never silently added to cash disbursements or book postings.
class OperationRecordsPage extends StatefulWidget {
  final String kind;
  final BusinessWorkspace workspace;
  final Future<void> Function(BusinessWorkspace) save;
  final VoidCallback recordExpense;
  const OperationRecordsPage({super.key, required this.kind,
    required this.workspace, required this.save,
    required this.recordExpense});

  @override State<OperationRecordsPage> createState() => _OperationRecordsPageState();
}

class _OperationRecordsPageState extends State<OperationRecordsPage> {
  String filter = 'All';
  bool saving = false;

  Future<void> _save(BusinessWorkspace next) async {
    if (saving) return;
    setState(() => saving = true);
    try {
      await widget.save(next);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Saved locally. Export your JSON backup regularly.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not save record: $error')));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _edit([BusinessOperationRecord? original]) async {
    var description = original?.description ?? '';
    var reference = original?.reference ?? '';
    var counterparty = original?.counterparty ?? '';
    var status = original?.status ?? 'Draft';
    var notes = original?.notes ?? '';
    var amount = original == null ? '' :
      (original.amountCentavos / 100).toStringAsFixed(2);
    var date = original?.date ?? DateTime.now();
    String? error;
    final item = await showDialog<BusinessOperationRecord>(
      context: context, builder: (d) => StatefulBuilder(
        builder: (ctx, refresh) => AlertDialog(
          title: Text(original == null ? 'Add ${widget.kind}' : 'Edit ${widget.kind}'),
          content: SizedBox(width: 500, child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(initialValue: description, maxLength: 180,
                decoration: InputDecoration(
                  labelText: widget.kind == 'Payroll' ? 'Employee / payroll description' :
                    widget.kind == 'Asset' ? 'Asset description' :
                    'Purchased product / service'),
                onChanged: (v) => description = v),
              TextFormField(initialValue: reference, maxLength: 160,
                decoration: const InputDecoration(
                  labelText: 'Source document / reference (optional)'),
                onChanged: (v) => reference = v),
              TextFormField(initialValue: counterparty, maxLength: 180,
                decoration: InputDecoration(labelText: widget.kind == 'Payroll' ?
                  'Employee / payee' : 'Supplier / vendor'),
                onChanged: (v) => counterparty = v),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(context: ctx,
                    initialDate: date, firstDate: DateTime(2000),
                    lastDate: DateTime(2100));
                  if (picked != null) refresh(() => date = picked);
                },
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(DateFormat('MMM d, yyyy').format(date))),
              const SizedBox(height: 8),
              TextFormField(initialValue: amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount PHP'),
                onChanged: (v) => amount = v),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: status, isExpanded: true,
                decoration: const InputDecoration(labelText: 'Record status'),
                items: [for (final s in businessOperationStatuses)
                  DropdownMenuItem(value: s, child: Text(s))],
                onChanged: (v) => refresh(() => status = v ?? status)),
              const SizedBox(height: 9),
              TextFormField(initialValue: notes, maxLength: 1500, maxLines: 3,
                decoration: const InputDecoration(labelText: 'Notes and supporting documents'),
                onChanged: (v) => notes = v),
              if (error != null) Text(error!,
                style: const TextStyle(color: Colors.red)),
            ]))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
            FilledButton(onPressed: () {
              final parsed = parsePesos(amount.trim());
              final conflict = reference.trim().isNotEmpty &&
                widget.workspace.operations.any((x) =>
                  x.kind == widget.kind && x.id != original?.id &&
                  x.reference.toLowerCase() == reference.trim().toLowerCase());
              if (description.trim().isEmpty || description.length > 180 ||
                  counterparty.length > 180 || reference.length > 160 ||
                  notes.length > 1500 || parsed == null || conflict) {
                refresh(() => error =
                  'Provide a description, valid peso amount and unique reference.');
                return;
              }
              Navigator.pop(ctx, BusinessOperationRecord(
                id: original?.id ?? const Uuid().v4(),
                kind: widget.kind, date: date,
                description: description.trim(),
                reference: reference.trim(),
                counterparty: counterparty.trim(),
                amountCentavos: parsed, status: status, notes: notes.trim()));
            }, child: const Text('Save locally')),
          ],
        )));
    if (item == null) return;
    await _save(widget.workspace.copyWith(operations: [
      for (final previous in widget.workspace.operations)
        if (previous.id != item.id) previous,
      item,
    ]));
  }

  Future<void> _remove(BusinessOperationRecord item) async {
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) =>
      AlertDialog(
        title: const Text('Delete register entry?'),
        content: const Text('The local reference entry will be removed. '
          'Any separately recorded expenses will remain unchanged.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete')),
        ]));
    if (confirmed != true) return;
    await _save(widget.workspace.copyWith(operations: [
      for (final previous in widget.workspace.operations)
        if (previous.id != item.id) previous,
    ]));
  }

  @override Widget build(BuildContext context) {
    final all = widget.workspace.operations.where(
      (e) => e.kind == widget.kind).toList()
      ..sort((a,b) => b.date.compareTo(a.date));
    final records = all.where((x) => filter == 'All' || x.status == filter).toList();
    final total = records.where((x) => x.status != 'Cancelled')
      .fold<int>(0, (n,x) => n + x.amountCentavos);
    final title = widget.kind == 'Asset' ? 'Business Assets' :
      widget.kind == 'Payroll' ? 'Payroll' : 'Purchase Records';
    final subtitle = widget.kind == 'Asset'
      ? 'Track owned equipment, tools and other assets'
      : widget.kind == 'Payroll'
      ? 'Maintain a payroll payment reference register'
      : 'Record supplier purchases and source references';
    return ListView(padding: const EdgeInsets.fromLTRB(16, 18, 16, 50), children: [
      Text(title, style: const TextStyle(color: _ink,
        fontSize: 23, fontWeight: FontWeight.w900)),
      const SizedBox(height: 5),
      Text(subtitle, style: const TextStyle(color: _muted)),
      const SizedBox(height: 12),
      Wrap(spacing: 9, runSpacing: 8, children: [
        FilledButton.icon(onPressed: saving ? null : () => _edit(),
          icon: const Icon(Icons.add), label: Text('Add ${widget.kind}')),
        OutlinedButton.icon(onPressed: widget.recordExpense,
          icon: const Icon(Icons.payments_outlined),
          label: const Text('Record matching cash expense')),
      ]),
      const SizedBox(height: 12),
      Card(child: Padding(padding: const EdgeInsets.all(15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('REGISTER SUMMARY', style: TextStyle(
            color: _muted, fontSize: 11, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(_currency.format(total / 100),
            style: const TextStyle(color: _navy,
              fontWeight: FontWeight.w900, fontSize: 24)),
          Text('${records.length} entries in this view',
            style: const TextStyle(color: _muted, fontSize: 12)),
        ]))),
      const SizedBox(height: 12),
      Wrap(spacing: 7, runSpacing: 5, children: [
        for (final s in ['All', ...businessOperationStatuses])
          ChoiceChip(label: Text(s), selected: filter == s,
            onSelected: (_) => setState(() => filter = s)),
      ]),
      const SizedBox(height: 11),
      if (records.isEmpty) const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: Text('No records in this register yet.'))),
      for (final item in records)
        Card(child: ListTile(
          onTap: () => _edit(item),
          title: Text(item.description,
            style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text([
            DateFormat('MMM d, yyyy').format(item.date), item.status,
            item.counterparty, item.reference,
          ].where((x) => x.isNotEmpty).join(' · '), maxLines: 3),
          trailing: PopupMenuButton<String>(
            tooltip: 'Record actions',
            onSelected: (v) => v == 'edit' ? _edit(item) : _remove(item),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ]),
        )),
      const SizedBox(height: 10),
      const Text('Operating register only. Entries do not post automatically '
        'to the cash disbursements journal, recognize payroll liabilities, '
        'depreciate assets, or move inventory. Record actual paid expenses '
        'separately to avoid unsupported double entries.',
        style: TextStyle(color: _muted, fontSize: 11.5)),
    ]);
  }
}
