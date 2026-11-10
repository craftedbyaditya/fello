part of 'auth_bloc.dart';

enum AuthStatus { unknown, authenticated, unauthenticated, loading }

class AuthState extends Equatable {
  const AuthState({
    required this.status,
    this.session,
    this.errorMessage,
    this.needsOnboarding = false,
  });

  const AuthState.unknown() : this(status: AuthStatus.unknown);

  const AuthState.unauthenticated({String? errorMessage})
      : this(
          status: AuthStatus.unauthenticated,
          errorMessage: errorMessage,
        );

  const AuthState.authenticated(
    AuthSession session, {
    bool needsOnboarding = false,
  }) : this(
          status: AuthStatus.authenticated,
          session: session,
          needsOnboarding: needsOnboarding,
        );

  final AuthStatus status;
  final AuthSession? session;
  final String? errorMessage;
  final bool needsOnboarding;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthState copyWith({
    AuthStatus? status,
    AuthSession? session,
    String? errorMessage,
    bool? needsOnboarding,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      session: session ?? this.session,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      needsOnboarding: needsOnboarding ?? this.needsOnboarding,
    );
  }

  @override
  List<Object?> get props =>
      [status, session, errorMessage, needsOnboarding];
}
