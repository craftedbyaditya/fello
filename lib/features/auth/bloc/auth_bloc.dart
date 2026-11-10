import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/mock/mock_auth_repository.dart';
import '../../../domain/repositories/auth_repository.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this._authRepository) : super(const AuthState.unknown()) {
    on<AuthSubscriptionRequested>(_onSubscriptionRequested);
    on<AuthSignInSubmitted>(_onSignIn);
    on<AuthSignUpSubmitted>(_onSignUp);
    on<AuthSignOutRequested>(_onSignOut);
    on<AuthSessionChanged>(_onSessionChanged);
    on<AuthOnboardingCompleted>(_onOnboardingCompleted);
  }

  final AuthRepository _authRepository;
  StreamSubscription<AuthSession?>? _subscription;

  Future<void> _onSubscriptionRequested(
    AuthSubscriptionRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _subscription?.cancel();
    _subscription = _authRepository.authStateChanges.listen(
      (session) => add(AuthSessionChanged(session)),
    );
  }

  void _onSessionChanged(AuthSessionChanged event, Emitter<AuthState> emit) {
    final session = event.session;
    if (session == null) {
      emit(const AuthState.unauthenticated());
    } else {
      emit(AuthState.authenticated(session));
    }
  }

  Future<void> _onSignIn(
    AuthSignInSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading, clearError: true));
    try {
      final session = await _authRepository.signIn(
        email: event.email,
        password: event.password,
      );
      emit(AuthState.authenticated(session));
    } on AuthFailure catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMessage: e.message,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onSignUp(
    AuthSignUpSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading, clearError: true));
    try {
      final session = await _authRepository.signUp(
        email: event.email,
        password: event.password,
        organizationName: event.organizationName,
        displayName: event.displayName,
      );
      emit(AuthState.authenticated(session, needsOnboarding: true));
    } on AuthFailure catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMessage: e.message,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onSignOut(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _authRepository.signOut();
    emit(const AuthState.unauthenticated());
  }

  void _onOnboardingCompleted(
    AuthOnboardingCompleted event,
    Emitter<AuthState> emit,
  ) {
    if (state.session != null) {
      emit(state.copyWith(needsOnboarding: false));
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
