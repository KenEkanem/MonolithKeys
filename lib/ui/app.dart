import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../app_controller.dart';
import '../product.dart';
import '../settings/settings.dart';
import 'pages/about_page.dart';
import 'pages/cursor_page.dart';
import 'pages/general_page.dart';
import 'pages/keystroke_page.dart';
import 'pages/license_page.dart';
import 'pages/sounds_page.dart';
import 'previews.dart';
import 'theme.dart';

/// Gives pages access to the [AppController].
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.controller, required super.child});

  final AppController controller;

  static AppController of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.controller;

  @override
  bool updateShouldNotify(AppScope old) => old.controller != controller;
}

class MonolithKeysApp extends StatelessWidget {
  const MonolithKeysApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => AppScope(
    controller: controller,
    child: ListenableBuilder(
      listenable: controller.settings,
      builder: (context, _) {
        final dark = controller.settings.value.theme == AppTheme.dark;
        return MaterialApp(
          title: Product.name,
          debugShowCheckedModeBanner: false,
          theme: buildTheme(dark ? Palette.dark : Palette.light, dark ? Brightness.dark : Brightness.light),
          home: const Shell(),
        );
      },
    ),
  );
}

enum SettingsPage {
  general('General', FluentIcons.settings_24_regular),
  keystroke('Keystroke', FluentIcons.keyboard_24_regular),
  cursor('Cursor', FluentIcons.cursor_24_regular),
  sounds('Sounds', FluentIcons.speaker_2_24_regular),
  license('License', FluentIcons.key_24_regular),
  about('About', FluentIcons.info_24_regular);

  const SettingsPage(this.label, this.icon);

  final String label;
  final IconData icon;
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  var _page = SettingsPage.general;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final controller = AppScope.of(context);
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 232,
            color: p.sidebar,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GestureDetector(
                  onPanStart: (_) => controller.native.startWindowDrag(),
                  child: Container(
                    color: const Color(0x00000000),
                    padding: const EdgeInsets.fromLTRB(8, 24, 8, 20),
                    child: const Row(
                      children: [
                        BrandMark(size: 30),
                        SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            Product.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                  child: Text(
                    'SETTINGS',
                    style: TextStyle(
                      fontSize: 11.5,
                      letterSpacing: 0.6,
                      color: p.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                for (final page in SettingsPage.values)
                  _NavItem(
                    icon: page.icon,
                    label: page.label,
                    selected: page == _page,
                    onTap: () => setState(() => _page = page),
                  ),
                const Spacer(),
                _NavItem(icon: FluentIcons.sign_out_24_regular, label: 'Exit', selected: false, onTap: controller.exit),
              ],
            ),
          ),
          VerticalDivider(width: 1, color: p.divider),
          Expanded(
            child: switch (_page) {
              SettingsPage.general => const GeneralPage(),
              SettingsPage.keystroke => const KeystrokePage(),
              SettingsPage.cursor => const CursorPage(),
              SettingsPage.sounds => const SoundsPage(),
              SettingsPage.license => const LicensingPage(),
              SettingsPage.about => const AboutPage(),
            },
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final color = selected ? p.onAccent : p.text;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? p.accent : const Color(0x00000000),
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            onTap: onTap,
            hoverColor: p.hover,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: selected ? p.onAccent : p.textMuted),
                  const SizedBox(width: 12),
                  Text(label, style: TextStyle(fontSize: 14.5, color: color)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Page frame: draggable title row with the close button, then content.
class PageFrame extends StatelessWidget {
  const PageFrame({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onPanStart: (_) => controller.native.startWindowDrag(),
          child: Container(
            color: const Color(0x00000000),
            padding: const EdgeInsets.fromLTRB(32, 20, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Semantics(
                      header: true,
                      child: Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close window (MonolithKeys keeps running in the notification area)',
                  icon: const Icon(FluentIcons.dismiss_24_regular, size: 18),
                  onPressed: controller.native.hideWindow,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(32, 8, 32, 32),
            itemCount: children.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) => children[i],
          ),
        ),
      ],
    );
  }
}
