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

final class AuthGoogleOAuthRequested extends AuthEvent {
  const AuthGoogleOAuthRequested();
}

final class AuthGoogleIdTokenSubmitted extends AuthEvent {
  const AuthGoogleIdTokenSubmitted(this.idToken);
  final String idToken;

  @override
  List<Object?> get props => [idToken];
}

final class AuthSignUpSubmitted extends AuthEvent {
  const AuthSignUpSubmitted({
    required this.email,
    required this.password,
    required this.displayName,
    this.inviteToken,
  });

  final String email;
  final String password;
  final String displayName;
  final String? inviteToken;

  @override
  List<Object?> get props => [email, password, displayName, inviteToken];
}

final class AuthSignOutRequested extends AuthEvent {
  const AuthSignOutRequested();
}

final class AuthOnboardingCompleted extends AuthEvent {
  const AuthOnboardingCompleted({
    required this.organizationName,
    this.businessType,
  });

  final String organizationName;
  final BusinessType? businessType;

  @override
  List<Object?> get props => [organizationName, businessType];
}

final class AuthOrganizationUpdated extends AuthEvent {
  const AuthOrganizationUpdated(this.organization);
  final Organization organization;

  @override
  List<Object?> get props => [organization];
}

final class AuthPasswordResetRequested extends AuthEvent {
  const AuthPasswordResetRequested({required this.email});
  final String email;

  @override
  List<Object?> get props => [email];
}

final class AuthPasswordUpdateRequested extends AuthEvent {
  const AuthPasswordUpdateRequested({required this.newPassword});
  final String newPassword;

  @override
  List<Object?> get props => [newPassword];
}
