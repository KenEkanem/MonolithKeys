import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../native/native_host.dart';
import '../../settings/settings.dart';
import '../app.dart';
import '../widgets.dart';

class GeneralPage extends StatelessWidget {
  const GeneralPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final settings = controller.settings;
    return ListenableBuilder(
      listenable: Listenable.merge([settings, controller.hotkeys]),
      builder: (context, _) {
        final s = settings.value;
        final status = controller.hotkeys.value;
        return PageFrame(
          title: 'General',
          children: [
            Section(
              children: [
                ToggleTile(
                  icon: FluentIcons.keyboard_24_regular,
                  title: 'Keystroke overlay',
                  subtitle: 'Show the keys you press on screen',
                  value: s.keystrokeEnabled,
                  onChanged: (v) => settings.update((s) => s.keystrokeEnabled = v),
                ),
                ShortcutTile(
                  feature: Feature.keystroke,
                  value: s.keystrokeShortcutEnabled,
                  status: status[Feature.keystroke],
                  onChanged: (v) => settings.update((s) => s.keystrokeShortcutEnabled = v),
                ),
              ],
            ),
            Section(
              children: [
                ToggleTile(
                  icon: FluentIcons.cursor_24_regular,
                  title: 'Cursor highlight',
                  subtitle: 'Draw a highlight around the pointer',
                  value: s.cursorEnabled,
                  onChanged: (v) => settings.update((s) => s.cursorEnabled = v),
                ),
                ShortcutTile(
                  feature: Feature.cursor,
                  value: s.cursorShortcutEnabled,
                  status: status[Feature.cursor],
                  onChanged: (v) => settings.update((s) => s.cursorShortcutEnabled = v),
                ),
              ],
            ),
            Section(
              children: [
                ToggleTile(
                  icon: FluentIcons.sound_wave_circle_24_regular,
                  title: 'Keystroke sounds',
                  subtitle: 'Play a sound for each key press',
                  value: s.soundsEnabled,
                  onChanged: (v) => settings.update((s) => s.soundsEnabled = v),
                ),
                ShortcutTile(
                  feature: Feature.sounds,
                  value: s.soundsShortcutEnabled,
                  status: status[Feature.sounds],
                  onChanged: (v) => settings.update((s) => s.soundsShortcutEnabled = v),
                ),
                SliderTile(
                  icon: FluentIcons.speaker_2_24_regular,
                  label: 'Volume',
                  value: s.soundVolume,
                  valueText: '${(s.soundVolume * 100).round()}%',
                  onChanged: (v) => settings.update((s) => s.soundVolume = v),
                ),
              ],
            ),
            Section(
              children: [
                ToggleTile(
                  icon: FluentIcons.window_24_regular,
                  title: 'Show window on launch',
                  subtitle: 'When off, MonolithKeys starts in the notification area',
                  value: s.showWindowOnLaunch,
                  onChanged: (v) => settings.update((s) => s.showWindowOnLaunch = v),
                ),
                ToggleTile(
                  icon: FluentIcons.power_24_regular,
                  title: 'Start with Windows',
                  subtitle: 'Open in the notification area when you sign in',
                  value: s.startWithWindows,
                  onChanged: (v) => settings.update((s) => s.startWithWindows = v),
                ),
                ToggleTile(
                  icon: FluentIcons.dark_theme_24_regular,
                  title: 'Dark theme',
                  subtitle: 'Use dark colors for this window',
                  value: s.theme == AppTheme.dark,
                  onChanged: (v) => settings.update((s) => s.theme = v ? AppTheme.dark : AppTheme.light),
                ),
              ],
            ),
            Section(
              children: [
                SettingTile(
                  icon: FluentIcons.history_24_regular,
                  title: 'Restore defaults',
                  subtitle: 'Reset every setting to its original value',
                  trailing: const Icon(FluentIcons.chevron_right_24_regular, size: 18),
                  onTap: () => _confirmRestore(context),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmRestore(BuildContext context) async {
    final settings = AppScope.of(context).settings;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore defaults?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        content: const Text(
          'All settings, including colors, templates and shortcuts, go back to their original values. '
          'Your license is not affected.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Restore')),
        ],
      ),
    );
    if (confirmed ?? false) settings.restoreDefaults();
  }
}
