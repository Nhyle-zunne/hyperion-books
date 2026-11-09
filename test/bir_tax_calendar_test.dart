import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyperion_books/models/bir_tax_calendar.dart';
import 'package:hyperion_books/models/business_workspace.dart';
import 'package:hyperion_books/ui/tax_calendar_view.dart';

BirCalendarEvent event(int year, String code, String period) =>
  BirTaxCalendar.forDueYear(year).singleWhere(
    (e) => e.code == code && e.period == period);

void main() {
  test('2027 CPALLY-like individual filing examples are generated from BIR rules', () {
    expect(event(2027, 'Inventory List', '2026').due,
      DateTime(2027, 2, 1)); // Jan 30 Saturday -> estimated Monday
    expect(event(2027, '1701A', '2026').due, DateTime(2027, 4, 15));
    expect(event(2027, '1701', '2026').due, DateTime(2027, 4, 15));
    expect(event(2027, '1701Q', 'Q1 2027').opens,
      DateTime(2027, 4, 1));
    expect(event(2027, '1701Q', 'Q1 2027').baseDue,
      DateTime(2027, 5, 15));
    expect(event(2027, '1701Q', 'Q1 2027').due,
      DateTime(2027, 5, 17));
    expect(event(2027, '1701Q', 'Q2 2027').due,
      DateTime(2027, 8, 16));
    expect(event(2027, '1701Q', 'Q3 2027').due,
      DateTime(2027, 11, 15));
  });

  test('2025 annual ITR extension to May 15, 2026 is not lost', () {
    for (final form in ['1701', '1701A', '1701-MS']) {
      final f = event(2026, form, '2025');
      expect(f.due, DateTime(2026, 5, 15));
      expect(f.verifiedException, true);
      expect(f.notes, contains('RMC 30-2026'));
    }
    expect(event(2027, '1701A', '2026').verifiedException, false);
  });

  test('monthly withholding, quarter-end return and year-crossing rules', () {
    expect(event(2027, '1601-C', 'December 2026').due,
      DateTime(2027, 1, 15));
    expect(event(2027, '0619-E', 'January 2027').due,
      DateTime(2027, 2, 10));
    expect(BirTaxCalendar.forDueYear(2027).where(
      (e) => e.code == '0619-E' && e.period == 'March 2027'), isEmpty);
    expect(event(2027, '2550Q', 'Q4 2026').due,
      DateTime(2027, 1, 25));
    expect(event(2027, '1601-EQ', 'Q4 2026').due,
      DateTime(2027, 2, 1));
    expect(event(2027, '1702Q', 'Q3 2027').baseDue,
      DateTime(2027, 11, 29));
    expect(BirTaxCalendar.forDueYear(2027).where(
      (e) => e.code == '1701Q' && e.period == 'Q4 2026'), isEmpty);
  });

  test('future years and audience filters are deterministic and distinct', () {
    for (final y in [2026,2027,2028,2030,2036]) {
      final schedule = BirTaxCalendar.forDueYear(y);
      expect(schedule, isNotEmpty);
      expect(schedule.every((e) => e.due.year == y), true);
      expect(schedule.map((e) => e.id).toSet().length, schedule.length);
      expect(schedule.every((e) => e.sourceUrl.startsWith('https://')),
        true);
    }
    final e = event(2027, '2551Q', 'Q1 2027');
    expect(BirTaxCalendar.visibleFor('Individual (8%)', e), false);
    expect(BirTaxCalendar.visibleFor('Individual (percentage tax)', e), true);
    expect(BirTaxCalendar.visibleFor('All reference forms', e), true);
    expect(tentativeWeekendRoll(DateTime(2027, 5, 15)),
      DateTime(2027, 5, 17));
  });

  testWidgets('calendar shows due grid, year view, filters and personal actions',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 920);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: TaxCalendarView(
        workspace: const BusinessWorkspace(),
        save: (_) async {},
        addReminder: () {},
        addReminderForDate: (_) {},
        editReminder: (_) {},
        addFiling: (_) {},
      ))));
    await tester.pumpAndSettle();
    expect(find.text('Tax Calendar'), findsOneWidget);
    expect(find.text('Due Date Only'), findsOneWidget);
    expect(find.text('Month view'), findsOneWidget);
    expect(find.text('Add reminder'), findsOneWidget);
    expect(find.byType(GridView), findsOneWidget);
    await tester.tap(find.text('Year view'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Deadlines'), findsWidgets);
    expect(find.byType(GridView), findsNothing);
    await tester.tap(find.text('Month view'));
    await tester.pumpAndSettle();
    expect(find.byType(GridView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
