import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyperion_books/models/book_entry.dart';
import 'package:hyperion_books/models/reports.dart';
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

void main() {
  Future<void> expectDashboardAtSize(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final fixture = _DashboardFixture();
    addTearDown(fixture.dispose);

    await tester.pumpWidget(MaterialApp(home: BooksHome(controller: fixture)));
    await tester.pumpAndSettle();

    expect(find.text('HYPERION BOOKS'), findsOneWidget);
    expect(find.text('Financial overview'), findsOneWidget);
    expect(find.text('Add payout'), findsOneWidget);
    expect(find.text('Add expense'), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
    expect(tester.takeException(), isNull);
  }

  testWidgets('dashboard renders on a narrow phone without overflow',
      (tester) async => expectDashboardAtSize(tester, const Size(360, 760)));

  testWidgets('dashboard renders on desktop without overflow',
      (tester) async => expectDashboardAtSize(tester, const Size(1280, 900)));
}
