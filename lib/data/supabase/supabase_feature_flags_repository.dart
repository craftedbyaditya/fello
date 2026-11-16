import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/feature_flags.dart';
import '../../domain/repositories/feature_flags_repository.dart';

class SupabaseFeatureFlagsRepository implements FeatureFlagsRepository {
  SupabaseFeatureFlagsRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<FeatureFlags> load() async {
    final rows = await _client.rpc('get_launch_feature_flags');
    final values = <String, bool>{};
    for (final row in rows as List) {
      final value = row as Map<String, dynamic>;
      final key = value['key'] as String?;
      if (key != null) values[key] = value['enabled'] == true;
    }
    return FeatureFlags(values);
  }
}
