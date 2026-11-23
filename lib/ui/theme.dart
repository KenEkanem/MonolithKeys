import 'package:material_ui/material_ui.dart';

/// Colour tokens for the settings window. Every widget reads colours from
/// here so light and dark stay complete and consistent.
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.window,
    required this.sidebar,
    required this.card,
    required this.cardBorder,
    required this.divider,
    required this.text,
    required this.textMuted,
    required this.accent,
    required this.accentSoft,
    required this.onAccent,
    required this.hover,
    required this.control,
    required this.warning,
  });

  final Color window;
  final Color sidebar;
  final Color card;
  final Color cardBorder;
  final Color divider;
  final Color text;
  final Color textMuted;
  final Color accent;

  /// Tinted background for selected, non-primary elements.
  final Color accentSoft;
  final Color onAccent;
  final Color hover;

  /// Off-state fill for switches, slider tracks and key chips.
  final Color control;
  final Color warning;

  static const light = Palette(
    window: Color(0xFFFFFFFF),
    sidebar: Color(0xFFFAFAFB),
    card: Color(0xFFF5F6F8),
    cardBorder: Color(0xFFEAECEF),
    divider: Color(0xFFE4E6EA),
    text: Color(0xFF1B1D21),
    textMuted: Color(0xFF626873),
    accent: Color(0xFF1F66F2),
    accentSoft: Color(0xFFE6EEFE),
    onAccent: Color(0xFFFFFFFF),
    hover: Color(0x0A000000),
    control: Color(0xFFDADDE2),
    warning: Color(0xFF9D5D00),
  );

  static const dark = Palette(
    window: Color(0xFF1C1D21),
    sidebar: Color(0xFF18191C),
    card: Color(0xFF25272B),
    cardBorder: Color(0xFF2E3035),
    divider: Color(0xFF34373C),
    text: Color(0xFFECEDEF),
    textMuted: Color(0xFFA0A5AE),
    accent: Color(0xFF4C8DFF),
    accentSoft: Color(0xFF1F2E4D),
    onAccent: Color(0xFFFFFFFF),
    hover: Color(0x0FFFFFFF),
    control: Color(0xFF41444A),
    warning: Color(0xFFFFC65C),
  );

  static Palette of(BuildContext context) => Theme.of(context).extension<Palette>()!;

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(Palette? other, double t) => t < 0.5 || other == null ? this : other;
}

ThemeData buildTheme(Palette p, Brightness brightness) {
  final base = ThemeData(brightness: brightness, useMaterial3: true);
  final selected = WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected));
  return base.copyWith(
    extensions: [p],
    scaffoldBackgroundColor: p.window,
    splashFactory: NoSplash.splashFactory,
    colorScheme: base.colorScheme.copyWith(
      primary: p.accent,
      onPrimary: p.onAccent,
      surface: p.window,
      onSurface: p.text,
      outline: p.divider,
      surfaceContainerHigh: p.card,
    ),
    textTheme: base.textTheme.apply(bodyColor: p.text, displayColor: p.text),
    dividerTheme: DividerThemeData(color: p.divider, thickness: 1, space: 1),
    iconTheme: IconThemeData(color: p.textMuted, size: 20),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Color(0xFFFFFFFF)),
      trackColor: WidgetStateProperty.resolveWith((s) => selected.resolve(s) ? p.accent : p.control),
      trackOutlineColor: const WidgetStatePropertyAll(Color(0x00000000)),
      overlayColor: const WidgetStatePropertyAll(Color(0x00000000)),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => selected.resolve(s) ? p.accent : null),
      side: BorderSide(color: p.textMuted, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 4,
      activeTrackColor: p.accent,
      inactiveTrackColor: p.control,
      thumbColor: p.accent,
      overlayColor: p.accent.withValues(alpha: 0.12),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8, elevation: 0, pressedElevation: 0),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
      trackShape: const RoundedRectSliderTrackShape(),
      tickMarkShape: SliderTickMarkShape.noTickMark,
      showValueIndicator: ShowValueIndicator.never,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.window,
      surfaceTintColor: const Color(0x00000000),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: p.window,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: p.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: p.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: p.accent, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.text,
        side: BorderSide(color: p.divider),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: p.accent)),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 500),
      decoration: BoxDecoration(color: p.text, borderRadius: BorderRadius.circular(4)),
      textStyle: TextStyle(color: p.window, fontSize: 12),
    ),
  );
}
