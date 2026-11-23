import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../sound/sound_synth.dart';
import '../app.dart';
import '../theme.dart';
import '../widgets.dart';

class SoundsPage extends StatelessWidget {
  const SoundsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final settings = controller.settings;
    final p = Palette.of(context);
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final s = settings.value;
        return PageFrame(
          title: 'Sounds',
          children: [
            Section(
              children: [
                ToggleTile(
                  icon: FluentIcons.sound_wave_circle_24_regular,
                  title: 'Keystroke sounds',
                  subtitle: 'Play a sound for each key press',
                  value: s.soundsEnabled,
                  onChanged: (v) => settings.update((s) => s.soundsEnabled = v),
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
            RadioGroup<String>(
              groupValue: s.soundTheme,
              onChanged: (id) {
                if (id != null) settings.update((s) => s.soundTheme = id);
              },
              child: Section(
                children: [
                  const SectionHeader('Sound'),
                  for (final theme in soundThemes)
                    SettingTile(
                      title: theme.name,
                      subtitle: theme.description,
                      onTap: () => settings.update((s) => s.soundTheme = theme.id),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Play ${theme.name}',
                            icon: Icon(FluentIcons.play_24_regular, size: 18, color: p.textMuted),
                            onPressed: () => controller.previewSound(theme.id),
                          ),
                          Radio<String>(value: theme.id),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
