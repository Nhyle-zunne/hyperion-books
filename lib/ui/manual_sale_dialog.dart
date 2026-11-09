import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/book_entry.dart';
import '../models/paymongo_transaction.dart';

/// Direct receipts (QR Ph, personal bank transfers, wallets, cash).
/// Unlike a platform payout these count as sales immediately on their date.
Future<PayMongoTransaction?> showManualSaleEditor(BuildContext context,
    {PayMongoTransaction? initial}) => showDialog<PayMongoTransaction>(
  context: context,
  builder: (_) => _ManualSaleEditor(initial: initial),
);

class _ManualSaleEditor extends StatefulWidget {
  final PayMongoTransaction? initial;
  const _ManualSaleEditor({this.initial});
  @override
  State<_ManualSaleEditor> createState() => _ManualSaleEditorState();
}

class _ManualSaleEditorState extends State<_ManualSaleEditor> {
  late final TextEditingController _amount;
  late final TextEditingController _fee;
  late final TextEditingController _description;
  late final TextEditingController _reference;
  late final TextEditingController _customer;
  late final TextEditingController _account;
  late final TextEditingController _notes;
  late DateTime _date;
  late String _method;
  String? _error;

  static const methods = [
    'QR Ph', 'Bank Transfer', 'Cash', 'GCash / Maya', 'Other',
  ];

  @override
  void initState() {
    super.initState();
    final item = widget.initial;
    _date = item?.occurredAt ?? DateTime.now();
    _method = item != null && methods.contains(item.paymentMethod)
        ? item.paymentMethod : 'QR Ph';
    _amount = TextEditingController(text: pesoInput(item?.grossCentavos));
    _fee = TextEditingController(text: item == null || item.feeCentavos == 0
        ? '' : pesoInput(-item.feeCentavos));
    _description = TextEditingController(text: item?.description ?? '');
    _reference = TextEditingController(text: item?.reference ?? '');
    _customer = TextEditingController(text: item?.customer ?? '');
    _account = TextEditingController(text: item?.depositAccount ?? '');
    _notes = TextEditingController(text: item?.notes ?? '');
  }

  @override
  void dispose() {
    for (final c in [_amount, _fee, _description, _reference,
      _customer, _account, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final result = await showDatePicker(context: context,
      initialDate: _date, firstDate: DateTime(2020),
      lastDate: DateTime(2100), helpText: 'Date payment was received');
    if (result != null) setState(() => _date = DateTime(result.year,
      result.month, result.day, _date.hour, _date.minute));
  }

  void _save() {
    final gross = parsePesos(_amount.text);
    final fee = _fee.text.trim().isEmpty ? 0 : parsePesos(_fee.text);
    final description = _description.text.trim();
    if (gross == null || gross <= 0) {
      setState(() => _error = 'Enter the sale amount in pesos.');
      return;
    }
    if (fee == null || fee < 0 || fee >= gross) {
      setState(() => _error = 'The optional fee must be less than the sale amount.');
      return;
    }
    if (description.isEmpty || description.length > 180) {
      setState(() => _error = 'Enter the product or service (up to 180 characters).');
      return;
    }
    if (_reference.text.trim().length > 160 ||
        _customer.text.trim().length > 160 ||
        _account.text.trim().length > 160 || _notes.text.trim().length > 1000) {
      setState(() => _error = 'One of the optional fields is too long.');
      return;
    }
    final sale = PayMongoTransaction(
      id: widget.initial?.id ?? 'manual_${const Uuid().v4()}',
      type: 'Payment', status: 'Paid',
      paymentMethod: _method, occurredAt: _date,
      grossCentavos: gross, feeCentavos: -fee,
      vatCentavos: 0, netCentavos: gross - fee,
      source: 'manual',
      reference: _reference.text.trim(),
      description: description,
      customer: _customer.text.trim(),
      depositAccount: _account.text.trim(),
      notes: _notes.text.trim(),
    );
    Navigator.of(context).pop(sale);
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(14),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560, maxHeight: 740),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.initial == null ? 'Add manual sale' : 'Edit manual sale',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Record a payment you received outside PayMongo, such as QR Ph, '
            'a direct personal-bank transfer or cash. Do not enter a sale '
            'that is already included in a sales CSV.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12)),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: _chooseDate,
            icon: const Icon(Icons.calendar_today_outlined),
            label: Align(alignment: Alignment.centerLeft,
              child: Text('Payment received  ·  ${DateFormat('MMM d, yyyy').format(_date)}')),
          ),
          const SizedBox(height: 14),
          TextField(controller: _description,
            maxLength: 180, textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Product / service *', hintText: 'OIC-NW monthly access')),
          const SizedBox(height: 6),
          TextField(controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Gross amount paid *', prefixText: '₱  ', hintText: '0.00')),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _method,
            decoration: const InputDecoration(labelText: 'Payment method *'),
            items: methods.map((method) => DropdownMenuItem(
              value: method, child: Text(method))).toList(),
            onChanged: (value) => setState(() => _method = value ?? 'QR Ph'),
          ),
          const SizedBox(height: 14),
          TextField(controller: _reference,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Payment reference (recommended)',
              hintText: 'Bank / QR transaction reference'),
          ),
          const SizedBox(height: 14),
          TextField(controller: _account,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Received into (optional)',
              hintText: 'Personal BPI account, cash, wallet, etc.')),
          const SizedBox(height: 14),
          TextField(controller: _fee,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Bank / transaction fee (optional)',
              prefixText: '₱  ', hintText: '0.00')),
          const SizedBox(height: 14),
          TextField(controller: _customer,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Customer (optional)',
              hintText: 'Name or internal customer code')),
          const SizedBox(height: 14),
          TextField(controller: _notes,
            maxLines: 2, maxLength: 1000,
            decoration: const InputDecoration(labelText: 'Notes (optional)')),
          const SizedBox(height: 5),
          Text('The paid amount is recorded as sales revenue and a direct '
            'cash/bank receipt, not an extra payout or expense. Customer details '
            'remain in your browser and unencrypted backups.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11)),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(
              color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'))),
            const SizedBox(width: 10),
            Expanded(child: FilledButton.icon(
              onPressed: _save, icon: const Icon(Icons.check),
              label: const Text('Save sale'))),
          ]),
        ]),
      ),
    ),
  );
}
