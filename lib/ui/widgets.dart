import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../native/native_host.dart';
import '../settings/settings.dart';
import 'theme.dart';

/// A settings card. Children are separated by hairline dividers.
class Section extends StatelessWidget {
  const Section({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: p.card,
        border: Border.all(color: p.cardBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(indent: 16, endIndent: 16),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Bold heading row inside a [Section], with an optional action on the right.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.icon, this.action});

  final String title;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
    child: Row(
      children: [
        if (icon != null) ...[Icon(icon), const SizedBox(width: 14)],
        Expanded(
          child: Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
        ),
        ?action,
      ],
    ),
  );
}

class SettingTile extends StatelessWidget {
  const SettingTile({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.indent = false,
  });

  final IconData? icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Aligns a secondary row with the text of the row above it.
  final bool indent;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final row = Padding(
      padding: EdgeInsets.fromLTRB(indent ? 50 : 16, 12, 16, 12),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, size: 22), const SizedBox(width: 14)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 14.5, fontWeight: indent ? FontWeight.w400 : FontWeight.w600)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: TextStyle(fontSize: 13, color: p.textMuted)),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 16), trailing!],
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, hoverColor: p.hover, borderRadius: BorderRadius.circular(10), child: row);
  }
}

class ToggleTile extends StatelessWidget {
  const ToggleTile({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.indent = false,
  });

  final IconData? icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool indent;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: SettingTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      indent: indent,
      onTap: () => onChanged(!value),
      trailing: Switch(value: value, onChanged: onChanged),
    ),
  );
}

/// Keys shown in a shortcut, e.g. Ctrl + Alt + Shift + K.
class KeyCombo extends StatelessWidget {
  const KeyCombo(this.keys, {super.key});

  final List<String> keys;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < keys.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Text('+', style: TextStyle(color: p.textMuted)),
            ),
          // Same construction as the overlay caps: a darker edge under the face.
          Container(
            padding: const EdgeInsets.only(bottom: 2),
            decoration: BoxDecoration(color: p.control, borderRadius: BorderRadius.circular(4)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: p.window,
                border: Border.all(color: p.divider),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                keys[i],
                style: TextStyle(fontSize: 12, color: p.textMuted, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// "Enable shortcut" row with the key combination and registration status.
class ShortcutTile extends StatelessWidget {
  const ShortcutTile({
    super.key,
    required this.feature,
    required this.value,
    required this.onChanged,
    required this.status,
  });

  final Feature feature;
  final bool value;
  final ValueChanged<bool> onChanged;
  final HotkeyStatus? status;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return MergeSemantics(
      child: InkWell(
        onTap: () => onChanged(!value),
        hoverColor: p.hover,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(42, 6, 16, 6),
          child: Row(
            children: [
              Checkbox(value: value, onChanged: (v) => onChanged(v ?? false)),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Enable shortcut', style: TextStyle(fontSize: 14.5)),
                    if (value && status == HotkeyStatus.conflict)
                      Text(
                        'Another app is already using this shortcut.',
                        style: TextStyle(fontSize: 12.5, color: p.warning),
                      ),
                  ],
                ),
              ),
              KeyCombo(['Ctrl', 'Alt', 'Shift', shortcutLetters[feature]!]),
            ],
          ),
        ),
      ),
    );
  }
}

class SliderTile extends StatelessWidget {
  const SliderTile({
    super.key,
    this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.valueText,
    this.indent = false,
  });

