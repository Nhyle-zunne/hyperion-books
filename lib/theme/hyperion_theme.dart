import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hyperion PWA's light/dark palette adapted for the Flutter bookkeeping app.
/// Theme preferences are separate from private financial records and remain
/// available when the PWA is offline.
class HyperionColors {
  HyperionColors._();
  static bool _dark = false;
  static bool get isDark => _dark;
  static void useDark(bool value) => _dark = value;

  static Color get background => _dark
    ? const Color(0xFF0B1220) : const Color(0xFFEEF2F6);
  static Color get card => _dark
    ? const Color(0xFF151D2E) : Colors.white;
  static Color get elevated => _dark
    ? const Color(0xFF1C2740) : const Color(0xFFF1F5F9);
  static Color get header => _dark
    ? const Color(0xFF0F1729) : Colors.white;
  static Color get ink => _dark
    ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
  static Color get muted => _dark
    ? const Color(0xFF9BAAC2) : const Color(0xFF64748B);
  static Color get border => _dark
    ? const Color(0xFF34445C) : const Color(0xFFD0D7E2);
  static Color get accent => _dark
    ? const Color(0xFF22C55E) : const Color(0xFF15803D);
  static Color get accentSoft => _dark
    ? const Color(0xFF153F31) : const Color(0xFFE4F4EC);
  static Color get brand => _dark
    ? const Color(0xFFACCDFA) : const Color(0xFF042353);
  static Color get brandFill => _dark
    ? const Color(0xFF22406C) : const Color(0xFF042353);
  static Color get onBrandFill => Colors.white;
  static Color get selected => _dark
    ? const Color(0xFF243858) : const Color(0xFFE8EFFC);
  static Color get danger => _dark
    ? const Color(0xFFFCA39D) : const Color(0xFFB35D55);
  static Color get dangerSoft => _dark
    ? const Color(0xFF4A2A33) : const Color(0xFFFAE9E6);
  static Color get warning => _dark
    ? const Color(0xFFFDAA72) : const Color(0xFFA65A29);
  static Color get success => _dark
    ? const Color(0xFF4ADE80) : const Color(0xFF16754B);
  static Color get chartBlue => _dark
    ? const Color(0xFF93C5FD) : const Color(0xFF3075A6);

  static ThemeData buildTheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final c = ColorScheme.fromSeed(
      seedColor: dark ? const Color(0xFF22C55E) :
        const Color(0xFF15803D),
      brightness: brightness,
      surface: dark ? const Color(0xFF151D2E) : Colors.white,
    );
    final scheme = c.copyWith(
      primary: dark ? const Color(0xFF22C55E) : const Color(0xFF15803D),
      onPrimary: dark ? const Color(0xFF04110A) : Colors.white,
      onSurface: dark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
      outline: dark ? const Color(0xFF34445C) : const Color(0xFFD0D7E2),
      surfaceContainer: dark ? const Color(0xFF1C2740) : const Color(0xFFF1F5F9),
    );
    final text = ThemeData(brightness: brightness, useMaterial3: true)
      .textTheme.apply(bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: text,
      scaffoldBackgroundColor: dark
        ? const Color(0xFF0B1220) : const Color(0xFFEEF2F6),
      appBarTheme: AppBarTheme(
        backgroundColor: dark
          ? const Color(0xFF0F1729) : Colors.white,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: scheme.outline.withValues(alpha: .50)),
          borderRadius: BorderRadius.circular(18)),
      ),
      dividerTheme: DividerThemeData(color: scheme.outline),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface, surfaceTintColor: Colors.transparent),
      popupMenuTheme: PopupMenuThemeData(color: scheme.surface),
      drawerTheme: DrawerThemeData(backgroundColor: scheme.surface),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface, indicatorColor: dark
          ? const Color(0xFF243858) : const Color(0xFFE8EFFC)),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainer,
        selectedColor: dark ? const Color(0xFF243858) :
          const Color(0xFFE4F4EC),
        side: BorderSide(color: scheme.outline)),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15, vertical: 14)),
      iconTheme: IconThemeData(color: scheme.onSurface),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(scheme.onSurface.withValues(alpha: .48)),
        trackColor: WidgetStatePropertyAll(scheme.outline.withValues(alpha: .3))),
    );
  }
}

/// Same two-state behavior as hyperion-pwa: default Light and remember choice.
/// Preferences are deliberately *not* put in bookkeeping JSON backup.
class HyperionThemeController extends ChangeNotifier {
  HyperionThemeController._();
  static final HyperionThemeController instance = HyperionThemeController._();
  static const preferenceKey = 'hyperion-books-ui-theme-v1';

  ThemeMode _mode = ThemeMode.light;
  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _mode = prefs.getString(preferenceKey) == 'dark'
        ? ThemeMode.dark : ThemeMode.light;
    } catch (_) {
      _mode = ThemeMode.light;
    }
    HyperionColors.useDark(isDark);
    notifyListeners();
  }

  Future<void> setMode(ThemeMode next) async {
    if (next == _mode) return;
    _mode = next;
    HyperionColors.useDark(isDark);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(preferenceKey, isDark ? 'dark' : 'light');
    } catch (_) {
      // Remains usable even if browser private mode blocks preferences.
    }
  }

  Future<void> toggle() => setMode(isDark ? ThemeMode.light : ThemeMode.dark);
}

class HyperionThemeToggle extends StatelessWidget {
  final bool showLabel;
  const HyperionThemeToggle({super.key, this.showLabel = false});

  @override Widget build(BuildContext context) {
    final mode = HyperionThemeController.instance;
    return AnimatedBuilder(animation: mode, builder: (context, _) {
      final dark = mode.isDark;
      final title = dark ? 'Light mode' : 'Dark mode';
      if (showLabel) {
        return ListTile(
          dense: true,
          leading: Icon(dark ? Icons.light_mode_outlined :
            Icons.dark_mode_outlined, color: HyperionColors.brand),
          title: Text(title),
          subtitle: Text(dark ? 'Switch to the light appearance' :
            'Switch to the dark appearance'),
          trailing: Switch(value: dark, onChanged: (v) =>
            mode.setMode(v ? ThemeMode.dark : ThemeMode.light)),
          onTap: mode.toggle,
        );
      }
      return IconButton(
        tooltip: 'Switch to ${dark ? "light" : "dark"} mode',
        onPressed: mode.toggle,
        icon: Icon(dark ? Icons.light_mode_outlined :
          Icons.dark_mode_outlined),
      );
    });
  }
}
