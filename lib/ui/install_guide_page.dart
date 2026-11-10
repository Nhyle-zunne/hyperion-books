import 'package:flutter/material.dart';
import '../services/install_platform.dart';
import '../services/install_status.dart';
import '../theme/hyperion_theme.dart';

/// How to install the Hyperion Books PWA. Separate from Hyperion Maritime:
/// there is no Android Play Store listing for this bookkeeping application.
class InstallGuidePage extends StatefulWidget {
  const InstallGuidePage({super.key});

  @override
  State<InstallGuidePage> createState() => _InstallGuidePageState();
}

class _InstallGuidePageState extends State<InstallGuidePage>
    with WidgetsBindingObserver {
  late InstallStatus _status;
  late String _platform;
  String? _notice;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _status = currentInstallStatus();
    _platform = const ['android', 'ios', 'desktop'].contains(_status.platform)
        ? _status.platform : 'desktop';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() => _status = currentInstallStatus());
  }

  Future<void> _install() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    // The browser method is called directly from this tap, before any await.
    final result = await requestInstallPrompt();
    if (!mounted) return;
    setState(() {
      _status = currentInstallStatus();
      _busy = false;
      _notice = switch (result) {
        'accepted' => 'Install accepted. Find Hyperion Books on your Home screen or in your apps.',
        'installed' => 'Hyperion Books is already running as an installed app.',
        'dismissed' => 'Installation was dismissed. You can try again from the browser menu.',
        _ => 'Your browser did not open an installation dialog. Use the browser steps below.',
      };
    });
  }

  @override
  Widget build(BuildContext context) => ListView(
    key: const PageStorageKey<String>('hyperion-books-install-guide'),
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 34),
    children: [
      Row(children: [
        Icon(Icons.install_mobile_outlined, color: HyperionColors.brand),
        const SizedBox(width: 10),
        Expanded(child: Text('How to install', style: TextStyle(
          fontSize: 23, fontWeight: FontWeight.w900, color: HyperionColors.ink))),
      ]),
      const SizedBox(height: 5),
      Text('Add Hyperion Books to your device like an app. Use the same website '
        'and keep your bookkeeping on this device.',
        style: TextStyle(color: HyperionColors.muted, height: 1.4)),
      const SizedBox(height: 16),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _choice('android', 'Android', Icons.android),
        _choice('ios', 'iPhone / iPad', Icons.phone_iphone_outlined),
        _choice('desktop', 'PC / Mac', Icons.desktop_windows_outlined),
      ]),
      const SizedBox(height: 14),
      Card(child: Padding(padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(_status.installed
                ? Icons.check_circle_outline : Icons.app_shortcut_outlined,
              size: 21, color: HyperionColors.brand),
            const SizedBox(width: 8),
            Expanded(child: Text(_status.installed
              ? 'Already installed on this device'
              : _status.canPrompt && _platform == _status.platform
                ? 'Ready to install'
                : 'Install using your browser',
              style: TextStyle(fontWeight: FontWeight.w800,
                color: HyperionColors.ink))),
            IconButton(
              tooltip: 'Check install availability',
              icon: const Icon(Icons.refresh, size: 19),
              onPressed: _refresh),
          ]),
          if (_status.installed)
            Text('You are using the installed version of Hyperion Books.',
              style: TextStyle(color: HyperionColors.muted, fontSize: 12))
          else ...[
            Text(_platform == 'ios'
                ? 'Apple devices use the browser Share menu, not an automatic install popup.'
                : _platform != _status.platform
                  ? 'Follow the steps below on the selected device.'
                  : _status.canPrompt
                    ? 'Your browser supports an installation dialog for this website.'
                    : 'Some browsers do not offer an in-page install dialog. '
                      'The steps below work without one.',
              style: TextStyle(color: HyperionColors.muted, fontSize: 12)),
            if (_platform != 'ios') ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const ValueKey('install-browser-button'),
                onPressed: _busy || !_status.canPrompt ||
                        _platform != _status.platform ? null : _install,
                icon: const Icon(Icons.download_outlined),
                label: Text(_busy ? 'Opening installation…' : 'Install Hyperion Books'),
              ),
              if (_platform == _status.platform && !_status.canPrompt)
                Padding(padding: const EdgeInsets.only(top: 8),
                  child: Text('The install button becomes available when this browser '
                    'offers a native prompt. You can still add it using the '
                    'browser menu below.',
                    style: TextStyle(color: HyperionColors.muted,
                      fontSize: 11))),
            ],
          ],
          if (_notice != null) ...[
            const SizedBox(height: 10),
            Text(_notice!, key: const ValueKey('install-notice'),
              style: TextStyle(color: HyperionColors.ink, fontSize: 12)),
          ],
        ]),
      )),
      const SizedBox(height: 12),
      Card(child: Padding(padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_heading(), style: TextStyle(fontSize: 16,
            fontWeight: FontWeight.w900, color: HyperionColors.ink)),
          const SizedBox(height: 12),
          ..._steps().asMap().entries.map((item) => _step(
            item.key + 1, item.value)),
        ]),
      )),
      const SizedBox(height: 12),
      Card(child: Padding(padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline, color: HyperionColors.brand, size: 19),
          const SizedBox(width: 9),
          Expanded(child: Text(
            'Hyperion Books is a separate website app; it does not use the '
            'Hyperion Maritime Google Play listing. Installation makes it '
            'quicker to open, but does not sync local financial records between '
            'devices. Export a JSON backup before changing, clearing, or '
            'replacing your browser or device.',
            style: TextStyle(fontSize: 11.5,
              color: HyperionColors.muted, height: 1.45))),
        ]),
      )),
    ],
  );

  Widget _choice(String value, String title, IconData icon) => ChoiceChip(
    key: ValueKey<String>('install-platform-$value'),
    selected: _platform == value,
    label: Text(title, style: const TextStyle(fontSize: 12)),
    avatar: Icon(icon, size: 17),
    onSelected: (_) => setState(() {
      _platform = value;
      _notice = null;
    }),
  );

  String _heading() => switch (_platform) {
    'android' => 'Install on Android',
    'ios' => 'Add to your iPhone or iPad',
    _ => 'Install on Windows, Mac, or Linux',
  };

  List<String> _steps() => switch (_platform) {
    'android' => [
      'Open hyperion-books in Chrome or Brave on your Android device. '
        'If the link opened inside Facebook, Messenger, or another app, use '
        'Open in browser first.',
      'Open the browser menu (usually ⋮). In Brave or Chrome, look for '
        'Install app or Add to Home screen. In Samsung Internet, look for '
        'Add page to / Add to Home screen.',
      'Choose Install or Add and confirm. The Hyperion Books icon should '
        'appear on your Home screen or in your app list.',
      'If the menu has no installation option, check that the site has '
        'loaded online in an up-to-date Chrome or Brave browser, then reopen '
        'the menu. You can also use the install button above when available.',
    ],
    'ios' => [
      'Open the Hyperion Books website in Safari on your iPhone or iPad. '
        'If it opened in another app, open the page in Safari.',
      'Tap Share. On newer Safari versions, first tap the page menu beside '
        'the address bar, then Share.',
      'Scroll down and choose Add to Home Screen. If missing, open '
        'Edit Actions in the Share sheet to add the option.',
      'Keep the name Hyperion Books, turn on Open as Web App if offered, '
        'then tap Add. Launch it using the new Home screen icon.',
    ],
    _ => [
      'Open Hyperion Books in a current desktop browser, such as Chrome, '
        'Edge, or Brave, on Windows, Mac, or Linux.',
      'Click the Install icon in the address bar if shown, or open the '
        'browser menu. Chrome/Brave may list Install Hyperion Books under '
        'Save and share; Edge may list it under Apps.',
      'Choose Install and confirm. The app can then launch from your '
        'desktop, Dock, launcher, or Start menu.',
      'On Safari for macOS Sonoma or later, use File → Add to Dock '
        '(or Share → Add to Dock, depending on version). If your browser '
        'cannot install apps, use Chrome or Edge.',
    ],
  };

  Widget _step(int number, String description) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CircleAvatar(radius: 13, backgroundColor: HyperionColors.accentSoft,
        child: Text('$number', style: TextStyle(
          fontWeight: FontWeight.w800, fontSize: 11,
          color: HyperionColors.brand))),
      const SizedBox(width: 11),
      Expanded(child: Text(description, style: TextStyle(
        fontSize: 12.5, height: 1.5, color: HyperionColors.ink))),
    ]),
  );
}
