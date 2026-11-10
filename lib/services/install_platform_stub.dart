import 'install_status.dart';

/// Used by Flutter's VM widget tests and non-web environments.
InstallStatus currentInstallStatus() => const InstallStatus(
  platform: 'desktop', browser: 'unknown', installed: false, canPrompt: false);

Future<String> requestInstallPrompt() async => 'unavailable';
