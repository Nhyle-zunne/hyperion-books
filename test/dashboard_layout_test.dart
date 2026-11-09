import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyperion_books/models/book_entry.dart';
import 'package:hyperion_books/models/reports.dart';
import 'package:hyperion_books/models/paymongo_transaction.dart';
import 'package:hyperion_books/state/books_controller.dart';
import 'package:hyperion_books/ui/home.dart';

class _DashboardFixture extends BooksController {
  @override
  bool get loading => false;

  @override
  bool get ready => true;

  @override
  String get status => 'Stored locally on this device';

  @override
  String get userId => 'local';

  @override
  List<BookEntry> get entries => const [];

  @override
  BooksReport get report => BooksReport.fromEntries(entries);
}

class _ImportedDashboardFixture extends _DashboardFixture {
  @override
  List<PayMongoTransaction> get paymongoTransactions => [
    PayMongoTransaction(
      id: 'pay_dashboard_sample', type: 'Payment', status: 'Paid',
      paymentMethod: 'qrph', occurredAt: DateTime(2026, 11, 5, 14, 22),
      grossCentavos: 10000, feeCentavos: -150, vatCentavos: -16,
      netCentavos: 9850,
    ),
  ];
}

void main() {
  Future<void> expectDashboardAtSize(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final originalHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      // ignore: avoid_print
      print('DESKTOP RENDER DIAGNOSTIC: ${details.toString()}');
      originalHandler?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalHandler);

    final fixture = _DashboardFixture();
    addTearDown(fixture.dispose);

    await tester.pumpWidget(MaterialApp(home: BooksHome(controller: fixture)));
    await tester.pumpAndSettle();

    // Desktop now has its own independently scrolling navigation drawer.
    // ignore: avoid_print
    print('DASHBOARD CHECK $size: HYPERION BOOKS=${find.text('HYPERION BOOKS').evaluate().length}, '
      'overview=${find.text('Financial overview').evaluate().length}, '
      'payout=${find.text('Add payout').evaluate().length}, '
      'expense=${find.text('Add expense').evaluate().length}, '
      'images=${find.byType(Image).evaluate().length}');
    expect(find.text('HYPERION BOOKS'), findsOneWidget);
    expect(find.text('Financial overview'), findsOneWidget);
    expect(find.text('Add payout'), findsOneWidget);
    expect(find.text('Add expense'), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
    final layoutError = tester.takeException();
    // ignore: avoid_print
    print('DASHBOARD LAYOUT ERROR: $layoutError');
    expect(layoutError, isNull);
  }

  testWidgets('dashboard renders on a narrow phone without overflow',
      (tester) async => expectDashboardAtSize(tester, const Size(360, 760)));

  testWidgets('dashboard renders on desktop without overflow',
      (tester) async => expectDashboardAtSize(tester, const Size(1280, 900)));
  testWidgets('imported sales CSV activity appears on dashboard',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final fixture = _ImportedDashboardFixture();
    addTearDown(fixture.dispose);
    await tester.pumpWidget(MaterialApp(home: BooksHome(controller: fixture)));
    await tester.pumpAndSettle();
    // ignore: avoid_print
    print('IMPORT MARKERS: activity=${find.text('Sales activity').evaluate().length}, '
      'gross=${find.text('Gross customer payments').evaluate().length}, '
      'count=${find.text('1 paid transactions').evaluate().length}');
    expect(find.text('Sales activity'), findsOneWidget);
    expect(find.text('PayMongo Activity'), findsNothing);
    expect(find.text('Imported PayMongo activity'), findsNothing);
    expect(find.text('Gross customer payments'), findsOneWidget);
    expect(find.text('1 paid transactions'), findsOneWidget);
    final dashboard = find.descendant(
      of: find.byKey(const PageStorageKey<String>('hyperion-dashboard')),
      matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(
      find.text('Business performance'), 360,
      scrollable: dashboard);
    expect(find.text('Business performance'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Bank and cash movements'), 360,
      scrollable: dashboard);
    expect(find.text('Bank and cash movements'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

}
