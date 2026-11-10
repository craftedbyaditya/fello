import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/mock/mock_auth_repository.dart';
import '../../data/mock/mock_form_repository.dart';
import '../../data/mock/mock_response_repository.dart';
import '../../data/mock/mock_store.dart';
import '../../data/supabase/supabase_auth_repository.dart';
import '../../data/supabase/supabase_form_repository.dart';
import '../../data/supabase/supabase_response_repository.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/form_repository.dart';
import '../../domain/repositories/response_repository.dart';
import '../config/app_config.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies(AppConfig config) async {
  if (getIt.isRegistered<AppConfig>()) {
    await getIt.reset();
  }

  getIt.registerSingleton<AppConfig>(config);

  if (config.useMock) {
    final store = MockStore();
    getIt.registerSingleton<MockStore>(store);
    getIt.registerLazySingleton<AuthRepository>(
      () => MockAuthRepository(store),
    );
    getIt.registerLazySingleton<FormRepository>(
      () => MockFormRepository(store),
    );
    getIt.registerLazySingleton<ResponseRepository>(
      () => MockResponseRepository(store),
    );
  } else {
    if (config.supabaseUrl.isEmpty || config.supabaseAnonKey.isEmpty) {
      throw StateError(
        'DATA_SOURCE=supabase requires SUPABASE_URL and SUPABASE_ANON_KEY.',
      );
    }
    await Supabase.initialize(
      url: config.supabaseUrl,
      // publishableKey is the current API; anon key values remain valid.
      publishableKey: config.supabaseAnonKey,
    );
    final client = Supabase.instance.client;
    getIt.registerLazySingleton<AuthRepository>(
      () => SupabaseAuthRepository(client),
    );
    getIt.registerLazySingleton<FormRepository>(
      () => SupabaseFormRepository(client),
    );
    getIt.registerLazySingleton<ResponseRepository>(
      () => SupabaseResponseRepository(client),
    );
  }
}
