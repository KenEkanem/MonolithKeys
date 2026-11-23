import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../log.dart';
import '../../product.dart';
import '../app.dart';
import '../previews.dart';
import '../theme.dart';
import '../widgets.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final native = AppScope.of(context).native;
    final p = Palette.of(context);
    final logs = Log.directory;
    Widget link(IconData icon, String title, String value, String target) => SettingTile(
      icon: icon,
      title: title,
      trailing: Text(value, style: TextStyle(color: p.accent)),
      onTap: () => native.open(target),
    );
    return PageFrame(
      title: 'About',
      children: [
        Section(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const BrandMark(size: 48),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(Product.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      SelectableText(
                        'Version ${Product.version} · build ${Product.build}'
                        '${Product.buildDate.isEmpty ? '' : ' · ${Product.buildDate}'}',
                        style: TextStyle(color: p.textMuted, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SettingTile(
              icon: FluentIcons.person_24_regular,
              title: 'Developer',
              trailing: Text(Product.publisher, style: TextStyle(color: p.textMuted)),
            ),
            if (Product.websiteUrl.isNotEmpty)
              link(FluentIcons.globe_24_regular, 'Website', Product.websiteUrl, Product.websiteUrl),
            if (Product.docsUrl.isNotEmpty)
              link(FluentIcons.document_text_24_regular, 'Documentation', Product.docsUrl, Product.docsUrl),
            if (Product.supportEmail.isNotEmpty)
              link(FluentIcons.mail_24_regular, 'Support', Product.supportEmail, 'mailto:${Product.supportEmail}'),
          ],
        ),
        Section(
          children: [
            SettingTile(
              icon: FluentIcons.eye_24_regular,
              title: 'Privacy',
              subtitle:
                  'MonolithKeys reads key presses only to draw the overlay and play sounds while those features are on. '
                  'It never records what you type, and it has no network access.',
            ),
            if (logs != null)
              SettingTile(
                icon: FluentIcons.folder_open_24_regular,
                title: 'Open logs folder',
                subtitle: 'Diagnostic logs for bug reports. They never contain key presses.',
                trailing: const Icon(FluentIcons.open_24_regular, size: 18),
                onTap: () => native.open(logs.path),
              ),
            SettingTile(
              icon: FluentIcons.document_text_24_regular,
              title: 'Third-party licenses',
              subtitle: 'Open-source components used by MonolithKeys',
              trailing: const Icon(FluentIcons.chevron_right_24_regular, size: 18),
              onTap: () => showLicensePage(
                context: context,
                applicationName: Product.name,
                applicationVersion: Product.version,
                applicationIcon: const Padding(padding: EdgeInsets.all(12), child: BrandMark(size: 48)),
              ),
            ),
          ],
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('© 2026 ${Product.publisher}', style: TextStyle(color: p.textMuted, fontSize: 13)),
          ),
        ),
      ],
    );
  }
}