  final IconData? icon;
  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;
  final String? valueText;
  final bool indent;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(indent ? 50 : 16, 6, 16, 6),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, size: 22), const SizedBox(width: 14)],
          SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 14.5))),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
              semanticFormatterCallback: valueText == null ? null : (_) => valueText!,
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(
              valueText ?? '',
              textAlign: TextAlign.right,
              style: TextStyle(color: p.textMuted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Integer field with up and down buttons, e.g. a delay in milliseconds.
class StepperField extends StatefulWidget {
  const StepperField({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.suffix,
    required this.onChanged,
    required this.semanticLabel,
  });

  final int value;
  final int min;
  final int max;
  final int step;
  final String suffix;
  final ValueChanged<int> onChanged;
  final String semanticLabel;

  @override
  State<StepperField> createState() => _StepperFieldState();
}

class _StepperFieldState extends State<StepperField> {
  late final _text = TextEditingController(text: '${widget.value}');
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(StepperField old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && _text.text != '${widget.value}') _text.text = '${widget.value}';
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _set(int v) {
    final clamped = v.clamp(widget.min, widget.max);
    _text.text = '$clamped';
    if (clamped != widget.value) widget.onChanged(clamped);
  }

  void _commit() => _set(int.tryParse(_text.text) ?? widget.value);

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return SizedBox(
      width: 168,
      child: TextField(
        controller: _text,
        focusNode: _focus,
        textAlign: TextAlign.right,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
        onSubmitted: (_) => _commit(),
        decoration: InputDecoration(
          hintText: widget.semanticLabel,
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.suffix, style: TextStyle(color: p.textMuted)),
              IconButton(
                tooltip: 'Increase',
                visualDensity: VisualDensity.compact,
                icon: const Icon(FluentIcons.chevron_up_24_regular, size: 16),
                onPressed: widget.value >= widget.max ? null : () => _set(widget.value + widget.step),
              ),
              IconButton(
                tooltip: 'Decrease',
                visualDensity: VisualDensity.compact,
                icon: const Icon(FluentIcons.chevron_down_24_regular, size: 16),
                onPressed: widget.value <= widget.min ? null : () => _set(widget.value - widget.step),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Selectable tile used by the template, style and sound pickers.
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({super.key, required this.selected, required this.onTap, required this.label, required this.child});

  final bool selected;
  final VoidCallback onTap;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        hoverColor: p.hover,
        child: Container(
          decoration: BoxDecoration(
            color: selected ? p.accentSoft : p.window,
            border: Border.all(color: selected ? p.accent : p.cardBorder, width: selected ? 2 : 1),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: EdgeInsets.all(selected ? 9 : 10),
          child: ExcludeSemantics(child: child),
        ),
      ),
    );
  }
}

/// Small dropdown for enum-style options.
class OptionDropdown<T> extends StatelessWidget {
  const OptionDropdown({super.key, required this.value, required this.options, required this.onChanged});

  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: p.window,
        border: Border.all(color: p.divider),
        borderRadius: BorderRadius.circular(6),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          focusColor: const Color(0x00000000),
          dropdownColor: p.window,
          borderRadius: BorderRadius.circular(8),
          icon: const Icon(FluentIcons.chevron_down_24_regular, size: 16),
          style: TextStyle(color: p.text, fontSize: 14),
          items: [for (final e in options.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

/// Colour swatch and `#AARRGGBB` value. Clicking opens an editor.
class ColorField extends StatelessWidget {
  const ColorField({super.key, required this.label, required this.color, required this.onChanged, this.enabled = true});

  final String label;
  final Color color;
  final ValueChanged<Color> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: SettingTile(
        title: label,
        indent: true,
        onTap: enabled ? () => _edit(context) : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 20,
              decoration: BoxDecoration(
                color: color,
                border: Border.all(color: p.divider),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 92,
              child: Text(
                colorToHex(color),
                style: TextStyle(
                  fontSize: 13.5,
                  color: p.textMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final picked = await showDialog<Color>(
      context: context,
      builder: (_) => _ColorDialog(title: label, initial: color),
    );
    if (picked != null) onChanged(picked);
  }
}

class _ColorDialog extends StatefulWidget {
  const _ColorDialog({required this.title, required this.initial});

  final String title;
  final Color initial;

  @override
  State<_ColorDialog> createState() => _ColorDialogState();
}

class _ColorDialogState extends State<_ColorDialog> {
  static const _presets = [
    0xFFFFC83D, 0xFFE5484D, 0xFFF76B15, 0xFF22C55E, 0xFF14B8A6, 0xFF3B82F6, //
    0xFF6366F1, 0xFFA855F7, 0xFFEC4899, 0xFFFFFFFF, 0xFF9CA3AF, 0xFF111827,
  ];

  late Color _color = widget.initial;
  late final _hex = TextEditingController(text: colorToHex(widget.initial));

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _set(Color c) => setState(() {
    _color = c;
    _hex.text = colorToHex(c);
  });

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final opacity = _color.a;
    return AlertDialog(
      title: Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final argb in _presets)
                  Semantics(
                    button: true,
                    label: colorToHex(Color(argb)),
                    child: InkWell(
                      onTap: () => _set(Color(argb).withValues(alpha: opacity)),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        width: 40,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Color(argb),
                          border: Border.all(
                            color: _color.withValues(alpha: 1) == Color(argb) ? p.accent : p.divider,
                            width: _color.withValues(alpha: 1) == Color(argb) ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const SizedBox(width: 70, child: Text('Opacity')),
                Expanded(
                  child: Slider(
                    value: opacity,
                    onChanged: (v) => _set(_color.withValues(alpha: v)),
                  ),
                ),
                SizedBox(width: 44, child: Text('${(opacity * 100).round()}%', textAlign: TextAlign.right)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(width: 70, child: Text('Hex')),
                Expanded(
                  child: TextField(
                    controller: _hex,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[#0-9a-fA-F]')),
                      LengthLimitingTextInputFormatter(9),
                    ],
                    onChanged: (v) {
                      final c = colorFromHex(v);
                      if (c != null) setState(() => _color = c);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _color,
                    border: Border.all(color: p.divider),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, _color), child: const Text('Apply')),
      ],
    );
  }
}
