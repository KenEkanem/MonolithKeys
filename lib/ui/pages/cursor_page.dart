import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../cursor/cursor_templates.dart';
import '../../settings/settings.dart';
import '../app.dart';
import '../previews.dart';
import '../widgets.dart';

class CursorPage extends StatelessWidget {
  const CursorPage({super.key});

  static const _placements = {
    CursorPlacement.followPointer: 'Follow pointer',
    CursorPlacement.screenCenter: 'Center of screen',
    CursorPlacement.windowCenter: 'Center of active window',
  };

  static const _animations = {
    ClickAnimation.none: 'None',
    ClickAnimation.pulse: 'Pulse',
    ClickAnimation.ripple: 'Ripple',
    ClickAnimation.shrink: 'Shrink',
  };

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final s = settings.value;
        return PageFrame(
          title: 'Cursor',
          children: [
            Section(
              children: [
                ToggleTile(
                  icon: FluentIcons.cursor_24_regular,
                  title: 'Highlight cursor',
                  subtitle: 'Draw a shape around the pointer so viewers can follow it',
                  value: s.cursorEnabled,
                  onChanged: (v) => settings.update((s) => s.cursorEnabled = v),
                ),
                SettingTile(
                  icon: FluentIcons.target_24_regular,
                  title: 'Position',
                  subtitle: 'Pin the highlight to the middle of the screen or active window, for zoomed recordings',
                  trailing: OptionDropdown(
                    value: s.cursorPlacement,
                    options: _placements,
                    onChanged: (v) => settings.update((s) => s.cursorPlacement = v),
                  ),
                ),
              ],
            ),
            Section(
              children: [
                const SectionHeader('Style'),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final t in cursorTemplates)
                        Tooltip(
                          message: t.name,
                          child: ChoiceTile(
                            label: '${t.name} highlight',
                            selected: s.cursorTemplate == t.id,
                            onTap: () => settings.update((s) => s.cursorTemplate = t.id),
                            child: CustomPaint(
                              size: const Size.square(44),
                              painter: CursorShapePainter(t, s.highlightColor),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            Section(
              children: [
                SliderTile(
                  icon: FluentIcons.resize_24_regular,
                  label: 'Size',
                  value: s.cursorSize.toDouble(),
                  min: Settings.cursorSizeRange.min.toDouble(),
                  max: Settings.cursorSizeRange.max.toDouble(),
                  divisions: (Settings.cursorSizeRange.max - Settings.cursorSizeRange.min) ~/ 4,
                  valueText: '${s.cursorSize} px',
                  onChanged: (v) => settings.update((s) => s.cursorSize = v.round()),
                ),
                SliderTile(
                  icon: FluentIcons.weather_sunny_24_regular,
                  label: 'Glow',
                  value: s.cursorGlow,
                  valueText: '${(s.cursorGlow * 100).round()}%',
                  onChanged: (v) => settings.update((s) => s.cursorGlow = v),
                ),
              ],
            ),
            Section(
              children: [
                SettingTile(
                  icon: FluentIcons.timer_24_regular,
                  title: 'Hide when still',
                  subtitle: 'Fade the highlight after the pointer stops moving. 0 keeps it visible.',
                  trailing: StepperField(
                    value: s.cursorHideAfterMs,
                    min: Settings.cursorHideRange.min,
                    max: Settings.cursorHideRange.max,
                    step: 250,
                    suffix: 'ms',
                    semanticLabel: 'Hide when still, in milliseconds',
                    onChanged: (v) => settings.update((s) => s.cursorHideAfterMs = v),
                  ),
                ),
                SettingTile(
                  icon: FluentIcons.cursor_click_24_regular,
                  title: 'Click animation',
                  trailing: OptionDropdown(
                    value: s.clickAnimation,
                    options: _animations,
                    onChanged: (v) => settings.update((s) => s.clickAnimation = v),
                  ),
                ),
              ],
            ),
            Section(
              children: [
                ToggleTile(
                  icon: FluentIcons.color_24_regular,
                  title: 'Click colors',
                  subtitle: 'Change color while a mouse button is held',
                  value: s.clickColorsEnabled,
                  onChanged: (v) => settings.update((s) => s.clickColorsEnabled = v),
                ),
                ColorField(
                  label: 'Highlight',
                  color: s.highlightColor,
                  onChanged: (c) => settings.update((s) => s.highlightColor = c),
                ),
                ColorField(
                  label: 'Left click',
                  color: s.leftClickColor,
                  enabled: s.clickColorsEnabled,
                  onChanged: (c) => settings.update((s) => s.leftClickColor = c),
                ),
                ColorField(
                  label: 'Right click',
                  color: s.rightClickColor,
                  enabled: s.clickColorsEnabled,
                  onChanged: (c) => settings.update((s) => s.rightClickColor = c),
                ),
                ColorField(
                  label: 'Middle click',
                  color: s.middleClickColor,
                  enabled: s.clickColorsEnabled,
                  onChanged: (c) => settings.update((s) => s.middleClickColor = c),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
