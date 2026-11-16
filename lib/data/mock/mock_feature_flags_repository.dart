import '../../domain/entities/feature_flags.dart';
import '../../domain/repositories/feature_flags_repository.dart';

class MockFeatureFlagsRepository implements FeatureFlagsRepository {
  @override
  Future<FeatureFlags> load() async => FeatureFlags.launchDefaults;
}
