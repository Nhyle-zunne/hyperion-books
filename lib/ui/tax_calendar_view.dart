import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/bir_tax_calendar.dart';
import '../models/business_workspace.dart';
import '../theme/hyperion_theme.dart';

/// A CPALLY-inspired but original, Hyperion-themed BIR reference calendar.
/// All BIR dates are read-only projections; only user-created reminders and
/// filing logs can be saved locally. No BIR submission is performed here.
class TaxCalendarView extends StatefulWidget {
  final BusinessWorkspace workspace;
  final Future<void> Function(BusinessWorkspace) save;
  final VoidCallback addReminder;
  final ValueChanged<BusinessReminder> editReminder;
  final ValueChanged<DateTime> addFiling;
  const TaxCalendarView({super.key, required this.workspace,
    required this.save, required this.addReminder,
    required this.editReminder, required this.addFiling});

  @override State<TaxCalendarView> createState() => _TaxCalendarViewState();
}

class _TaxCalendarViewState extends State<TaxCalendarView> {
  DateTime _viewing = DateTime(DateTime.now().year, DateTime.now().month);
  String _audience = BirTaxCalendar.audiences.first;
  final Set<BirCadence> _types = {...BirCadence.values};
  bool _dueOnly = true;
  bool _yearView = false;
  bool _upcoming = false;
  bool _saving = false;
  final ScrollController _gridX = ScrollController();
  static final _date = DateFormat('MMMM d, yyyy');
  static final _short = DateFormat('MMM d, yyyy');
  static const _months = [
    'January','February','March','April','May','June',
    'July','August','September','October','November','December',
  ];

  @override void dispose() {
    _gridX.dispose();
    super.dispose();
  }

  List<BirCalendarEvent> get _yearEvents =>
    BirTaxCalendar.forDueYear(_viewing.year).where((e) =>
      _types.contains(e.cadence) &&
      BirTaxCalendar.visibleFor(_audience, e)).toList();

  void _changeMonth(int delta) {
    final d = DateTime(_viewing.year, _viewing.month + delta);
    if (d.year < 2020 || d.year > 2100) return;
    setState(() => _viewing = DateTime(d.year, d.month));
  }
  void _setDate(int year, int month) {
    if (year < 2020 || year > 2100) return;
    setState(() => _viewing = DateTime(year, month));
  }

