import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/book_entry.dart';
import '../models/paymongo_transaction.dart';
import '../models/business_workspace.dart';

Future<void> openRecordSearch(BuildContext context, {
  required List<BookEntry> entries,
  required List<PayMongoTransaction> paymongo,
  required BusinessWorkspace workspace,
  required VoidCallback onEntries,
  required VoidCallback onPayMongo,
  required VoidCallback onTools,
}) => showDialog<void>(context: context,
  builder: (dialog) => _SearchDialog(
    entries: entries, paymongo: paymongo, workspace: workspace,
    onEntries: onEntries, onPayMongo: onPayMongo, onTools: onTools));

class _Hit {
  final String title, detail, type;
  final VoidCallback open;
  _Hit(this.title, this.detail, this.type, this.open);
}

class _SearchDialog extends StatefulWidget {
  final List<BookEntry> entries;
  final List<PayMongoTransaction> paymongo;
  final BusinessWorkspace workspace;
  final VoidCallback onEntries, onPayMongo, onTools;
  const _SearchDialog({required this.entries, required this.paymongo,
    required this.workspace, required this.onEntries,
    required this.onPayMongo, required this.onTools});
  @override State<_SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<_SearchDialog> {
  String query = '', type = 'All';
  @override Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_PH',
      symbol: '₱', decimalDigits: 2);
    String money(int n) => currency.format(n / 100);
    final all = <_Hit>[
      for (final e in widget.entries)
        _Hit(e.kind == EntryKind.expense ? e.description : e.platform,
          '\${e.id} • \${e.dateKey} • \${money(e.amountCentavos)} '
          '• \${e.category} \${e.description}',
          e.kind == EntryKind.expense ? 'Expenses' : 'Payouts',
          widget.onEntries),
      for (final e in widget.paymongo)
        _Hit('PayMongo \${e.type}',
          '\${e.id} • \${DateFormat('yyyy-MM-dd HH:mm').format(e.occurredAt)}'
          ' • \${money(e.grossCentavos)} • \${money(e.netCentavos)}'
          ' • \${e.paymentMethod} \${e.status}',
          'PayMongo', widget.onPayMongo),
      for (final m in widget.workspace.masters)
        _Hit(m.name, '\${m.kind} • \${m.details}', 'Master lists',
          widget.onTools),
      for (final t in widget.workspace.reminders)
        _Hit(t.title,
          'Due \${DateFormat('MMM d, yyyy').format(t.dueDate)} • \${t.notes}',
          'Tax planner', widget.onTools),
    ];
    final needle = query.trim().toLowerCase();
    final filtered = all.where((x) =>
      (type == 'All' || x.type == type) &&
      (needle.isEmpty || ('\${x.title} \${x.detail} \${x.type}')
        .toLowerCase().contains(needle))).take(100).toList();
    return Dialog(insetPadding: const EdgeInsets.all(12),
      child: ConstrainedBox(constraints: const BoxConstraints(
        maxWidth: 660, maxHeight: 650),
        child: Column(children: [
          Padding(padding: const EdgeInsets.all(12),
            child: Row(children: [
              const Icon(Icons.search),
              const SizedBox(width: 8),
              Expanded(child: TextField(autofocus: true,
                onChanged: (v) => setState(() => query = v),
                decoration: const InputDecoration(
                  hintText: 'Search dates, references, amounts...'))),
              IconButton(tooltip: 'Close', onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close)),
            ])),
          SingleChildScrollView(scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final x in [
                'All', 'PayMongo', 'Payouts', 'Expenses',
                'Master lists', 'Tax planner'])
                Padding(padding: const EdgeInsets.only(right: 5),
                  child: ChoiceChip(label: Text(x),
                    selected: type == x,
                    onSelected: (_) => setState(() => type = x))),
            ])),
          const Divider(),
          Expanded(child: filtered.isEmpty
            ? const Center(child: Text('No matching records'))
            : ListView.builder(itemCount: filtered.length,
              itemBuilder: (context, i) {
                final row = filtered[i];
                return ListTile(title: Text(row.title),
                  subtitle: Text('\${row.type} • \${row.detail}',
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () { Navigator.pop(context); row.open(); });
              })),
          Padding(padding: const EdgeInsets.all(9),
            child: Text('\${filtered.length} results (max 100). '
              'Private local search; no uploads.',
              style: const TextStyle(fontSize: 11))),
        ]),
      ));
  }
}
