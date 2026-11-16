import '../entities/feature_flags.dart';

abstract class FeatureFlagsRepository {
  Future<FeatureFlags> load();
}
