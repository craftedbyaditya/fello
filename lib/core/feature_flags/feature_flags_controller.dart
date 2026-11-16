import 'package:flutter/foundation.dart';

import '../../domain/entities/feature_flags.dart';
import '../../domain/repositories/feature_flags_repository.dart';

/// Five-minute global cache; failed loads revert to conservative launch flags.
class FeatureFlagsController extends ChangeNotifier {
  FeatureFlagsController(
    this._repository, {
    this.ttl = const Duration(minutes: 5),
  });

  final FeatureFlagsRepository _repository;
  final Duration ttl;
  FeatureFlags _flags = FeatureFlags.launchDefaults;
  DateTime? _loadedAt;
  bool _loading = false;

  bool enabled(String key, {bool fallback = false}) =>
      _flags.enabled(key, fallback: fallback);

  Future<void> refresh({bool force = false}) async {
    if (_loading) return;
    final now = DateTime.now();
    if (!force && _loadedAt != null && now.difference(_loadedAt!) < ttl) return;
    _loading = true;
    try {
      _flags = await _repository.load();
    } catch (_) {
      _flags = FeatureFlags.launchDefaults;
    } finally {
      _loadedAt = now;
      _loading = false;
      notifyListeners();
    }
  }
}
