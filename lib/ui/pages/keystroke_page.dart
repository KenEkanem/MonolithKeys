import 'dart:io';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../display/display_layout.dart';
import '../../keystroke/composer.dart';
import '../../keystroke/key_templates.dart';
import '../../log.dart';
import '../../settings/settings.dart';
import '../app.dart';
import '../previews.dart';
import '../theme.dart';
import '../widgets.dart';

class KeystrokePage extends StatelessWidget {
  const KeystrokePage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    final p = Palette.of(context);
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final s = settings.value;
        final colors = keyColorById(s.keyColor);
        return PageFrame(
          title: 'Keystroke',
          children: [
            Section(
              children: [
                ToggleTile(
                  icon: FluentIcons.keyboard_24_regular,
                  title: 'Show keystrokes',
                  subtitle:
                      'Key presses are only used to draw this overlay. Nothing you type is saved or sent anywhere.',
                  value: s.keystrokeEnabled,
                  onChanged: (v) => settings.update((s) => s.keystrokeEnabled = v),
                ),
              ],
            ),
            _DisplaySection(displayId: s.displayId, alignX: s.alignX, alignY: s.alignY),
            Section(
              children: [
                const SectionHeader('Position', icon: FluentIcons.location_24_regular),
                SliderTile(
                  label: 'Horizontal',
                  indent: true,
                  value: s.alignX,
                  valueText: '${(s.alignX * 100).round()}%',
                  onChanged: (v) => settings.update((s) => s.alignX = v),
                ),
                SliderTile(
                  label: 'Vertical',
                  indent: true,
                  value: s.alignY,
                  valueText: '${(s.alignY * 100).round()}%',
                  onChanged: (v) => settings.update((s) => s.alignY = v),
                ),
              ],
            ),
            Section(
              children: [
                const SectionHeader('Template', icon: FluentIcons.keyboard_shift_24_regular),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final t in keyTemplates)
                        ChoiceTile(
                          label: '${t.name} template',
                          selected: s.keyTemplate == t.id,
                          onTap: () => settings.update((s) => s.keyTemplate = t.id),
                          child: SizedBox(
                            width: 196,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  height: 46,
                                  child: FittedBox(
                                    alignment: Alignment.centerLeft,
                                    child: KeystrokePreview(
                                      strokes: [Stroke(previewStroke)],
                                      template: t,
                                      colors: colors,
                                      scale: 0.8,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(t.name, style: TextStyle(fontSize: 13, color: p.textMuted)),
                              ],
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
                const SectionHeader('Colors', icon: FluentIcons.color_24_regular),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [for (final c in keyColors) _ColorSwatch(theme: c, selected: s.keyColor == c.id)],
                  ),
                ),
              ],
            ),
            Section(
              children: [
                SliderTile(
                  icon: FluentIcons.resize_24_regular,
                  label: 'Size',
                  value: s.keyScale.toDouble(),
                  min: Settings.keyScaleRange.min.toDouble(),
                  max: Settings.keyScaleRange.max.toDouble(),
                  divisions: (Settings.keyScaleRange.max - Settings.keyScaleRange.min) ~/ 5,
                  valueText: '${s.keyScale}%',
                  onChanged: (v) => settings.update((s) => s.keyScale = v.round()),
                ),
              ],
            ),
            Section(
              children: [
                ToggleTile(
                  icon: FluentIcons.keyboard_shift_24_regular,
                  title: 'Shortcuts only',
                  subtitle: 'Hide plain typing. Shortcuts and mouse clicks still show.',
                  value: s.shortcutsOnly,
                  onChanged: (v) => settings.update((s) => s.shortcutsOnly = v),
                ),
                ToggleTile(
                  icon: FluentIcons.laptop_24_regular,
                  title: 'Mac symbols',
                  subtitle: 'Add ⌘ ⌃ ⌥ ⇧ next to modifier names',
                  value: s.macSymbols,
                  onChanged: (v) => settings.update((s) => s.macSymbols = v),
                ),
                ToggleTile(
                  icon: FluentIcons.text_case_uppercase_24_regular,
                  title: 'One key at a time',
                  subtitle: 'Replace the previous key instead of showing a sequence',
                  value: s.singleKeyMode,
                  onChanged: (v) => settings.update((s) => s.singleKeyMode = v),
                ),
                ToggleTile(
                  icon: FluentIcons.cursor_click_24_regular,
                  title: 'Mouse clicks and scrolling',
                  subtitle: 'Show clicks and scroll direction with the keys',
                  value: s.showMouseInput,
                  onChanged: (v) => settings.update((s) => s.showMouseInput = v),
                ),
                SettingTile(
                  icon: FluentIcons.timer_24_regular,
                  title: 'Hide after',
                  subtitle: 'How long keys stay on screen after you stop typing',
                  trailing: StepperField(
                    value: s.keyHideAfterMs,
                    min: Settings.keyHideRange.min,
                    max: Settings.keyHideRange.max,
                    step: 100,
                    suffix: 'ms',
                    semanticLabel: 'Hide after, in milliseconds',
                    onChanged: (v) => settings.update((s) => s.keyHideAfterMs = v),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.theme, required this.selected});

  final KeyColorTheme theme;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Tooltip(
      message: theme.name,
      child: Semantics(
        button: true,
        selected: selected,
        label: '${theme.name} keys',
        child: InkWell(
          onTap: () => AppScope.of(context).settings.update((s) => s.keyColor = theme.id),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 46,
            height: 40,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              border: Border.all(color: selected ? p.accent : const Color(0x00000000), width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Container(
              padding: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(color: theme.edge, borderRadius: BorderRadius.circular(5)),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.face,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: p.cardBorder),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lists connected displays as a scaled desktop map. Clicking one moves the
/// keystroke overlay there; the marker shows where it will appear.
class _DisplaySection extends StatefulWidget {
  const _DisplaySection({required this.displayId, required this.alignX, required this.alignY});

  final String? displayId;
  final double alignX;
  final double alignY;

  @override
  State<_DisplaySection> createState() => _DisplaySectionState();
}

class _DisplaySectionState extends State<_DisplaySection> {
  List<DisplayInfo> _displays = const [];
  String? _wallpaper;
  ValueNotifier<int>? _revision;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final revision = AppScope.of(context).displaysRevision;
    if (revision != _revision) {
      _revision?.removeListener(_load);
      _revision = revision..addListener(_load);
      _load();
    }
  }

  @override
  void dispose() {
    _revision?.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final native = AppScope.of(context).native;
    try {
      final displays = await native.displays();
      final wallpaper = await native.wallpaperPath();
      if (mounted) {
        setState(() {
          _displays = displays;
          _wallpaper = wallpaper != null && File(wallpaper).existsSync() ? wallpaper : null;
        });
      }
    } on Object catch (e, st) {
      Log.error('Reading displays failed', e, st);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final settings = AppScope.of(context).settings;
    final selected = resolveDisplay(_displays, widget.displayId);
    return Section(
      children: [
        SectionHeader(
          'Display',
          icon: FluentIcons.desktop_24_regular,
          action: IconButton(
            tooltip: 'Refresh displays',
            icon: const Icon(FluentIcons.arrow_clockwise_24_regular, size: 18),
            onPressed: _load,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 210,
                child: _displays.isEmpty
                    ? Center(
                        child: Text('No displays found', style: TextStyle(color: p.textMuted)),
                      )
                    : LayoutBuilder(
                        builder: (context, box) {
                          final rects = previewLayout(_displays, box.biggest);
                          return Stack(
                            children: [
                              for (final d in _displays)
                                Positioned.fromRect(
                                  rect: rects[d.id]!,
                                  child: _DisplayTile(
                                    display: d,
                                    selected: d.id == selected?.id,
                                    wallpaper: _wallpaper,
                                    alignX: widget.alignX,
                                    alignY: widget.alignY,
                                    onTap: () => settings.update((s) => s.displayId = d.id),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
              ),
              if (selected != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Display ${selected.number}${selected.primary ? ' (main)' : ''} · '
                  '${selected.bounds.width.round()} × ${selected.bounds.height.round()} · ${(selected.scale * 100).round()}% scale',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: p.textMuted),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DisplayTile extends StatelessWidget {
  const _DisplayTile({
    required this.display,
    required this.selected,
    required this.wallpaper,
    required this.alignX,
    required this.alignY,
    required this.onTap,
  });

  final DisplayInfo display;
  final bool selected;
  final String? wallpaper;
  final double alignX;
  final double alignY;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: 'Display ${display.number}',
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            decoration: BoxDecoration(
              color: p.control,
              border: Border.all(color: selected ? p.accent : p.cardBorder, width: selected ? 3 : 1),
              borderRadius: BorderRadius.circular(6),
              image: wallpaper == null
                  ? null
                  : DecorationImage(
                      image: FileImage(File(wallpaper!)),
                      fit: BoxFit.cover,
                      opacity: selected ? 1 : 0.55,
                    ),
            ),
            child: LayoutBuilder(
              builder: (context, box) {
                final marker = Size(box.maxWidth * 0.22, box.maxHeight * 0.08);
                final origin = overlayOrigin(Offset.zero & box.biggest, marker, alignX, alignY, box.maxWidth * 0.02);
                return Stack(
                  children: [
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0x99000000),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          display.number,
                          style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    if (selected)
                      Positioned(
                        left: origin.dx,
                        top: origin.dy,
                        width: marker.width,
                        height: marker.height,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xE616181D),
                            border: Border.all(color: const Color(0xFFFFFFFF), width: 1),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
