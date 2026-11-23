/// Product identity. Build-specific values are injected by the release build
/// with `--dart-define` (see tool/build_release.ps1); links stay hidden until
/// they are configured.
abstract final class Product {
  static const name = 'MonolithKeys';
  static const publisher = 'MonolithKeys';
  static const version = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');
  static const build = String.fromEnvironment('APP_BUILD', defaultValue: 'development');
  static const buildDate = String.fromEnvironment('APP_BUILD_DATE');
  static const websiteUrl = String.fromEnvironment('APP_WEBSITE_URL');
  static const docsUrl = String.fromEnvironment('APP_DOCS_URL');
  static const supportEmail = String.fromEnvironment('APP_SUPPORT_EMAIL');
}
