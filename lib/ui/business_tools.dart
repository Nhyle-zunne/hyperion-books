import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/business_workspace.dart';
import '../models/book_entry.dart';
import '../models/paymongo_transaction.dart';

class BusinessTools extends StatefulWidget {
  final BusinessWorkspace workspace;
  final List<PayMongoTransaction> transactions;
  final Future<void> Function(BusinessWorkspace) save;
  final Widget backupPage;
  final int initialTab;
  final String initialKind;
  const BusinessTools({super.key, required this.workspace,
    this.transactions = const [], required this.save, required this.backupPage,
    this.initialTab = 0, this.initialKind = 'Customer'});
  @override State<BusinessTools> createState() => _BusinessToolsState();
}

class _BusinessToolsState extends State<BusinessTools> {
  late final TextEditingController name, tin, address, notes;
  late String registration, tax;
  late String kind;

  @override void initState() {
    super.initState();
    kind = businessListKinds.contains(widget.initialKind)
      ? widget.initialKind : 'Customer';
    name = TextEditingController(text: widget.workspace.businessName);
    tin = TextEditingController(text: widget.workspace.businessTin);
    address = TextEditingController(text: widget.workspace.businessAddress);
    notes = TextEditingController(text: widget.workspace.notes);
    registration = widget.workspace.registrationStatus;
    tax = widget.workspace.taxStatus;
  }
  @override void didUpdateWidget(covariant BusinessTools old) {
    super.didUpdateWidget(old);
    if (old.workspace.businessName != widget.workspace.businessName) {
      name.text = widget.workspace.businessName;
    }
    if (old.workspace.businessTin != widget.workspace.businessTin) {
      tin.text = widget.workspace.businessTin;
    }
    if (old.workspace.businessAddress != widget.workspace.businessAddress) {
      address.text = widget.workspace.businessAddress;
    }
    if (old.workspace.notes != widget.workspace.notes) {
      notes.text = widget.workspace.notes;
    }
  }
  @override void dispose() {
    name.dispose(); tin.dispose(); address.dispose(); notes.dispose();
    super.dispose();
  }

