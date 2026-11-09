/// Recurring Philippine BIR filing patterns for a calendar-year taxpayer.
/// These are REFERENCE schedules, not authenticated BIR notices or a
/// determination of a specific taxpayer's obligations. The BIR publishes
/// its official calendar annually, and can extend/change dates by circular.
library;

enum BirCadence { monthly, quarterly, annual }

/// Official source references. Never infer that a projected date is confirmed.
/// 2026 interactive calendar: RMC 110-2025.
/// 2025 annual ITR extension to May 15, 2026: RMC 30-2026.
const birCalendarCircular =
    'https://bir-cdn.bir.gov.ph/BIR/pdf/RMC%20No.%20110-2025.pdf';
const birOnlineSellerGuide =
    'https://bir-cdn.bir.gov.ph/BIR/pdf/TAXPAYERS%20GUIDE%20FOR%20ONLINE%20SELLERS.pdf';
const birFormsDirectory = 'https://www.bir.gov.ph/bir-forms';
const birAnnualExtension =
    'https://bir-cdn.bir.gov.ph/BIR/pdf/RMC%20No.%2036-2026.pdf';
const birWithholdingSchedule =
    'https://bir-cdn.bir.gov.ph/local/pdf/RMC%20No.%20131-2020%20Online%20Sellers.pdf';
const birAnnualWithholding =
    'https://bir-cdn.bir.gov.ph/local/pdf/RMC%20No.%2062-2023.pdf';

class BirCalendarEvent {
  final String code, name, period, applicability, sourceUrl, notes;
  final BirCadence cadence;
  final DateTime opens, baseDue, due;
  final bool verifiedException;

  const BirCalendarEvent({
    required this.code, required this.name, required this.period,
    required this.applicability, required this.sourceUrl,
    required this.cadence, required this.opens,
    required this.baseDue, required this.due,
    this.notes = '', this.verifiedException = false,
  });

  bool get shiftedForWeekend => baseDue != due && !verifiedException;
  bool get isYearSpecific => verifiedException;
  String get id => '$code-$period';
}

/// Weekend rollover is deliberately an INDICATIVE UI convenience.
/// Official BIR advisories, holidays, eFPS group-specific filing dates and
/// extensions can differ. Do not label this an official adjusted due date.
DateTime tentativeWeekendRoll(DateTime day) {
  if (day.weekday == DateTime.saturday) {
    return day.add(const Duration(days: 2));
  }
  if (day.weekday == DateTime.sunday) {
    return day.add(const Duration(days: 1));
  }
  return day;
}

