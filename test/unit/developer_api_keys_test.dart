import 'package:fello/data/mock/mock_developer_api_repository.dart';
import 'package:fello/data/mock/mock_response_repository.dart';
import 'package:fello/data/mock/mock_store.dart';
import 'package:fello/domain/auth_permission_failure.dart';
import 'package:fello/domain/entities/organization.dart';
import 'package:fello/domain/entities/profile.dart';
import 'package:fello/domain/entities/subscription_plan.dart';
import 'package:fello/domain/plan_limit_failure.dart';
import 'package:fello/domain/repositories/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockStore store;
  late MockDeveloperApiRepository api;
  late Organization freeOrg;
  late Organization paidOrg;
  late Profile freeAdmin;
  late Profile paidAdmin;
  late Profile paidEmployee;

  setUp(() {
    MockDeveloperApiRepository.clearAll();
    store = MockStore();
    api = MockDeveloperApiRepository(store);
    freeOrg = store.organizations.first;
    // Ensure free baseline
    freeOrg = Organization(
      id: freeOrg.id,
      name: freeOrg.name,
      slug: freeOrg.slug,
      createdAt: freeOrg.createdAt,
      planId: PlanId.free,
    );
    paidOrg = Organization(
      id: 'paid-org',
      name: 'Paid Co',
      slug: 'paid-co',
      createdAt: DateTime.now().toUtc(),
      planId: PlanId.pro,
    );
    freeAdmin = store.profiles.firstWhere((p) => p.isAdmin);
    paidAdmin = Profile(
      id: 'paid-admin',
      orgId: paidOrg.id,
      displayName: 'Paid Admin',
      email: 'paid-admin@example.com',
      role: ProfileRole.admin,
    );
    paidEmployee = Profile(
      id: 'paid-emp',
      orgId: paidOrg.id,
      displayName: 'Paid Emp',
      email: 'paid-emp@example.com',
      role: ProfileRole.employee,
    );
    store.organizations
      ..clear()
      ..addAll([freeOrg, paidOrg]);
    store.profiles.addAll([paidAdmin, paidEmployee]);
  });

  test('free org cannot list or create API keys', () async {
    store.setSession(AuthSession(profile: freeAdmin, organization: freeOrg));
    expect(api.listKeys(), throwsA(isA<PlanLimitFailure>()));
    expect(() => api.createKey(name: 'Test'), throwsA(isA<PlanLimitFailure>()));
  });

  test('paid admin can create, list, and revoke keys', () async {
    store.setSession(AuthSession(profile: paidAdmin, organization: paidOrg));
    final created = await api.createKey(name: 'Production');
    expect(created.apiKey.startsWith('kay_'), isTrue);
    expect(created.key.keyPrefix, created.apiKey.substring(0, 12));

    final keys = await api.listKeys();
    expect(keys.length, 1);
    expect(keys.first.name, 'Production');

    // Secret not retrievable from list metadata
    expect(keys.first.keyPrefix.length, lessThan(created.apiKey.length));

    await api.revokeKey(created.key.id);
    final after = await api.listKeys();
    expect(after.first.isRevoked, isTrue);
  });

  test('paid employee can list but cannot create or revoke', () async {
    store.setSession(AuthSession(profile: paidAdmin, organization: paidOrg));
    final created = await api.createKey(name: 'Shared');

    store.setSession(AuthSession(profile: paidEmployee, organization: paidOrg));
    final keys = await api.listKeys();
    expect(keys, isNotEmpty);

    expect(
      () => api.createKey(name: 'Nope'),
      throwsA(isA<AuthPermissionFailure>()),
    );
    expect(
      () => api.revokeKey(created.key.id),
      throwsA(isA<AuthPermissionFailure>()),
    );
  });

  test('admin can mark response public', () async {
    // Seeded responses belong to the default org; use that admin session.
    final org = store.organizations.firstWhere((o) => o.id == freeAdmin.orgId);
    store.setSession(AuthSession(profile: freeAdmin, organization: org));
    expect(store.responses, isNotEmpty);
    final responses = MockResponseRepository(store);
    final first = store.responses.first;
    final updated = await responses.setResponsePublic(
      responseId: first.id,
      isPublic: true,
    );
    expect(updated.isPublic, isTrue);
  });

  test('SubscriptionPlan.allowsReviewsApi is Pro-only', () {
    expect(SubscriptionPlan.free.allowsReviewsApi, isFalse);
    expect(SubscriptionPlan.growth.allowsReviewsApi, isFalse);
    expect(SubscriptionPlan.pro.allowsReviewsApi, isTrue);
  });
}
