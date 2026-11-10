import 'package:bloc_test/bloc_test.dart';
import 'package:fello/data/mock/mock_auth_repository.dart';
import 'package:fello/data/mock/mock_store.dart';
import 'package:fello/features/auth/bloc/auth_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockAuthRepository repo;

  setUp(() {
    repo = MockAuthRepository(MockStore());
  });

  blocTest<AuthBloc, AuthState>(
    'sign in emits authenticated',
    build: () => AuthBloc(repo),
    act: (bloc) => bloc.add(
      const AuthSignInSubmitted(
        email: 'ada@harbor.coffee',
        password: 'fello123',
      ),
    ),
    wait: const Duration(milliseconds: 500),
    expect: () => [
      isA<AuthState>().having((s) => s.status, 'status', AuthStatus.loading),
      isA<AuthState>().having(
        (s) => s.status,
        'status',
        AuthStatus.authenticated,
      ),
    ],
  );

  blocTest<AuthBloc, AuthState>(
    'bad password emits error',
    build: () => AuthBloc(repo),
    act: (bloc) => bloc.add(
      const AuthSignInSubmitted(
        email: 'ada@harbor.coffee',
        password: 'nope',
      ),
    ),
    wait: const Duration(milliseconds: 500),
    expect: () => [
      isA<AuthState>().having((s) => s.status, 'status', AuthStatus.loading),
      isA<AuthState>()
          .having((s) => s.status, 'status', AuthStatus.unauthenticated)
          .having((s) => s.errorMessage, 'error', isNotNull),
    ],
  );
}
