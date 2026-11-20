import '../entities/business_type.dart';
import '../entities/organization.dart';
import '../entities/profile.dart';

class AuthSession {
  const AuthSession({required this.profile, required this.organization});

  final Profile profile;
  final Organization organization;

  AuthSession copyWith({Profile? profile, Organization? organization}) {
    return AuthSession(
      profile: profile ?? this.profile,
      organization: organization ?? this.organization,
    );
  }
}

abstract class AuthRepository {
  Stream<AuthSession?> get authStateChanges;
  AuthSession? get currentSession;

  Future<AuthSession> signIn({required String email, required String password});

  /// Starts the browser-based Google OAuth fallback flow.
  Future<void> signInWithGoogleOAuth();

  /// Exchanges a Google Identity Services One Tap ID token for a Supabase
  /// session. The browser never receives a Supabase service-role credential.
  Future<AuthSession> signInWithGoogleIdToken({
    required String idToken,
    required String nonce,
  });

  Future<AuthSession> signUp({
    required String email,
    required String password,
    required String displayName,
    String? inviteToken,
  });

  Future<void> signOut();

  /// Sends a password-reset email (Supabase recovery link).
  Future<void> requestPasswordReset({required String email});

  /// Sets a new password after the user opens a recovery link.
  Future<void> updatePassword({required String newPassword});

  Future<Organization> updateOrganization({required String name, String? slug});

  /// Uploads (or removes) a workspace logo image and toggles public display.
  /// Paid plans only. [imageBytes] is a PNG/JPEG/WebP/SVG upload from the client.
  Future<Organization> updateWorkspaceLogo({
    List<int>? imageBytes,
    String? contentType,
    String? fileExtension,
    required bool showOnForms,
    bool removeLogo = false,
  });

  /// Confirms workspace name, optionally stores business type, and marks
  /// onboarding complete so the user lands on the dashboard.
  Future<AuthSession> completeOnboarding({
    required String organizationName,
    BusinessType? businessType,
  });
}
