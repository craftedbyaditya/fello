enum DataSource { mock, supabase }

/// Runtime configuration. Switch data layer with:
/// `flutter run --dart-define=DATA_SOURCE=supabase`
class AppConfig {
  const AppConfig({
    required this.dataSource,
    this.supabaseUrl = '',
    this.supabaseAnonKey = '',
    this.publicBaseUrl = 'http://localhost:3847',
  });

  final DataSource dataSource;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String publicBaseUrl;

  bool get useMock => dataSource == DataSource.mock;

  factory AppConfig.fromEnvironment() {
    const source = String.fromEnvironment(
      'DATA_SOURCE',
      defaultValue: 'mock',
    );
    const url = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
    const key = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
    const base = String.fromEnvironment(
      'PUBLIC_BASE_URL',
      defaultValue: 'http://localhost:3847',
    );

    return AppConfig(
      dataSource: source.toLowerCase() == 'supabase'
          ? DataSource.supabase
          : DataSource.mock,
      supabaseUrl: url,
      supabaseAnonKey: key,
      publicBaseUrl: base,
    );
  }
}
