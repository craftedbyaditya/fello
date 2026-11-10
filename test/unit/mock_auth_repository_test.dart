import 'package:fello/data/mock/mock_auth_repository.dart';
import 'package:fello/data/mock/mock_store.dart';
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
    expect(repo.currentSession, isNotNull);
  });

  test('sign in fails with wrong password', () async {
    expect(
      () => repo.signIn(email: 'ada@harbor.coffee', password: 'wrong'),
      throwsA(isA<AuthFailure>()),
    );
  });

  test('sign up creates org and session', () async {
    final session = await repo.signUp(
      email: 'new@example.com',
      password: 'secret1',
      organizationName: 'Northwind',
      displayName: 'Sam',
    );
    expect(session.organization.slug, 'northwind');
    expect(session.profile.displayName, 'Sam');
  });
}
