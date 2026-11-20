enum DataSource { mock, supabase }

/// Runtime configuration.
///
/// Production default is Supabase. Opt into mock only with
/// `--dart-define=DATA_SOURCE=mock` (unit tests / local UI demos).
class AppConfig {
  const AppConfig({
    required this.dataSource,
    this.supabaseUrl = '',
    this.supabaseAnonKey = '',
    this.publicBaseUrl = productionBaseUrl,
    this.turnstileSiteKey = '',
    this.googleWebClientId = '',
  });

  /// Release version injected by the production build from `pubspec.yaml`.
  /// Local development retains a readable fallback without needing defines.
  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.1',
  );

  final DataSource dataSource;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String publicBaseUrl;

  /// Cloudflare Turnstile site key. Required for Supabase public submissions.
  final String turnstileSiteKey;

  /// Public Google OAuth web client ID. An empty value intentionally keeps
  /// Google One Tap and the OAuth button disabled.
  final String googleWebClientId;

  bool get useMock => dataSource == DataSource.mock;
  bool get turnstileEnabled => turnstileSiteKey.trim().isNotEmpty;
  bool get googleSignInEnabled => googleWebClientId.trim().isNotEmpty;

  factory AppConfig.fromEnvironment() {
    const source = String.fromEnvironment(
      'DATA_SOURCE',
      defaultValue: 'supabase',
    );
    const url = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
    const key = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
    const base = String.fromEnvironment(
      'PUBLIC_BASE_URL',
      defaultValue: productionBaseUrl,
    );
    const turnstile = String.fromEnvironment(
      'TURNSTILE_SITE_KEY',
      defaultValue: '',
    );
    const googleWebClientId = String.fromEnvironment(
      'GOOGLE_WEB_CLIENT_ID',
      defaultValue: '',
    );

    final dataSource = source.toLowerCase() == 'mock'
        ? DataSource.mock
        : DataSource.supabase;

    return AppConfig(
      dataSource: dataSource,
      supabaseUrl: url,
      supabaseAnonKey: key,
      publicBaseUrl: _normalizeBaseUrl(base),
      turnstileSiteKey: turnstile.trim(),
      googleWebClientId: googleWebClientId.trim(),
    );
  }

  void validate() {
    if (useMock) return;
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'Kaydo requires SUPABASE_URL and SUPABASE_ANON_KEY.\n'
        'Create a Supabase project, run migrations in supabase/migrations/, '
        'then build/run with those dart-defines (see deploy/SUPABASE_SETUP.md).',
      );
    }
    final url = supabaseUrl.trim();
    if (url.contains('https:https://') ||
        url.contains('http:http://') ||
        !(url.startsWith('https://') || url.startsWith('http://'))) {
      throw StateError(
        'SUPABASE_URL looks invalid: "$supabaseUrl".\n'
        'Use exactly https://YOUR_PROJECT.supabase.co (one https://, no spaces).',
      );
    }
    if (!turnstileEnabled) {
      throw StateError(
        'Kaydo requires TURNSTILE_SITE_KEY for public form bot protection.\n'
        'Create a Cloudflare Turnstile widget, set the site key as a dart-define, '
        'and configure the server-side Turnstile secret for submit-feedback '
        '(see deploy/SUPABASE_SETUP.md).',
      );
    }
  }

  /// Production web origin for Kaydo (share links + QR).
  static const String productionHost = 'kaydo.sayge.in';
  static const String productionBaseUrl = 'https://$productionHost';

  static String _normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return productionBaseUrl;
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }
}
