import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/book_entry.dart';

Future<BookEntry?> showEntryEditor(BuildContext context, String userId,
    EntryKind kind, {BookEntry? initial}) {
  return showDialog<BookEntry>(
    context: context,
    builder: (context) => _EntryEditor(userId: userId, kind: kind, initial: initial),
  );
}

class _EntryEditor extends StatefulWidget {
  final String userId;
  final EntryKind kind;
  final BookEntry? initial;
  const _EntryEditor({required this.userId, required this.kind, this.initial});
  @override
  State<_EntryEditor> createState() => _EntryEditorState();
}

class _EntryEditorState extends State<_EntryEditor> {
  late final TextEditingController _amount;
  late final TextEditingController _gross;
  late final TextEditingController _description;
  late DateTime _date;
  late String _platform;
  late String _category;
  String? _error;

  @override
  void initState() {
    super.initState();
    _date = widget.initial?.date ?? DateTime.now();
    _amount = TextEditingController(text: pesoInput(widget.initial?.amountCentavos));
    _gross = TextEditingController(text: pesoInput(widget.initial?.grossCentavos));
    _description = TextEditingController(text: widget.initial?.description ?? '');
    _platform = widget.initial?.platform.isNotEmpty == true ? widget.initial!.platform : 'PayMongo';
    _category = widget.initial?.category.isNotEmpty == true ? widget.initial!.category : 'General';
  }

  @override
  void dispose() {
    _amount.dispose(); _gross.dispose(); _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final choice = await showDatePicker(
      context: context, initialDate: _date,
      firstDate: DateTime(2020), lastDate: DateTime(2100),
      helpText: 'Choose transaction date',
    );
    if (choice != null) setState(() => _date = choice);
  }

  void _save() {
    final amount = parsePesos(_amount.text);
    final gross = _gross.text.trim().isEmpty ? null : parsePesos(_gross.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a positive amount (for example, 1250.50).');
      return;
    }
    if (_gross.text.trim().isNotEmpty && (gross == null || gross < amount)) {
      setState(() => _error = 'Optional gross must be at least the net amount.');
      return;
    }
    if (widget.kind == EntryKind.expense && _description.text.trim().isEmpty) {
      setState(() => _error = 'Enter what the expense was for.');
      return;
    }
    final entry = widget.initial == null
      ? BookEntry.create(
          userId: widget.userId, kind: widget.kind,
          date: _date, platform: widget.kind == EntryKind.payout ? _platform : '',
          description: _description.text,
          category: widget.kind == EntryKind.expense ? _category : '',
          amountCentavos: amount,
          grossCentavos: widget.kind == EntryKind.payout ? gross : null)
      : widget.initial!.markEdited(
          date: _date,
          platform: widget.kind == EntryKind.payout ? _platform : '',
          description: _description.text,
          category: widget.kind == EntryKind.expense ? _category : '',
          amountCentavos: amount,
          grossCentavos: widget.kind == EntryKind.payout ? gross : null);
    Navigator.of(context).pop(entry);
  }

  @override
  Widget build(BuildContext context) {
    final isPayout = widget.kind == EntryKind.payout;
    return Dialog(
      insetPadding: const EdgeInsets.all(14),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(widget.initial == null
              ? (isPayout ? 'Add payout' : 'Add expense')
              : (isPayout ? 'Edit payout' : 'Edit expense'),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text(isPayout ? 'Record the amount actually received.' : 'Record one outgoing payment.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 22),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_month_outlined),
              label: Align(alignment: Alignment.centerLeft,
                child: Text('Date   ${DateFormat('MMMM d, yyyy').format(_date)}')),
              onPressed: _pickDate,
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(17)),
            ),
            const SizedBox(height: 17),
            if (isPayout) ...[
              DropdownButtonFormField<String>(
                initialValue: _platform,
                decoration: const InputDecoration(labelText: 'Payout source'),
                items: const ['PayMongo', 'Google Play'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => _platform = v ?? 'PayMongo'),
              ),
              const SizedBox(height: 17),
            ],
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(prefixText: '₱  ',
                labelText: isPayout ? 'Net payout received' : 'Expense amount',
                hintText: '0.00'),
            ),
            const SizedBox(height: 17),
            TextField(
              controller: _description,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: isPayout ? 'Note (optional)' : 'What was this for?',
                hintText: isPayout ? 'Weekly payout' : 'Supabase subscription'),
            ),
            if (isPayout) ...[
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Gross amount (optional)'),
                subtitle: const Text('Only if shown on your settlement statement'),
                children: [
                  TextField(
                    controller: _gross,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Gross collections before deductions',
                      prefixText: '₱  ', hintText: 'Leave blank if unknown'),
                  ),
                  const SizedBox(height: 9),
                  const Text('When entered, deductions = gross − net. Check the statement: fees, refunds and withholding may need separate treatment.',
                    style: TextStyle(fontSize: 12)),
                ],
              ),
            ] else ...[
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category (optional)'),
                items: const ['General','Software','Advertising','Equipment','Bank fees','Professional services','Other']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => _category = v ?? 'General'),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 25),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'))),
              const SizedBox(width: 12),
              Expanded(child: FilledButton.icon(icon: const Icon(Icons.check),
                onPressed: _save, label: const Text('Save entry'))),
            ]),
          ]),
        ),
      ),
    );
  }
}
