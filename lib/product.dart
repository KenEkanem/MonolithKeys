/// Product identity. Build-specific values are injected by the release build
/// with `--dart-define` (see tool/build_release.ps1). Links left empty are
/// hidden on the About page.
abstract final class Product {
  static const name = 'MonolithKeys';
  static const publisher = 'MonolithKeys';
  static const version = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');
  static const build = String.fromEnvironment('APP_BUILD', defaultValue: 'development');
  static const buildDate = String.fromEnvironment('APP_BUILD_DATE');
  static const websiteUrl = 'https://kennedyekanem.tech';
  static const docsUrl = String.fromEnvironment('APP_DOCS_URL');
  static const supportEmail = 'support@kennedyekanem.tech';
}
