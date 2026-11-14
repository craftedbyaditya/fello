import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/auth_failure.dart';
import '../../../domain/entities/business_type.dart';
import '../../../domain/entities/organization.dart';
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
    on<AuthOrganizationUpdated>(_onOrganizationUpdated);
    on<AuthPasswordResetRequested>(_onPasswordResetRequested);
    on<AuthPasswordUpdateRequested>(_onPasswordUpdateRequested);
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
    // Ignore transient nulls while a sign-in / sign-up request is in flight.
    if (session == null && state.status == AuthStatus.loading) {
      return;
    }
    if (session == null) {
      emit(const AuthState.unauthenticated());
    } else {
      emit(
        AuthState.authenticated(
          session,
          needsOnboarding: _needsOnboarding(session),
        ),
      );
    }
  }

  /// Workspace setup is admin-only. Employees join a ready org via invite.
  bool _needsOnboarding(AuthSession session) {
    if (session.profile.isEmployee) return false;
    return session.organization.needsOnboarding;
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
      emit(
        AuthState.authenticated(
          session,
          needsOnboarding: _needsOnboarding(session),
        ),
      );
    } on AuthFailure catch (e) {
      emit(
        AuthState.unauthenticated(errorMessage: e.message),
      );
    } catch (_) {
      emit(
        const AuthState.unauthenticated(
          errorMessage:
              'Something went wrong. Check your connection and try again.',
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
        displayName: event.displayName,
        inviteToken: event.inviteToken,
      );
      emit(
        AuthState.authenticated(
          session,
          needsOnboarding: _needsOnboarding(session),
        ),
      );
    } on AuthFailure catch (e) {
      emit(
        AuthState.unauthenticated(errorMessage: e.message),
      );
    } catch (_) {
      emit(
        const AuthState.unauthenticated(
          errorMessage: "We couldn't create your account. Please try again.",
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

  void _onOrganizationUpdated(
    AuthOrganizationUpdated event,
    Emitter<AuthState> emit,
  ) {
    final session = state.session;
    if (session == null) return;
    final next = session.copyWith(organization: event.organization);
    emit(
      AuthState.authenticated(
        next,
        needsOnboarding: _needsOnboarding(next),
      ),
    );
  }

  Future<void> _onPasswordResetRequested(
    AuthPasswordResetRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading, clearError: true));
    try {
      await _authRepository.requestPasswordReset(email: event.email);
      emit(
        const AuthState.unauthenticated(
          errorMessage:
              'If that email is registered, we sent a reset link. Check your inbox.',
        ),
      );
    } on AuthFailure catch (e) {
      emit(AuthState.unauthenticated(errorMessage: e.message));
    } catch (_) {
      emit(
        const AuthState.unauthenticated(
          errorMessage: "We couldn't send a reset email. Please try again.",
        ),
      );
    }
  }

  Future<void> _onPasswordUpdateRequested(
    AuthPasswordUpdateRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading, clearError: true));
    try {
      await _authRepository.updatePassword(newPassword: event.newPassword);
      final session = state.session;
      if (session != null) {
        emit(
          AuthState.authenticated(
            session,
            needsOnboarding: _needsOnboarding(session),
          ),
        );
      } else {
        emit(
          const AuthState.unauthenticated(
            errorMessage: 'Password updated. Please sign in.',
          ),
        );
      }
    } on AuthFailure catch (e) {
      emit(
        state.copyWith(
          status: state.session != null
              ? AuthStatus.authenticated
              : AuthStatus.unauthenticated,
          errorMessage: e.message,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: state.session != null
              ? AuthStatus.authenticated
              : AuthStatus.unauthenticated,
          errorMessage: "We couldn't update your password. Please try again.",
        ),
      );
    }
  }

  Future<void> _onOnboardingCompleted(
    AuthOnboardingCompleted event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading, clearError: true));
    try {
      final session = await _authRepository.completeOnboarding(
        organizationName: event.organizationName,
        businessType: event.businessType,
      );
      emit(
        AuthState.authenticated(
          session,
          needsOnboarding: false,
        ),
      );
    } on AuthFailure catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          errorMessage: e.message,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          errorMessage: "We couldn't create your workspace. Please try again.",
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
