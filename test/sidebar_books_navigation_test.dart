import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyperion_books/ui/hyperion_sidebar.dart';

void main() {
  testWidgets('Accounting contains one Books of Accounts shortcut with no redundant entries',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    String? destination;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: HyperionSidebar(
        selected: 'books', onSelect: (route) => destination = route)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Books of Accounts'), findsOneWidget);
    expect(find.text('Journal Entries'), findsNothing);
    expect(find.text('General Ledger'), findsNothing);

    final taxGroup = find.ancestor(
      of: find.text('Tax Filing'), matching: find.byType(ExpansionTile));
    expect(taxGroup, findsOneWidget);
    await tester.ensureVisible(find.text('Tax Filing'));
    await tester.tap(find.text('Tax Filing'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: taxGroup,
      matching: find.text('Books of Accounts')), findsNothing);

    final accountingGroup = find.ancestor(
      of: find.text('Accounting'), matching: find.byType(ExpansionTile));
    expect(accountingGroup, findsOneWidget);
    expect(find.descendant(of: accountingGroup,
      matching: find.text('Books of Accounts')), findsOneWidget);

    await Scrollable.ensureVisible(
      tester.element(find.text('Books of Accounts')),
      alignment: 0.45, duration: const Duration(milliseconds: 120));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Books of Accounts'));
    expect(destination, 'books');
    expect(tester.takeException(), isNull);
  });
}