class BirTaxCalendar {
  static List<BirCalendarEvent> forDueYear(int year) {
    if (year < 2020 || year > 2100) return const [];
    final items = <BirCalendarEvent>[];
    void add(String code, String title, BirCadence cadence,
        String period, DateTime opens, DateTime baseDue, String scope,
        {String? source, String notes = '', bool override = false}) {
      // Annual ITR for TY2025 has a specifically documented extension.
      final actual = override ? baseDue : tentativeWeekendRoll(baseDue);
      if (actual.year != year) return;
      items.add(BirCalendarEvent(code: code, name: title,
        cadence: cadence, period: period, opens: opens,
        baseDue: baseDue, due: actual, applicability: scope,
        sourceUrl: source ?? birOnlineSellerGuide,
        notes: notes, verifiedException: override));
    }

    for (final y in [year - 1, year]) {
      // Monthly withholding: not every business is a withholding agent.
      for (var month = 1; month <= 12; month++) {
        final opens = DateTime(y, month + 1);
        final standard = DateTime(y, month + 1, 10);
        final coverage = '${_monthLabel(month)} $y';
        add('1601-C', 'Compensation withholding', BirCadence.monthly,
          coverage, opens,
          month == 12 ? DateTime(y + 1, 1, 15) : standard, 'employer',
          source: birWithholdingSchedule,
          notes: 'Employers withholding compensation tax. eFPS group schedules differ.');
        if (month % 3 != 0) {
          add('0619-E', 'Creditable expanded withholding', BirCadence.monthly,
            coverage, opens, standard, 'withholding',
            source: birWithholdingSchedule,
            notes: 'First two months of each quarter; eFPS due dates vary by group.');
          add('0619-F', 'Final income withholding', BirCadence.monthly,
            coverage, opens, standard, 'withholding',
            source: birWithholdingSchedule,
            notes: 'Only where final withholding applies; eFPS due dates vary.');
        }
      }
      // Individuals use the annual return instead of a Q4 1701Q.
      for (var quarter = 1; quarter <= 4; quarter++) {
        final month = quarter * 3;
        final period = 'Q$quarter $y';
        final opened = DateTime(y, month + 1);
        final vatAndPt = DateTime(y, month + 1, 25);
        add('2550Q', 'Quarterly VAT return', BirCadence.quarterly,
          period, opened, vatAndPt, 'vat',
          notes: 'VAT-registered taxpayers; fiscal quarters may differ.');
        add('2551Q', 'Quarterly percentage tax', BirCadence.quarterly,
          period, opened, vatAndPt, 'percentage',
          notes: 'Only if subject to percentage tax; 8% election can replace it.');
        add('1601-EQ', 'Expanded withholding quarterly return',
          BirCadence.quarterly, period, opened,
          DateTime(y, month + 2, 0), 'withholding',
          source: birWithholdingSchedule,
          notes: 'Quarterly Alphalist of Payees may be required; eFPS rules apply.');
        add('1601-FQ', 'Final withholding quarterly return',
          BirCadence.quarterly, period, opened,
          DateTime(y, month + 2, 0), 'withholding',
          source: birWithholdingSchedule);
        if (quarter <= 3) {
          const days = [0, 15, 15, 15];
          add('1701Q', 'Individual quarterly income tax',
            BirCadence.quarterly, period, opened,
            DateTime(y, quarter == 1 ? 5 : quarter == 2 ? 8 : 11,
              days[quarter]), 'individual',
            notes: 'No fourth-quarter 1701Q; covered by the annual ITR.');
          add('1702Q', 'Corporate quarterly income tax',
            BirCadence.quarterly, period, opened,
            DateTime(y, month + 1, 0).add(const Duration(days: 60)), 'corporate',
            notes: 'For a calendar-year corporation; fiscal-year quarters differ.');
        }
      }
      // Calendar-year annual obligations for the preceding tax year.
      final filingOpen = DateTime(y + 1);
      final normalAnnual = DateTime(y + 1, 4, 15);
      final annualDue = y == 2025 ? DateTime(2026, 5, 15) : normalAnnual;
      const reason = 'The 2025 annual ITR deadline was extended to May 15, 2026 '
          'under BIR RMC 30-2026 (confirmed by RMC 36-2026).';
      for (final form in ['1701A', '1701']) {
        add(form, form == '1701A'
          ? 'Individual annual ITR (8% / OSD)'
          : 'Individual annual ITR (itemized / mixed)',
          BirCadence.annual, '$y', filingOpen, annualDue, 'individual',
          source: y == 2025 ? birAnnualExtension : birOnlineSellerGuide,
          notes: y == 2025 ? reason
            : 'Alternative individual return forms; file only the form applicable to you.',
          override: y == 2025);
      }
      add('1701-MS', 'Micro/small individual annual ITR',
        BirCadence.annual, '$y', filingOpen, annualDue, 'individual',
        source: birAnnualExtension,
        notes: y == 2025
          ? 'Only eligible micro/small individual taxpayers; alternative form. '
            '$reason'
          : 'Only eligible micro/small individual taxpayers; alternative form.',
        override: y == 2025);
      add('1702-RT', 'Corporate annual ITR (calendar year)',
        BirCadence.annual, '$y', filingOpen, normalAnnual, 'corporate',
        notes: 'RT/EX/MX depends on entity classification; fiscal-year deadlines differ.');
      add('Inventory List', 'Annual inventory list',
        BirCadence.annual, '$y', filingOpen, DateTime(y + 1, 1, 30),
        'inventory', notes: 'Only for taxpayers required to submit inventory; '
          'confirm the annual submission requirement and BIR issuances.');
      add('1604-C', 'Compensation annual withholding information',
        BirCadence.annual, '$y', filingOpen, DateTime(y + 1, 1, 31),
        'employer', source: birAnnualWithholding);
      add('2316', 'Provide withholding certificates to employees',
        BirCadence.annual, '$y', filingOpen, DateTime(y + 1, 1, 31),
        'employer', source: birWithholdingSchedule);
      add('1604-E', 'Annual expanded withholding information',
        BirCadence.annual, '$y', filingOpen, DateTime(y + 1, 3, 1),
        'withholding', source: birAnnualWithholding);
      add('1604-F', 'Annual final withholding information',
        BirCadence.annual, '$y', filingOpen, DateTime(y + 1, 1, 31),
        'withholding', source: birAnnualWithholding);
    }
    items.sort((a, b) {
      final byDate = a.due.compareTo(b.due);
      return byDate != 0 ? byDate : a.code.compareTo(b.code);
    });
    return List.unmodifiable(items);
  }

  static String _monthLabel(int month) => const [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ][month];

  static bool visibleFor(String selection, BirCalendarEvent event) {
    switch (selection) {
      case 'All reference forms':
        return true;
      case 'Individual (8%)':
        return event.applicability == 'individual' ||
          event.applicability == 'inventory';
      case 'Individual (percentage tax)':
        return ['individual', 'percentage', 'inventory']
          .contains(event.applicability);
      case 'VAT business':
        return ['individual', 'vat', 'inventory']
          .contains(event.applicability);
      case 'Employer':
        return event.applicability == 'employer';
      case 'Withholding agent':
        return ['employer', 'withholding'].contains(event.applicability);
      case 'Corporation (calendar year)':
        return ['corporate', 'inventory'].contains(event.applicability);
      default:
        return true;
    }
  }

  static const audiences = [
    'All reference forms',
    'Individual (8%)',
    'Individual (percentage tax)',
    'VAT business',
    'Employer',
    'Withholding agent',
    'Corporation (calendar year)',
  ];
}
