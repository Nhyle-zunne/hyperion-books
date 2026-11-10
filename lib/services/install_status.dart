/// Browser installation state, independent of Flutter UI and browser APIs.
class InstallStatus {
  final String platform;
  final String browser;
  final bool installed;
  final bool canPrompt;

  const InstallStatus({
    required this.platform,
    required this.browser,
    required this.installed,
    required this.canPrompt,
  });

  factory InstallStatus.fromJson(Map<String, dynamic> value) => InstallStatus(
    platform: value['platform'] is String
        ? value['platform'] as String : 'desktop',
    browser: value['browser'] is String
        ? value['browser'] as String : 'unknown',
    installed: value['installed'] == true,
    canPrompt: value['canPrompt'] == true,
  );
}
