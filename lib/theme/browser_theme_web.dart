// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Matches Hyperion PWA's theme-color and initial browser backdrop behavior.
/// No data is sent to a server.
void applyBrowserTheme(bool dark) {
  final background = dark ? '#0B1220' : '#EEF2F6';
  html.document.querySelector('meta[name="theme-color"]')
    ?.setAttribute('content', background);
  html.document.documentElement?.setAttribute('data-initial-theme',
    dark ? 'dark' : 'light');
  html.document.body?.style.backgroundColor = background;
}
