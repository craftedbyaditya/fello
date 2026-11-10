part of 'auth_bloc.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

final class AuthSubscriptionRequested extends AuthEvent {
  const AuthSubscriptionRequested();
}

final class AuthSessionChanged extends AuthEvent {
  const AuthSessionChanged(this.session);
  final AuthSession? session;

  @override
  List<Object?> get props => [session];
}

final class AuthSignInSubmitted extends AuthEvent {
  const AuthSignInSubmitted({required this.email, required this.password});
  final String email;
  final String password;

  @override
  List<Object?> get props => [email, password];
}

final class AuthSignUpSubmitted extends AuthEvent {
  const AuthSignUpSubmitted({
    required this.email,
    required this.password,
    required this.organizationName,
    required this.displayName,
  });

  final String email;
  final String password;
  final String organizationName;
  final String displayName;

  @override
  List<Object?> get props =>
      [email, password, organizationName, displayName];
}

final class AuthSignOutRequested extends AuthEvent {
  const AuthSignOutRequested();
}

final class AuthOnboardingCompleted extends AuthEvent {
  const AuthOnboardingCompleted();
}
