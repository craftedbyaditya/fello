import 'package:bloc_test/bloc_test.dart';
import 'package:fello/data/mock/mock_auth_repository.dart';
import 'package:fello/data/mock/mock_store.dart';
import 'package:fello/domain/entities/business_type.dart';
import 'package:fello/features/auth/bloc/auth_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockAuthRepository repo;

  setUp(() {
    repo = MockAuthRepository(MockStore());
  });

  blocTest<AuthBloc, AuthState>(
    'sign in emits authenticated without onboarding',
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
      isA<AuthState>()
          .having((s) => s.status, 'status', AuthStatus.authenticated)
          .having((s) => s.needsOnboarding, 'needsOnboarding', isFalse),
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

  blocTest<AuthBloc, AuthState>(
    'sign up emits authenticated needing onboarding',
    build: () => AuthBloc(repo),
    act: (bloc) => bloc.add(
      const AuthSignUpSubmitted(
        email: 'fresh@example.com',
        password: 'secret1',
        displayName: 'Fresh User',
      ),
    ),
    wait: const Duration(milliseconds: 600),
    expect: () => [
      isA<AuthState>().having((s) => s.status, 'status', AuthStatus.loading),
      isA<AuthState>()
          .having((s) => s.status, 'status', AuthStatus.authenticated)
          .having((s) => s.needsOnboarding, 'needsOnboarding', isTrue),
    ],
  );

  blocTest<AuthBloc, AuthState>(
    'completing onboarding clears needsOnboarding',
    build: () => AuthBloc(repo),
    seed: () {
      // Sign up synchronously via repo before seeding bloc state is awkward;
      // use act sequence instead.
      return const AuthState.unknown();
    },
    act: (bloc) async {
      bloc.add(
        const AuthSignUpSubmitted(
          email: 'onboard@example.com',
          password: 'secret1',
          displayName: 'Onboarder',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 550));
      bloc.add(
        const AuthOnboardingCompleted(
          organizationName: 'Acme Cafe',
          businessType: BusinessType.restaurantCafe,
        ),
      );
    },
    wait: const Duration(milliseconds: 1200),
    verify: (bloc) {
      expect(bloc.state.isAuthenticated, isTrue);
      expect(bloc.state.needsOnboarding, isFalse);
      expect(bloc.state.session?.organization.name, 'Acme Cafe');
      expect(
        bloc.state.session?.organization.businessType,
        BusinessType.restaurantCafe,
      );
    },
  );
}