  Future<void> persist(BusinessWorkspace next) async {
    try {
      await widget.save(next);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved locally. Back up your records.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')));
      }
    }
  }

  Widget scroll(List<Widget> content) => ListView(
    padding: const EdgeInsets.all(18), children: content);

  @override Widget build(BuildContext context) => DefaultTabController(
    length: 4, initialIndex: widget.initialTab.clamp(0, 3),
    child: Column(children: [
      const Padding(padding: EdgeInsets.all(14), child: Align(
        alignment: Alignment.centerLeft,
        child: Text('Business tools', style: TextStyle(
          fontSize: 22, fontWeight: FontWeight.w900)))),
      const TabBar(isScrollable: true, tabAlignment: TabAlignment.start,
        tabs: [Tab(text: 'My business'), Tab(text: 'Master lists'),
          Tab(text: 'Tax planner'), Tab(text: 'Backups & reports')]),
      Expanded(child: TabBarView(children: [
        profile(), masterList(), planner(), widget.backupPage,
      ])),
    ]));

  Widget profile() => scroll([
    const Text('Business profile', style: TextStyle(
      fontWeight: FontWeight.w800, fontSize: 18)),
    const SizedBox(height: 8),
    const Text('For reference only. Selecting a status does not file a tax '
      'return or update your registration with BIR.'),
    const SizedBox(height: 13),
    TextField(controller: name, maxLength: 180,
      decoration: const InputDecoration(labelText: 'Business name')),
    TextField(controller: tin, maxLength: 40,
      decoration: const InputDecoration(labelText: 'TIN (optional; not verified)')),
    TextField(controller: address, maxLength: 400, maxLines: 2,
      decoration: const InputDecoration(labelText: 'Registered business address (optional)')),
    DropdownButtonFormField<String>(initialValue: registration,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Registration status'),
      items: [for (final x in registrationStatuses)
        DropdownMenuItem(value: x, child: Text(x))],
      onChanged: (v) => setState(() => registration = v ?? 'Not specified')),
    const SizedBox(height: 12),
    DropdownButtonFormField<String>(initialValue: tax,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Tax method (reference only)'),
      items: [for (final x in taxStatuses)
        DropdownMenuItem(value: x, child: Text(x,
          overflow: TextOverflow.ellipsis))],
      onChanged: (v) => setState(() => tax = v ?? 'Not specified')),
    const SizedBox(height: 12),
    TextField(controller: notes, maxLength: 3000, maxLines: 3,
      decoration: const InputDecoration(labelText: 'Private notes')),
    Align(alignment: Alignment.centerLeft,
      child: FilledButton.icon(icon: const Icon(Icons.save_outlined),
        onPressed: () => persist(widget.workspace.copyWith(
          businessName: name.text.trim(),
          businessTin: tin.text.trim(),
          businessAddress: address.text.trim(), notes: notes.text,
          registrationStatus: registration, taxStatus: tax)),
        label: const Text('Save profile'))),
  ]);

  Widget masterList() {
    final items = widget.workspace.masters.where((x) => x.kind == kind).toList();
    final fromSales = <String, PayMongoTransaction>{};
    if (kind == 'Customer') {
      for (final row in widget.transactions.where((t) => t.isPayment)) {
        final email = row.customerEmail.trim().toLowerCase();
        final name = row.customer.trim().toLowerCase();
        if (name.isEmpty && email.isEmpty) continue;
        final key = email.isNotEmpty ? 'email:$email' : 'name:$name';
        fromSales.putIfAbsent(key, () => row);
      }
    }
    return scroll([
      const Text('Master lists', style: TextStyle(
        fontWeight: FontWeight.w800, fontSize: 18)),
      const SizedBox(height: 7),
      const Text('Organize customers, vendors, products and expense categories. '
        'Stock quantities and receivables are not automatically tracked.'),
      const SizedBox(height: 12),
      Wrap(spacing: 7, children: [for (final x in businessListKinds)
        ChoiceChip(label: Text(x), selected: x == kind,
          onSelected: (_) => setState(() => kind = x))]),
      const SizedBox(height: 12),
      Align(alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: () => editItem(null), icon: const Icon(Icons.add),
          label: Text('Add $kind'))),
      const SizedBox(height: 10),
      if (items.isEmpty) Text(kind == 'Customer'
        ? 'No manually saved customer profiles yet.'
        : 'No items yet.'),
      for (final item in items)
        Card(child: ListTile(title: Text(item.name),
          subtitle: Text([
            if (item.email.isNotEmpty) item.email,
            if (item.phone.isNotEmpty) item.phone,
            if (item.tin.isNotEmpty) 'TIN (unverified): ${item.tin}',
            if (item.details.isNotEmpty) item.details,
          ].join(' · ')),
          onTap: () => editItem(item),
          trailing: IconButton(tooltip: 'Delete item',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmMasterDelete(item)))),
      if (kind == 'Customer' && fromSales.isNotEmpty) ...[
        const SizedBox(height: 14),
        const Text('Customers from sales imports',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        const Text('Read-only customer directory derived from your local sales. '
          'Same email is grouped; names without email are indicative only. '
          'These customers are not copied into the manual master list.'),
        const SizedBox(height: 7),
        for (final sale in fromSales.values)
          Card(child: ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(sale.customer.isEmpty ? 'Name not provided' : sale.customer),
            subtitle: Text([
              if (sale.customerEmail.isNotEmpty) sale.customerEmail,
              if (sale.customerPhone.isNotEmpty) sale.customerPhone,
              if (sale.customerAddress.isNotEmpty) sale.customerAddress,
            ].join(' · ')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showDialog<void>(context: context, builder: (d) =>
              AlertDialog(
                title: const Text('Imported buyer details'),
                content: SelectableText([
                  'Name: ${sale.customer}',
                  'Email: ${sale.customerEmail}',
                  'Phone: ${sale.customerPhone}',
                  'Address: ${sale.customerAddress}',
                  'TIN (unverified): ${sale.customerTin}',
                  'Last matching sale: ${sale.id}',
                ].join('\n')),
                actions: [TextButton(onPressed: () => Navigator.pop(d),
                  child: const Text('Close'))],
              )),
          )),
      ],
    ]);
  }

  Future<void> _confirmMasterDelete(BusinessListItem item) async {
    final okay = await showDialog<bool>(context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Delete this list item?'),
        content: const Text('Saved transactions are not deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Delete')),
        ]));
    if (okay != true) return;
    await persist(widget.workspace.copyWith(masters: [
      for (final x in widget.workspace.masters)
        if (x.id != item.id) x,
    ]));
  }

  Future<void> editItem(BusinessListItem? original) async {
    var type = original?.kind ?? kind;
    var label = original?.name ?? '';
    var details = original?.details ?? '';
    var email = original?.email ?? '';
    var phone = original?.phone ?? '';
    var address = original?.address ?? '';
    var buyerTin = original?.tin ?? '';
    var price = original?.priceCentavos == null ? '' :
      (original!.priceCentavos! / 100).toStringAsFixed(2);
    final record = await showDialog<BusinessListItem>(context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: Text(original == null ? 'Add item' : 'Edit item'),
          content: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(initialValue: type,
                items: [for (final x in businessListKinds)
                  DropdownMenuItem(value: x, child: Text(x))],
                onChanged: (v) => refresh(() => type = v ?? type)),
              TextFormField(initialValue: label, maxLength: 160,
                decoration: const InputDecoration(labelText: 'Name'),
                onChanged: (v) => label = v),
              TextFormField(initialValue: details, maxLength: 500,
                decoration: const InputDecoration(labelText: 'Notes'),
                onChanged: (v) => details = v),
              if (type == 'Customer') ...[
                TextFormField(initialValue: email, maxLength: 254,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email (optional; private)'),
                  onChanged: (v) => email = v),
                TextFormField(initialValue: phone, maxLength: 60,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Contact number (optional)'),
                  onChanged: (v) => phone = v),
                TextFormField(initialValue: address, maxLength: 400,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Buyer address (B2B if applicable)'),
                  onChanged: (v) => address = v),
                TextFormField(initialValue: buyerTin, maxLength: 40,
                  decoration: const InputDecoration(
                    labelText: 'Buyer TIN (if applicable; not verified)'),
                  onChanged: (v) => buyerTin = v),
              ],
              if (type == 'Product')
                TextFormField(initialValue: price,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Reference price PHP (optional)'),
                  onChanged: (v) => price = v),
            ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog),
              child: const Text('Cancel')),
            FilledButton(onPressed: () {
              if (label.trim().isEmpty || label.length > 160 ||
                  details.length > 500 || email.length > 254 ||
                  phone.length > 60 || address.length > 400 ||
                  buyerTin.length > 40) {
                return;
              }
              final parsedPrice = type == 'Product' && price.trim().isNotEmpty
                  ? parsePesos(price) : null;
              if (type == 'Product' && price.trim().isNotEmpty &&
                  parsedPrice == null) {
                return;
              }
              Navigator.pop(dialog, BusinessListItem(
                id: original?.id ?? const Uuid().v4(), kind: type,
                name: label.trim(), details: details.trim(),
                email: type == 'Customer' ? email.trim() : '',
                phone: type == 'Customer' ? phone.trim() : '',
                address: type == 'Customer' ? address.trim() : '',
                tin: type == 'Customer' ? buyerTin.trim() : '',
                priceCentavos: parsedPrice));
            }, child: const Text('Save')),
          ])));
    if (record != null) {
      await persist(widget.workspace.copyWith(masters: [
        for (final x in widget.workspace.masters)
          if (x.id != record.id) x,
        record,
      ]));
    }
  }

  Widget planner() {
    final tasks = [...widget.workspace.reminders]
      ..sort((a,b) => a.dueDate.compareTo(b.dueDate));
    return scroll([
      const Text('Tax & compliance planner', style: TextStyle(
        fontWeight: FontWeight.w800, fontSize: 18)),
      const SizedBox(height: 7),
      const Text('Choose your own due dates. This is a checklist, not '
        'an automatic BIR calendar, filing system or notification service.'),
      const SizedBox(height: 10),
      Align(alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: () => editTask(null),
          icon: const Icon(Icons.add_alarm_outlined),
          label: const Text('Add task'))),
      const SizedBox(height: 10),
      if (tasks.isEmpty) const Text('No tasks scheduled.'),
      for (final task in tasks)
        Card(child: ListTile(
          leading: Checkbox(value: task.completed,
            onChanged: (v) => persist(widget.workspace.copyWith(reminders: [
              for (final x in widget.workspace.reminders)
                if (x.id == task.id) x.copyWith(completed: v ?? false)
                else x,
            ]))),
          title: Text(task.title),
          subtitle: Text(DateFormat('MMM d, yyyy').format(task.dueDate)),
          onTap: () => editTask(task),
          trailing: IconButton(tooltip: 'Delete task',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmTaskDelete(task)))),
    ]);
  }

  Future<void> _confirmTaskDelete(BusinessReminder item) async {
    final okay = await showDialog<bool>(context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Delete this reminder?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Delete')),
        ]));
    if (okay != true) return;
    await persist(widget.workspace.copyWith(reminders: [
      for (final x in widget.workspace.reminders)
        if (x.id != item.id) x,
    ]));
  }

  Future<void> editTask(BusinessReminder? original) async {
    var title = original?.title ?? '';
    var description = original?.notes ?? '';
    var date = original?.dueDate ?? DateTime.now();
    final value = await showDialog<BusinessReminder>(context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: Text(original == null ? 'New task' : 'Edit task'),
          content: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min, children: [
              TextFormField(initialValue: title, maxLength: 160,
                decoration: const InputDecoration(labelText: 'Task title'),
                onChanged: (v) => title = v),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(DateFormat('MMM d, yyyy').format(date)),
                onPressed: () async {
                  final selected = await showDatePicker(context: dialog,
                    initialDate: date, firstDate: DateTime(2020),
                    lastDate: DateTime(2100));
                  if (selected != null) refresh(() => date = selected);
                }),
              TextFormField(initialValue: description, maxLength: 1000,
                decoration: const InputDecoration(labelText: 'Notes'),
                onChanged: (v) => description = v),
            ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog),
              child: const Text('Cancel')),
            FilledButton(onPressed: () {
              if (title.trim().isEmpty || title.length > 160 ||
                  description.length > 1000) {
                return;
              }
              Navigator.pop(dialog, BusinessReminder(
                id: original?.id ?? const Uuid().v4(),
                title: title.trim(), notes: description.trim(),
                dueDate: date, completed: original?.completed ?? false));
            }, child: const Text('Save')),
          ])));
    if (value != null) {
      await persist(widget.workspace.copyWith(reminders: [
        for (final x in widget.workspace.reminders)
          if (x.id != value.id) x,
        value,
      ]));
    }
  }
}
