import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/mock/mock_auth_repository.dart';
import '../../data/mock/mock_billing_repository.dart';
import '../../data/mock/mock_developer_api_repository.dart';
import '../../data/mock/mock_form_repository.dart';
import '../../data/mock/mock_feature_flags_repository.dart';
import '../../data/mock/mock_response_repository.dart';
import '../../data/mock/mock_store.dart';
import '../../data/mock/mock_team_repository.dart';
import '../../data/mock/mock_workflow_repository.dart';
import '../../data/supabase/supabase_auth_repository.dart';
import '../../data/supabase/supabase_billing_repository.dart';
import '../../data/supabase/supabase_developer_api_repository.dart';
import '../../data/supabase/supabase_form_repository.dart';
import '../../data/supabase/supabase_feature_flags_repository.dart';
import '../../data/supabase/supabase_response_repository.dart';
import '../../data/supabase/supabase_team_repository.dart';
import '../../data/supabase/supabase_workflow_repository.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/billing_repository.dart';
import '../../domain/repositories/developer_api_repository.dart';
import '../../domain/repositories/form_repository.dart';
import '../../domain/repositories/feature_flags_repository.dart';
import '../../domain/repositories/response_repository.dart';
import '../../domain/repositories/team_repository.dart';
import '../../domain/repositories/workflow_repository.dart';
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
    getIt.registerLazySingleton<FeatureFlagsRepository>(
      MockFeatureFlagsRepository.new,
    );
    getIt.registerLazySingleton<ResponseRepository>(
      () => MockResponseRepository(store),
    );
    getIt.registerLazySingleton<TeamRepository>(
      () => MockTeamRepository(store),
    );
    getIt.registerLazySingleton<BillingRepository>(
      () => MockBillingRepository(store),
    );
    getIt.registerLazySingleton<WorkflowRepository>(
      () => MockWorkflowRepository(store),
    );
    getIt.registerLazySingleton<DeveloperApiRepository>(
      () => MockDeveloperApiRepository(store),
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
    getIt.registerLazySingleton<FeatureFlagsRepository>(
      () => SupabaseFeatureFlagsRepository(client),
    );
    getIt.registerLazySingleton<ResponseRepository>(
      () => SupabaseResponseRepository(client),
    );
    getIt.registerLazySingleton<TeamRepository>(
      () => SupabaseTeamRepository(client),
    );
    getIt.registerLazySingleton<BillingRepository>(
      () => SupabaseBillingRepository(client),
    );
    getIt.registerLazySingleton<WorkflowRepository>(
      () => SupabaseWorkflowRepository(client),
    );
    getIt.registerLazySingleton<DeveloperApiRepository>(
      () => SupabaseDeveloperApiRepository(client),
    );
  }
}
