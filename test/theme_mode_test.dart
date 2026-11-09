import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hyperion_books/theme/hyperion_theme.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await HyperionThemeController.instance.load();
  });

  tearDown(() async {
    await HyperionThemeController.instance.setMode(ThemeMode.light);
  });

  test('Light is the default; Dark and Light persist across loads', () async {
    final mode = HyperionThemeController.instance;
    expect(mode.mode, ThemeMode.light);
    expect(HyperionColors.background, const Color(0xFFEEF2F6));
    await mode.setMode(ThemeMode.dark);
    expect(mode.mode, ThemeMode.dark);
    expect(HyperionColors.background, const Color(0xFF0B1220));
    await mode.load();
    expect(mode.mode, ThemeMode.dark);
    await mode.toggle();
    await mode.load();
    expect(mode.mode, ThemeMode.light);
  });

  testWidgets('Toolbar moon/sun switch updates the app appearance',
      (tester) async {
    final model = HyperionThemeController.instance;
    await tester.pumpWidget(AnimatedBuilder(
      animation: model,
      builder: (context, _) => MaterialApp(
        themeMode: model.mode,
        theme: HyperionColors.buildTheme(Brightness.light),
        darkTheme: HyperionColors.buildTheme(Brightness.dark),
        home: const Scaffold(
          body: Center(child: HyperionThemeToggle()),
        ),
      ),
    ));
    expect(find.byTooltip('Switch to dark mode'), findsOneWidget);
    await tester.tap(find.byTooltip('Switch to dark mode'));
    await tester.pumpAndSettle();
    expect(model.mode, ThemeMode.dark);
    expect(find.byTooltip('Switch to light mode'), findsOneWidget);
    expect(Theme.of(tester.element(find.byType(Scaffold))).brightness,
      Brightness.dark);
  });

  testWidgets('Labeled drawer switch reflects the same shared theme state',
      (tester) async {
    final mode = HyperionThemeController.instance;
    await tester.pumpWidget(AnimatedBuilder(
      animation: mode,
      builder: (context, _) => MaterialApp(
        themeMode: mode.mode,
        theme: HyperionColors.buildTheme(Brightness.light),
        darkTheme: HyperionColors.buildTheme(Brightness.dark),
        home: const Scaffold(body: HyperionThemeToggle(showLabel: true)),
      ),
    ));
    expect(find.text('Dark mode'), findsOneWidget);
    await tester.tap(find.text('Dark mode'));
    await tester.pumpAndSettle();
    expect(find.text('Light mode'), findsOneWidget);
    expect(mode.isDark, isTrue);
  });

  test('Dark text and surfaces retain readable contrast', () {
    HyperionColors.useDark(true);
    Color text = HyperionColors.ink;
    Color surface = HyperionColors.card;
    // WCAG contrast, avoiding platform/environment dependencies.
    double lum(Color c) {
      double value(double v) {
        return v <= .04045 ? v / 12.92 :
          math.pow((v + .055) / 1.055, 2.4).toDouble();
      }
      return .2126 * value(c.r) + .7152 * value(c.g) +
        .0722 * value(c.b);
    }
    final a = lum(text), b = lum(surface);
    final ratio = ((a > b ? a : b) + .05) /
      ((a < b ? a : b) + .05);
    expect(ratio, greaterThan(7));
    HyperionColors.useDark(false);
  });
}
