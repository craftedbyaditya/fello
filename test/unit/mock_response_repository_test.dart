import 'package:fello/data/mock/mock_response_repository.dart';
import 'package:fello/data/mock/mock_store.dart';
import 'package:fello/domain/entities/dashboard_stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockStore store;
  late MockResponseRepository repo;

  setUp(() {
    store = MockStore();
    repo = MockResponseRepository(store);
  });

  test('stats compute average rating and nps', () async {
    final stats = await repo.getStats(orgId: 'org_demo');
    expect(stats.totalResponses, greaterThan(0));
    expect(stats.averageRating, isNotNull);
    expect(stats.npsScore, isNotNull);
  });

  test('filters by nps promoter band', () async {
    final all = await repo.listResponses(orgId: 'org_demo');
    final promoters = await repo.listResponses(
      orgId: 'org_demo',
      filters: const ResponseFilters(npsBand: 'promoter'),
    );
    expect(promoters.length, lessThanOrEqualTo(all.length));
    expect(promoters, isNotEmpty);
  });

  test('submit rejects empty required answers', () async {
    final form = store.forms.firstWhere((f) => f.slug == 'harbor-visit');
    expect(
      () => repo.submitResponse(formId: form.id, answersByQuestionId: {}),
      throwsA(isA<Object>()),
    );
  });
}
