import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyperion_books/state/books_controller.dart';
import 'package:hyperion_books/models/book_entry.dart';
import 'package:hyperion_books/models/reports.dart';
import 'package:hyperion_books/ui/home.dart';
import 'package:hyperion_books/ui/install_guide_page.dart';

class _ReadyBooks extends BooksController {
  @override bool get loading => false;
  @override bool get ready => true;
  @override String get status => 'Ready';
  @override String get userId => 'local';
  @override List<BookEntry> get entries => const [];
  @override BooksReport get report => BooksReport.fromEntries(entries);
}

void main() {
  testWidgets('mobile uses one hamburger navigation, not a duplicate bottom More',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final controller = _ReadyBooks();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(home: BooksHome(controller: controller)));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byTooltip('Open business navigation'), findsOneWidget);
    expect(find.byTooltip('Search local records'), findsOneWidget);
    expect(find.byTooltip('Quick record'), findsNothing);
    expect(find.byTooltip('Back up your records'), findsNothing);
    expect(find.byIcon(Icons.more_horiz), findsNothing);

    await tester.tap(find.byTooltip('Open business navigation'));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsOneWidget);
    expect(find.text('Backups & Exports'), findsOneWidget);
    final scroll = find.descendant(
      of: find.byType(Drawer), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.text('How to install'),
      140, scrollable: scroll);
    await tester.tap(find.text('How to install'));
    await tester.pumpAndSettle();

    expect(find.byType(Drawer), findsNothing);
    expect(find.byType(InstallGuidePage), findsOneWidget);
    expect(find.byKey(const ValueKey('install-platform-android')),
      findsOneWidget);
    expect(find.byKey(const ValueKey('install-platform-ios')),
      findsOneWidget);
    expect(find.byKey(const ValueKey('install-platform-desktop')),
      findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('install guide has Android, iPhone/iPad and desktop instructions',
      (tester) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: InstallGuidePage(),
    )));
    await tester.pumpAndSettle();

    final android = find.byKey(const ValueKey('install-platform-android'));
    await tester.tap(android);
    await tester.pumpAndSettle();
    expect(find.text('Install on Android'), findsOneWidget);
    expect(find.byKey(const ValueKey('install-browser-button')),
      findsOneWidget);
    // VM tests deliberately have no native browser prompt.
    expect(tester.widget<FilledButton>(
      find.byKey(const ValueKey('install-browser-button'))).onPressed, isNull);

    final ios = find.byKey(const ValueKey('install-platform-ios'));
    await tester.tap(ios);
    await tester.pumpAndSettle();
    expect(find.text('Add to your iPhone or iPad'), findsOneWidget);
    expect(find.byKey(const ValueKey('install-browser-button')), findsNothing);

    final desktop = find.byKey(const ValueKey('install-platform-desktop'));
    await tester.tap(desktop);
    await tester.pumpAndSettle();
    expect(find.text('Install on Windows, Mac, or Linux'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });


}