  @override Widget build(BuildContext context) {
    final entries = _yearEvents;
    final selectedMonth = entries.where((d) =>
      d.due.month == _viewing.month).toList();
    final reminders = widget.workspace.reminders.where((r) =>
      r.dueDate.year == _viewing.year &&
      r.dueDate.month == _viewing.month).toList();
    final filings = widget.workspace.taxRecords.where((r) =>
      r.kind == 'Filing' && r.date.year == _viewing.year &&
      r.date.month == _viewing.month).toList();
    final estimated = _viewing.year > 2026;
    return ListView(padding: const EdgeInsets.fromLTRB(13, 12, 13, 38),
      children: [
        Card(child: Padding(padding: const EdgeInsets.all(15),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Tax Calendar', style: TextStyle(fontSize: 21,
              fontWeight: FontWeight.w900, color: HyperionColors.ink)),
            const SizedBox(height: 4),
            Text('BIR reference filing dates and your local reminders',
              style: TextStyle(fontSize: 12, color: HyperionColors.muted)),
            const SizedBox(height: 12),
            Row(children: [
              Icon(Icons.info_outline, color: HyperionColors.warning, size: 19),
              const SizedBox(width: 8),
              Expanded(child: Text(
                estimated
                ? 'Future-year dates are PROJECTED from recurring BIR rules. '
                  'Only weekends are provisionally shifted. Holidays, special '
                  'extensions, eFPS groups and your actual tax obligations must '
                  'be checked in the official BIR calendar.'
                : 'The 2026 BIR calendar is officially announced (RMC 110-2025), '
                  'but this list is a reference subset, not a live certified '
                  'calendar. It includes the 2025 annual ITR extension and '
                  'may omit special advisories or taxpayer-specific deadlines.',
                style: TextStyle(color: HyperionColors.muted, fontSize: 12,
                  height: 1.45))),
            ]),
            const Divider(height: 19),
            Text('TYPE', style: TextStyle(fontSize: 10,
              color: HyperionColors.muted,
              fontWeight: FontWeight.w900, letterSpacing: .6)),
            const SizedBox(height: 7),
            Wrap(spacing: 7, runSpacing: 3,
              crossAxisAlignment: WrapCrossAlignment.center, children: [
                for (final cadence in BirCadence.values)
                  FilterChip(
                    label: Text(_cadence(cadence)),
                    selected: _types.contains(cadence),
                    onSelected: (v) => setState(() {
                      if (v) { _types.add(cadence); }
                      else { _types.remove(cadence); }
                    })),
                FilterChip(
                  avatar: const Icon(Icons.event_available_outlined, size: 17),
                  label: const Text('Due Date Only'),
                  selected: _dueOnly,
                  onSelected: (v) => setState(() => _dueOnly = v)),
              ]),
            const SizedBox(height: 8),
            Wrap(crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10, runSpacing: 5, children: [
                Text('SHOW SCHEDULES FOR', style: TextStyle(fontSize: 10,
                  color: HyperionColors.muted, fontWeight: FontWeight.w900)),
                DropdownButton<String>(
                  isDense: true, value: _audience,
                  items: [
                    for (final a in BirTaxCalendar.audiences)
                      DropdownMenuItem(value: a, child: Text(a)),
                  ],
                  onChanged: (s) => setState(() =>
                    _audience = s ?? BirTaxCalendar.audiences.first)),
              ]),
            if (_audience != 'All reference forms')
              Padding(padding: const EdgeInsets.only(top: 5),
                child: Text('A category filter is not a determination of your '
                  'BIR registration obligations. Similar forms may be alternatives.',
                  style: TextStyle(fontSize: 11, color: HyperionColors.muted))),
          ]))),
        const SizedBox(height: 10),
        Card(child: Padding(padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10, runSpacing: 8, children: [
                Wrap(crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 5, children: [
                    Text('FILING PERIOD', style: TextStyle(
                      color: HyperionColors.muted,
                      fontSize: 10, fontWeight: FontWeight.w900)),
                    DropdownButton<int>(
                      value: _viewing.month, isDense: true,
                      items: [
                        for (var m = 1; m <= 12; m++)
                          DropdownMenuItem(value: m, child: Text(_months[m - 1])),
                      ],
                      onChanged: (m) => _setDate(_viewing.year,
                        m ?? _viewing.month)),
                    DropdownButton<int>(
                      value: _viewing.year, isDense: true,
                      items: [
                        for (final y in <int>{_viewing.year,
                          ...[for (var y = 2025; y <= 2050; y++) y]}.toList()..sort())
                          DropdownMenuItem(value: y, child: Text('$y')),
                      ],
                      onChanged: (y) => _setDate(y ?? _viewing.year,
                        _viewing.month)),
                  ]),
                Wrap(spacing: 4, crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    IconButton(tooltip: 'Previous month', onPressed: () =>
                      _changeMonth(-1), icon: const Icon(Icons.chevron_left)),
                    OutlinedButton(onPressed: () => _setDate(
                      DateTime.now().year, DateTime.now().month),
                      child: const Text('Today')),
                    IconButton(tooltip: 'Next month', onPressed: () =>
                      _changeMonth(1), icon: const Icon(Icons.chevron_right)),
                  ]),
              ]),
            const SizedBox(height: 8),
            Wrap(spacing: 7, runSpacing: 6, children: [
              ChoiceChip(label: const Text('Month view'),
                selected: !_yearView,
                onSelected: (_) => setState(() {
                  _yearView = false; _upcoming = false;
                })),
              ChoiceChip(label: const Text('Year view'),
                selected: _yearView && !_upcoming,
                onSelected: (_) => setState(() {
                  _yearView = true; _upcoming = false;
                })),
              ChoiceChip(label: const Text('Upcoming'),
                selected: _yearView && _upcoming,
                onSelected: (_) => setState(() {
                  _yearView = true; _upcoming = true;
                })),
              OutlinedButton.icon(
                onPressed: widget.addReminder,
                icon: const Icon(Icons.add_alert_outlined, size: 17),
                label: const Text('Add reminder')),
              OutlinedButton.icon(
                onPressed: () => widget.addFiling(_viewing),
                icon: const Icon(Icons.note_add_outlined, size: 17),
                label: const Text('Record filing')),
            ]),
            const SizedBox(height: 13),
            if (!_yearView) _monthGrid(entries) else _yearList(entries),
            const SizedBox(height: 10),
            if (!_yearView) Text(
              '${selectedMonth.length} reference due dates this month'
              ' · ${reminders.length} personal reminders'
              ' · ${filings.length} filing logs',
              style: TextStyle(fontSize: 11, color: HyperionColors.muted)),
          ]))),
        const SizedBox(height: 12),
        if (!_yearView) _monthAgenda(selectedMonth, reminders, filings),
        const SizedBox(height: 10),
        Card(child: Padding(padding: const EdgeInsets.all(13),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Official BIR sources and limitations',
              style: TextStyle(color: HyperionColors.ink,
                fontSize: 14, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('Regular schedules: BIR online sellers guide, withholding '
              'tax circulars and BIR Forms Directory. For 2026: RMC 110-2025. '
              'The 2025 annual ITR was extended to May 15, 2026 '
              '(RMC 30-2026, confirmed by RMC 36-2026).',
              style: TextStyle(color: HyperionColors.muted, fontSize: 11)),
            TextButton.icon(
              onPressed: () => _copy(birCalendarCircular),
              icon: const Icon(Icons.copy_outlined, size: 16),
              label: const Text('Copy official 2026 BIR calendar circular link')),
            TextButton.icon(
              onPressed: () => _copy(birFormsDirectory),
              icon: const Icon(Icons.copy_outlined, size: 16),
              label: const Text('Copy BIR forms directory link')),
            Text('No taxpayer-specific deadlines, holidays, special extensions '
              'or official acknowledgments are retrieved automatically. '
              'This is not a BIR filing service.',
              style: TextStyle(color: HyperionColors.warning, fontSize: 11)),
          ]))),
      ]);
  }

  Widget _monthGrid(List<BirCalendarEvent> events) {
    final first = DateTime(_viewing.year, _viewing.month);
    final days = DateTime(_viewing.year, _viewing.month + 1, 0).day;
    final leading = first.weekday % 7; // Sunday-first, as in CPALLY
    final count = ((days + leading + 6) ~/ 7) * 7;
    final window = [
      for (var i = 0; i < count; i++)
        i < leading || i >= leading + days ? null :
          DateTime(_viewing.year, _viewing.month, i - leading + 1),
    ];
    return LayoutBuilder(builder: (context, size) {
      final w = size.maxWidth < 770 ? 770.0 : size.maxWidth;
      return Scrollbar(
        controller: _gridX, thumbVisibility: true, trackVisibility: true,
        interactive: true, thickness: 9,
        scrollbarOrientation: ScrollbarOrientation.bottom,
        child: SingleChildScrollView(controller: _gridX,
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: w, child: Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(children: [
              Row(children: [
                for (final label in const [
                  'Sun','Mon','Tue','Wed','Thu','Fri','Sat',
                ])
                  Expanded(child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Text(label, textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: HyperionColors.muted)))),
              ]),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisExtent: 122,
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 2),
                itemCount: window.length,
                itemBuilder: (ctx, index) {
                  final d = window[index];
                  return d == null
                    ? Container(color: HyperionColors.background)
                    : _calendarDay(d, events);
                }),
            ])))),
      );
    });
  }

  Widget _calendarDay(DateTime day, List<BirCalendarEvent> events) {
    final due = events.where((e) => _sameDay(e.due, day)).toList();
    final opens = _dueOnly ? <BirCalendarEvent>[] : events.where(
      (e) => _sameDay(e.opens, day)).toList();
    final reminders = widget.workspace.reminders.where(
      (r) => _sameDay(r.dueDate, day)).toList();
    final filings = widget.workspace.taxRecords.where((r) =>
      r.kind == 'Filing' && _sameDay(r.date, day)).toList();
    final today = _sameDay(day, DateTime.now());
    return Material(color: today ? HyperionColors.selected : HyperionColors.card,
      child: InkWell(
        onTap: () => _showDay(day, events),
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(border: Border.all(
            color: today ? HyperionColors.brand : HyperionColors.border,
            width: today ? 1.4 : .6)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${day.day}', style: TextStyle(fontSize: 12,
                color: HyperionColors.ink,
                fontWeight: today ? FontWeight.w900 : FontWeight.w600)),
              const SizedBox(height: 4),
              for (final e in due.take(2))
                _eventPill(e.code, e.cadence),
              if (due.length > 2)
                Text('+${due.length - 2} more due',
                  style: TextStyle(color: HyperionColors.muted, fontSize: 10)),
              if (opens.isNotEmpty && due.isEmpty)
                Text('${opens.length} filing window(s) open',
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: HyperionColors.accent, fontSize: 10)),
              if (reminders.isNotEmpty)
                Text('${reminders.length} reminder(s)',
                  style: TextStyle(color: HyperionColors.warning, fontSize: 10)),
              if (filings.isNotEmpty)
                Text('${filings.length} logged filing(s)',
                  style: TextStyle(color: HyperionColors.success, fontSize: 10)),
            ])),
        )));
  }

  Widget _eventPill(String code, BirCadence cadence) {
    final c = cadence == BirCadence.annual
      ? HyperionColors.brand : cadence == BirCadence.quarterly
      ? HyperionColors.accent : HyperionColors.chartBlue;
    return Padding(padding: const EdgeInsets.only(bottom: 3),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        decoration: BoxDecoration(color: c.withValues(alpha: .13),
          borderRadius: BorderRadius.circular(4)),
        child: Text(code, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 10))));
  }

  Widget _yearList(List<BirCalendarEvent> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final shown = _upcoming
      ? items.where((e) => !e.due.isBefore(today)).toList()
      : items;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('${_viewing.year} Deadlines',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900,
          color: HyperionColors.ink)),
      const SizedBox(height: 4),
      Text(_upcoming ? 'Upcoming from today' : 'Year view — all reference due dates',
        style: TextStyle(fontSize: 11, color: HyperionColors.muted)),
      if (shown.isEmpty)
        const Padding(padding: EdgeInsets.all(22),
          child: Text('No matching future deadlines for this selection.')),
      for (var m = 1; m <= 12; m++)
        if (shown.any((e) => e.due.month == m)) ...[
          const SizedBox(height: 11),
          Text(_months[m - 1],
            style: TextStyle(fontWeight: FontWeight.w900,
              color: HyperionColors.brand, fontSize: 13)),
          for (final event in shown.where((e) => e.due.month == m))
            _deadlineTile(event),
        ],
    ]);
  }

  Widget _monthAgenda(List<BirCalendarEvent> deadlines,
      List<BusinessReminder> reminders, List<TaxRecord> filings) {
    return Card(child: Padding(padding: const EdgeInsets.all(13),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${_viewing.year} Deadlines · ${_months[_viewing.month - 1]}',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900,
            color: HyperionColors.ink)),
        const SizedBox(height: 4),
        Text('Calendar-year reference dates, not taxpayer-specific filing notices',
          style: TextStyle(color: HyperionColors.muted, fontSize: 11)),
        const SizedBox(height: 8),
        if (deadlines.isEmpty)
          const Padding(padding: EdgeInsets.all(15),
            child: Text('No matching reference deadlines this month.')),
        for (final event in deadlines) _deadlineTile(event),
        if (reminders.isNotEmpty || filings.isNotEmpty)
          const Divider(height: 23),
        for (final reminder in reminders)
          ListTile(
            dense: true, leading: Checkbox(
              value: reminder.completed, onChanged: _saving ? null :
                (v) => _saveReminderStatus(reminder, v ?? false)),
            title: Text(reminder.title),
            subtitle: Text('${_short.format(reminder.dueDate)} · Personal reminder'),
            trailing: IconButton(
              onPressed: () => widget.editReminder(reminder),
              tooltip: 'Edit reminder', icon: const Icon(Icons.edit_outlined)),
            onTap: () => widget.editReminder(reminder)),
        for (final filing in filings)
          ListTile(dense: true,
            leading: const Icon(Icons.description_outlined),
            title: Text(filing.name),
            subtitle: Text('${filing.status} · ${_short.format(filing.date)}'
              '${filing.reference.isEmpty ? "" : " · ${filing.reference}"}')),
      ])));
  }

  Widget _deadlineTile(BirCalendarEvent event) =>
    Card(margin: const EdgeInsets.only(top: 6),
      child: ListTile(
        dense: true, onTap: () => _showDeadline(event),
        leading: Icon(Icons.event_outlined, color: HyperionColors.brand),
        title: Text('${event.code} — ${event.name} (${event.period})',
          style: TextStyle(fontSize: 12.5,
            fontWeight: FontWeight.w700, color: HyperionColors.ink)),
        subtitle: Text('Opens: ${_short.format(event.opens)}  ·  '
          'Due: ${_short.format(event.due)}'
          '${event.shiftedForWeekend ? " (weekend estimate)" : ""}',
          style: TextStyle(fontSize: 11, color: HyperionColors.muted)),
        trailing: const Icon(Icons.chevron_right, size: 17),
      ));

  void _showDay(DateTime day, List<BirCalendarEvent> events) {
    final due = events.where((e) => _sameDay(e.due, day)).toList();
    final opens = _dueOnly ? <BirCalendarEvent>[] : events.where(
      (e) => _sameDay(e.opens, day)).toList();
    final reminders = widget.workspace.reminders.where(
      (r) => _sameDay(r.dueDate, day)).toList();
    showModalBottomSheet<void>(
      context: context, isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => SafeArea(child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight:
          MediaQuery.sizeOf(sheet).height * .72),
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(17),
          children: [
            Text(_date.format(day), style: TextStyle(
              fontSize: 19, fontWeight: FontWeight.w900,
              color: HyperionColors.ink)),
            const SizedBox(height: 8),
            if (due.isEmpty && opens.isEmpty && reminders.isEmpty)
              const Text('No scheduled items on this day.'),
            for (final event in due)
              ListTile(
                title: Text('${event.code} · ${event.name}'),
                subtitle: const Text('Reference due date'),
                onTap: () {
                  Navigator.pop(sheet);
                  _showDeadline(event);
                }),
            for (final event in opens)
              ListTile(
                title: Text('${event.code} · ${event.name}'),
                subtitle: const Text('Filing period opens'),
                onTap: () {
                  Navigator.pop(sheet);
                  _showDeadline(event);
                }),
            for (final reminder in reminders)
              ListTile(
                title: Text(reminder.title),
                subtitle: const Text('Personal reminder'),
                onTap: () {
                  Navigator.pop(sheet);
                  widget.editReminder(reminder);
                }),
            OutlinedButton.icon(onPressed: () {
              Navigator.pop(sheet);
              widget.addFiling(day);
            }, icon: const Icon(Icons.note_add_outlined),
              label: const Text('Record a local filing')),
          ]))));
  }

  Future<void> _showDeadline(BirCalendarEvent event) async {
    final hasReminder = widget.workspace.reminders.any(
      (r) => r.id == 'bir-${event.id}');
    await showDialog<void>(context: context, builder: (ctx) =>
      AlertDialog(
        title: Text('${event.code} · ${event.name}'),
        content: SizedBox(width: 520, child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            _detail('Filing period', event.period),
            _detail('Frequency', _cadence(event.cadence)),
            _detail('Applies to', event.applicability),
            _detail('Filing window opens', _date.format(event.opens)),
            _detail('Regular statutory date', _date.format(event.baseDue)),
            _detail('Displayed due date', _date.format(event.due)),
            if (event.shiftedForWeekend)
              _detail('Weekend adjustment',
                'Tentative next weekday; public holidays and BIR notices not applied'),
            if (event.verifiedException)
              _detail('2026 special extension', event.notes),
            if (event.notes.isNotEmpty && !event.verifiedException)
              _detail('Conditions', event.notes),
            const SizedBox(height: 10),
            Text(event.due.year > 2026
              ? 'PROJECTED · The BIR may publish a different date, holiday '
                'shift, or special circular for this year.'
              : 'REFERENCE ONLY · Check the live official BIR calendar before filing.',
              style: TextStyle(color: HyperionColors.warning, fontSize: 12)),
            const SizedBox(height: 9),
            SelectableText(event.sourceUrl, style: TextStyle(
              fontSize: 11, color: HyperionColors.brand)),
          ]))),
        actions: [
          TextButton.icon(onPressed: () => _copy(event.sourceUrl),
            icon: const Icon(Icons.copy_outlined, size: 16),
            label: const Text('Copy BIR source')),
          TextButton.icon(
            onPressed: hasReminder || _saving ? null : () async {
              Navigator.pop(ctx);
              await _saveDeadlineReminder(event);
            },
            icon: const Icon(Icons.notifications_active_outlined, size: 16),
            label: Text(hasReminder ? 'Reminder saved' : 'Save reminder')),
          FilledButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('Close')),
        ]));
  }

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(), style: TextStyle(
        color: HyperionColors.muted,
        fontWeight: FontWeight.w800, fontSize: 10)),
      SelectableText(value, style: const TextStyle(fontSize: 12.5)),
    ]));

  Future<void> _saveDeadlineReminder(BirCalendarEvent event) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final id = 'bir-${event.id}';
      if (widget.workspace.reminders.any((r) => r.id == id)) return;
      await widget.save(widget.workspace.copyWith(reminders: [
        ...widget.workspace.reminders,
        BusinessReminder(id: id,
          title: '${event.code} · ${event.period} — verify BIR filing',
          dueDate: event.due,
          notes: 'Reference estimate; verify the current official BIR '
            'calendar, taxpayer applicability, holidays, eFPS group and '
            'special extensions. Source: ${event.sourceUrl}'),
      ]));
      if (mounted) _message('Reference reminder saved on this device.');
    } catch (error) {
      if (mounted) _message('Could not save reminder: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveReminderStatus(BusinessReminder r, bool completed) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.save(widget.workspace.copyWith(reminders: [
        for (final item in widget.workspace.reminders)
          if (item.id == r.id)
            item.copyWith(completed: completed)
          else item,
      ]));
    } catch (error) {
      if (mounted) _message('Could not save reminder: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _copy(String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) _message('Official source link copied.');
  }

  void _message(String value) => ScaffoldMessenger.of(context)
    .showSnackBar(SnackBar(content: Text(value)));
  static bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
  static String _cadence(BirCadence v) => switch (v) {
    BirCadence.monthly => 'Monthly',
    BirCadence.quarterly => 'Quarterly',
    BirCadence.annual => 'Annual',
  };
}
