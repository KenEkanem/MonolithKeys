import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../license/license.dart';
import '../app.dart';
import '../theme.dart';
import '../widgets.dart';

class LicensingPage extends StatefulWidget {
  const LicensingPage({super.key});

  @override
  State<LicensingPage> createState() => _LicensingPageState();
}

class _LicensingPageState extends State<LicensingPage> {
  final _key = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  Future<void> _activate(LicenseService license) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await license.activate(_key.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
      if (error == null) _key.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final license = AppScope.of(context).license;
    final p = Palette.of(context);
    return ListenableBuilder(
      listenable: license,
      builder: (context, _) {
        final state = license.state;
        final (statusText, statusDetail) = switch (state.status) {
          LicenseStatus.unlicensed => ('Not activated', 'Every feature works without a license key.'),
          LicenseStatus.active => (
            'Active',
            state.expiresAt == null
                ? 'Perpetual license, ${state.maskedKey}'
                : 'Valid until ${_date(state.expiresAt!)}, ${state.maskedKey}',
          ),
          LicenseStatus.expired => (
            'Expired',
            'Expired on ${_date(state.expiresAt!)}. Renew to keep receiving updates.',
          ),
        };
        return PageFrame(
          title: 'License',
          children: [
            Section(
              children: [
                SettingTile(
                  icon: state.status == LicenseStatus.active
                      ? FluentIcons.checkmark_circle_24_filled
                      : FluentIcons.key_24_regular,
                  title: statusText,
                  subtitle: statusDetail,
                  trailing: state.key == null
                      ? null
                      : OutlinedButton(onPressed: license.deactivate, child: const Text('Deactivate')),
                ),
              ],
            ),
            if (state.status != LicenseStatus.active)
              Section(
                children: [
                  const SectionHeader('Activate', icon: FluentIcons.key_24_regular),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!license.canActivateOnline)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              UnconfiguredLicenseClient.message,
                              style: TextStyle(color: p.textMuted, fontSize: 13),
                            ),
                          ),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _key,
                                enabled: license.canActivateOnline && !_busy,
                                decoration: const InputDecoration(hintText: 'MK-XXXXX-XXXXX-XXXXX-XXXXX'),
                                onSubmitted: (_) => _activate(license),
                              ),
                            ),
                            const SizedBox(width: 10),
                            FilledButton(
                              onPressed: license.canActivateOnline && !_busy ? () => _activate(license) : null,
                              child: Text(_busy ? 'Activating…' : 'Activate'),
                            ),
                          ],
                        ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(_error!, style: TextStyle(color: p.warning, fontSize: 13)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }

  static String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
