import 'package:fello/core/feature_flags/feature_flags_controller.dart';
import 'package:fello/domain/entities/feature_flags.dart';
import 'package:fello/domain/repositories/feature_flags_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repository implements FeatureFlagsRepository {
  _Repository(this.responses);
  final List<Object> responses;
  int calls = 0;

  @override
  Future<FeatureFlags> load() async {
    final next =
        responses[calls < responses.length ? calls : responses.length - 1];
    calls++;
    if (next is Exception) throw next;
    return next as FeatureFlags;
  }
}

void main() {
  test(
    'loads flags initially and does not reload inside the five-minute TTL',
    () async {
      final repo = _Repository([
        const FeatureFlags({'task_board_enabled': true}),
      ]);
      final controller = FeatureFlagsController(repo);

      await controller.refresh();
      await controller.refresh();

      expect(controller.enabled('task_board_enabled'), isTrue);
      expect(repo.calls, 1);
    },
  );

  test(
    'force refresh observes an operator flag change without redeployment',
    () async {
      final repo = _Repository([
        const FeatureFlags({'task_board_enabled': false}),
        const FeatureFlags({'task_board_enabled': true}),
      ]);
      final controller = FeatureFlagsController(repo);

      await controller.refresh();
      expect(controller.enabled('task_board_enabled'), isFalse);
      await controller.refresh(force: true);

      expect(controller.enabled('task_board_enabled'), isTrue);
      expect(repo.calls, 2);
    },
  );

  test(
    'RPC failure falls back without enabling incomplete functionality',
    () async {
      final repo = _Repository([Exception('offline')]);
      final controller = FeatureFlagsController(repo);

      await controller.refresh();

      expect(controller.enabled('feedback_forms_enabled'), isTrue);
      expect(controller.enabled('task_board_enabled'), isFalse);
      expect(controller.enabled('reviews_api_enabled'), isFalse);
      expect(controller.enabled('billing_enabled'), isFalse);
    },
  );

  test('expired TTL triggers exactly one new request', () async {
    final repo = _Repository([
      const FeatureFlags({'analytics_enabled': true}),
      const FeatureFlags({'analytics_enabled': false}),
    ]);
    final controller = FeatureFlagsController(repo, ttl: Duration.zero);

    await controller.refresh();
    await controller.refresh();

    expect(repo.calls, 2);
    expect(controller.enabled('analytics_enabled'), isFalse);
  });
}
