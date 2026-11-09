import 'dart:js_interop';
import 'package:flutter/foundation.dart';

// The same CSS 3D loader that Hyperion PWA uses is hosted in web/index.html.
// Calling these browser functions changes only presentation. They never read
// or send any bookkeeping entries, and failures must never block an operation.
@JS('hyperionBooksLoader.start')
external JSNumber _startLoading(JSString label);

@JS('hyperionBooksLoader.stop')
external void _stopLoading(JSNumber token);

@JS('hyperionBooksLoader.pulse')
external void _pulseLoading(JSString label, JSNumber durationMs);

class HyperionLoading {
  const HyperionLoading._();

  static Future<T> whileRunning<T>(String label, Future<T> Function() work) async {
    JSNumber? token;
    if (kIsWeb) {
      try {
        token = _startLoading(label.toJS);
      } catch (_) {
        // A missing browser hook should not prevent saving or exporting.
      }
    }
    try {
      return await work();
    } finally {
      if (token != null) {
        try {
          _stopLoading(token);
        } catch (_) {
          // Only the visual indicator may fail.
        }
      }
    }
  }

  static void pageTransition(String label) {
    if (!kIsWeb) return;
    try {
      _pulseLoading(label.toJS, 480.toJS);
    } catch (_) {
      // Ignore visual-only errors.
    }
  }
}
