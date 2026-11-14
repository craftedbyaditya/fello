import 'package:fello/data/mock/mock_auth_repository.dart';
import 'package:fello/data/mock/mock_store.dart';
import 'package:fello/domain/auth_failure.dart';
import 'package:fello/domain/entities/business_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockStore store;
  late MockAuthRepository repo;

  setUp(() {
    store = MockStore();
    repo = MockAuthRepository(store);
  });

  test('sign in succeeds with demo credentials', () async {
    final session = await repo.signIn(
      email: 'ada@harbor.coffee',
      password: 'fello123',
    );
    expect(session.profile.email, 'ada@harbor.coffee');
    expect(session.organization.name, 'Harbor Coffee');
    expect(session.organization.needsOnboarding, isFalse);
    expect(repo.currentSession, isNotNull);
  });

  test('sign in fails with wrong password', () async {
    expect(
      () => repo.signIn(email: 'ada@harbor.coffee', password: 'wrong'),
      throwsA(isA<AuthFailure>()),
    );
  });

  test('sign up creates placeholder workspace needing onboarding', () async {
    final session = await repo.signUp(
      email: 'new@example.com',
      password: 'secret1',
      displayName: 'Sam',
    );
    expect(session.profile.displayName, 'Sam');
    expect(session.organization.name, 'My workspace');
    expect(session.organization.needsOnboarding, isTrue);
    expect(session.organization.businessType, isNull);
  });

  test('complete onboarding sets name, business type, and completion', () async {
    await repo.signUp(
      email: 'new@example.com',
      password: 'secret1',
      displayName: 'Sam',
    );
    final session = await repo.completeOnboarding(
      organizationName: 'Northwind',
      businessType: BusinessType.retail,
    );
    expect(session.organization.name, 'Northwind');
    expect(session.organization.slug, 'northwind');
    expect(session.organization.businessType, BusinessType.retail);
    expect(session.organization.needsOnboarding, isFalse);
  });

  test('complete onboarding can skip business type', () async {
    await repo.signUp(
      email: 'skip@example.com',
      password: 'secret1',
      displayName: 'Sam',
    );
    final session = await repo.completeOnboarding(
      organizationName: 'Skip Co',
    );
    expect(session.organization.businessType, isNull);
    expect(session.organization.needsOnboarding, isFalse);
  });

  test('complete onboarding rejects empty organisation name', () async {
    await repo.signUp(
      email: 'bad@example.com',
      password: 'secret1',
      displayName: 'Sam',
    );
    expect(
      () => repo.completeOnboarding(organizationName: '   '),
      throwsA(isA<AuthFailure>()),
    );
  });
}
