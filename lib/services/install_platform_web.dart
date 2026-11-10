import 'dart:convert';
import 'dart:js_interop';
import 'install_status.dart';

@JS('hyperionBooksInstall.status')
external JSString _browserInstallStatus();

@JS('hyperionBooksInstall.prompt')
external JSPromise<JSString> _browserPromptInstall();

InstallStatus currentInstallStatus() {
  try {
    final raw = jsonDecode(_browserInstallStatus().toDart);
    if (raw is Map<String, dynamic>) return InstallStatus.fromJson(raw);
  } catch (_) {
    // Browsers without the controller still show manual install instructions.
  }
  return const InstallStatus(
    platform: 'desktop', browser: 'unknown',
    installed: false, canPrompt: false);
}

Future<String> requestInstallPrompt() async {
  try {
    // Important: no await before invoking prompt(), as browsers require a
    // direct user gesture for their native installation dialog.
    final result = _browserPromptInstall();
    return (await result.toDart).toDart;
  } catch (_) {
    return 'unavailable';
  }
}
