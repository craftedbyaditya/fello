import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/auth_failure.dart';
import '../../domain/entities/business_type.dart';
import '../../domain/entities/organization.dart';
import '../../domain/entities/profile.dart';
import '../../domain/entities/subscription_plan.dart';
import '../../domain/repositories/auth_repository.dart';

/// Production auth repository. Requires valid SUPABASE_URL + ANON_KEY.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;
  static const _timeout = Duration(seconds: 20);

  @override
  Stream<AuthSession?> get authStateChanges async* {
    yield await _loadSession();
    await for (final state in _client.auth.onAuthStateChange) {
      if (state.session == null) {
        yield null;
      } else {
        yield await _loadSessionWithRetry();
      }
    }
  }

  @override
  AuthSession? get currentSession => null;

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth
          .signInWithPassword(email: email.trim(), password: password)
          .timeout(_timeout);
      final session = await _loadSessionWithRetry();
      if (session == null) {
        throw AuthFailure(
          'Signed in, but your workspace profile is missing. '
          'Confirm database migrations were applied.',
        );
      }
      return session;
    } on AuthFailure {
      rethrow;
    } on AuthException catch (e) {
      throw AuthFailure(_friendlyAuthMessage(e));
    } on TimeoutException {
      throw AuthFailure(
        'Sign-in timed out. Check your connection and Supabase keys.',
      );
    } catch (_) {
      throw AuthFailure("We couldn't sign you in. Please try again.");
    }
  }

  @override
  Future<void> signInWithGoogleOAuth() async {
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: _publicRedirectBase(),
      );
    } on AuthException catch (e) {
      throw AuthFailure(_friendlyAuthMessage(e));
    } catch (_) {
      throw AuthFailure("We couldn't start Google sign-in. Please try again.");
    }
  }

  @override
  Future<AuthSession> signInWithGoogleIdToken({required String idToken}) async {
    try {
      await _client.auth
          .signInWithIdToken(provider: OAuthProvider.google, idToken: idToken)
          .timeout(_timeout);
      final session = await _loadSessionWithRetry();
      if (session == null) {
        throw AuthFailure(
          'Google signed you in, but your workspace profile is missing.',
        );
      }
      return session;
    } on AuthFailure {
      rethrow;
    } on AuthException catch (e) {
      throw AuthFailure(_friendlyAuthMessage(e));
    } on TimeoutException {
      throw AuthFailure('Google sign-in timed out. Please try again.');
    } catch (_) {
      throw AuthFailure(
        "We couldn't complete Google sign-in. Please try again.",
      );
    }
  }

  @override
  Future<AuthSession> signUp({
    required String email,
    required String password,
    required String displayName,
    String? inviteToken,
  }) async {
    try {
      final meta = <String, dynamic>{'display_name': displayName.trim()};
      final token = inviteToken?.trim();
      if (token != null && token.isNotEmpty) {
        meta['invite_token'] = token;
      }
      final response = await _client.auth
          .signUp(email: email.trim(), password: password, data: meta)
          .timeout(_timeout);

      if (response.user == null) {
        throw AuthFailure("We couldn't create your account. Please try again.");
      }

      // Email confirmation enabled → no session until user confirms.
      if (response.session == null) {
        throw AuthFailure(
          'Account created. Check your email to confirm, then sign in.',
        );
      }

      final session = await _loadSessionWithRetry();
      if (session == null) {
        throw AuthFailure(
          'Account created, but workspace setup failed. '
          'Apply SQL migrations in supabase/migrations/, then sign in again.',
        );
      }
      return session;
    } on AuthFailure {
      rethrow;
    } on AuthException catch (e) {
      throw AuthFailure(_friendlyAuthMessage(e));
    } on TimeoutException {
      throw AuthFailure(
        'Sign-up timed out. Check your connection and Supabase keys.',
      );
    } catch (_) {
      throw AuthFailure("We couldn't create your account. Please try again.");
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<void> requestPasswordReset({required String email}) async {
    try {
      await _client.auth
          .resetPasswordForEmail(
            email.trim(),
            redirectTo: '${_publicRedirectBase()}/reset-password',
          )
          .timeout(_timeout);
    } on AuthException catch (e) {
      throw AuthFailure(_friendlyAuthMessage(e));
    } on TimeoutException {
      throw AuthFailure('Request timed out. Please try again.');
    } catch (_) {
      throw AuthFailure("We couldn't send a reset email. Please try again.");
    }
  }

  @override
  Future<void> updatePassword({required String newPassword}) async {
    try {
      await _client.auth
          .updateUser(UserAttributes(password: newPassword))
          .timeout(_timeout);
    } on AuthException catch (e) {
      throw AuthFailure(_friendlyAuthMessage(e));
    } on TimeoutException {
      throw AuthFailure('Update timed out. Please try again.');
    } catch (_) {
      throw AuthFailure("We couldn't update your password. Please try again.");
    }
  }

  String _publicRedirectBase() {
    // Recovery links should land on the deployed web origin.
    // AppConfig is not injected here; use current browser origin on web.
    return Uri.base.origin;
  }

  @override
  Future<Organization> updateOrganization({
    required String name,
    String? slug,
  }) async {
    final session = await _loadSession();
    if (session == null) {
      throw AuthFailure("We couldn't update your workspace. Please try again.");
    }
    final payload = <String, dynamic>{'name': name};
    if (slug != null && slug.isNotEmpty) payload['slug'] = slug;
    try {
      final row = await _client
          .from('organizations')
          .update(payload)
          .eq('id', session.organization.id)
          .select()
          .single()
          .timeout(_timeout);
      return _organizationFromRow(row);
    } on AuthFailure {
      rethrow;
    } on TimeoutException {
      throw AuthFailure('Update timed out. Please try again.');
    } catch (_) {
      throw AuthFailure("We couldn't update your workspace. Please try again.");
    }
  }

  @override
  Future<Organization> updateWorkspaceLogo({
    List<int>? imageBytes,
    String? contentType,
    String? fileExtension,
    required bool showOnForms,
    bool removeLogo = false,
  }) async {
    final session = await _loadSession();
    if (session == null) {
      throw AuthFailure("We couldn't update your logo. Please try again.");
    }
    if (!session.organization.plan.allowsWorkspaceLogo) {
      throw AuthFailure(
        'Workspace logo is available on paid plans. Upgrade on Billing.',
      );
    }

    final orgId = session.organization.id;
    String? nextUrl = session.organization.logoUrl;

    try {
      if (removeLogo) {
        await _deleteOrgLogos(orgId);
        nextUrl = null;
      } else if (imageBytes != null && imageBytes.isNotEmpty) {
        final ext = _normalizeLogoExt(fileExtension, contentType);
        final mime = contentType ?? _mimeForExt(ext);
        final path = '$orgId/logo.$ext';
        await _client.storage
            .from('org-logos')
            .uploadBinary(
              path,
              Uint8List.fromList(imageBytes),
              fileOptions: FileOptions(contentType: mime, upsert: true),
            );
        final publicUrl = _client.storage.from('org-logos').getPublicUrl(path);
        nextUrl = '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';
      }

      final row = await _client
          .from('organizations')
          .update({'show_logo_on_forms': showOnForms, 'logo_url': nextUrl})
          .eq('id', orgId)
          .select()
          .single()
          .timeout(_timeout);
      return _organizationFromRow(row);
    } on AuthFailure {
      rethrow;
    } on TimeoutException {
      throw AuthFailure('Update timed out. Please try again.');
    } on StorageException catch (e) {
      throw AuthFailure(
        e.message.isNotEmpty
            ? e.message
            : "We couldn't upload your logo. Please try again.",
      );
    } on PostgrestException catch (e) {
      if (e.message.contains('PLAN_LIMIT_LOGO')) {
        throw AuthFailure(
          'Workspace logo is available on paid plans. Upgrade on Billing.',
        );
      }
      throw AuthFailure(
        e.message.isNotEmpty
            ? e.message
            : "We couldn't update your logo. Please try again.",
      );
    } catch (_) {
      throw AuthFailure("We couldn't update your logo. Please try again.");
    }
  }

  Future<void> _deleteOrgLogos(String orgId) async {
    try {
      final listed = await _client.storage.from('org-logos').list(path: orgId);
      if (listed.isEmpty) return;
      await _client.storage
          .from('org-logos')
          .remove(listed.map((f) => '$orgId/${f.name}').toList());
    } catch (_) {
      // Best-effort cleanup; org row still clears logo_url.
    }
  }

  String _normalizeLogoExt(String? fileExtension, String? contentType) {
    final fromName = fileExtension?.toLowerCase().replaceAll('.', '');
    if (fromName == 'png' ||
        fromName == 'jpg' ||
        fromName == 'jpeg' ||
        fromName == 'webp' ||
        fromName == 'svg') {
      return fromName == 'jpeg' ? 'jpg' : fromName!;
    }
    return switch (contentType) {
      'image/jpeg' => 'jpg',
      'image/webp' => 'webp',
      'image/svg+xml' => 'svg',
      _ => 'png',
    };
  }

  String _mimeForExt(String ext) {
    return switch (ext) {
      'jpg' => 'image/jpeg',
      'webp' => 'image/webp',
      'svg' => 'image/svg+xml',
      _ => 'image/png',
    };
  }

  @override
  Future<AuthSession> completeOnboarding({
    required String organizationName,
    BusinessType? businessType,
  }) async {
    final session = await _loadSession();
    if (session == null) {
      throw AuthFailure("We couldn't create your workspace. Please try again.");
    }
    final trimmed = organizationName.trim();
    if (trimmed.isEmpty) {
      throw AuthFailure('Organisation name is required.');
    }

    final payload = <String, dynamic>{
      'name': trimmed,
      'business_type': businessType?.id,
      'onboarding_completed_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      await _client
          .from('organizations')
          .update(payload)
          .eq('id', session.organization.id)
          .timeout(_timeout);
    } on TimeoutException {
      throw AuthFailure('Onboarding timed out. Please try again.');
    } catch (_) {
      throw AuthFailure("We couldn't create your workspace. Please try again.");
    }

    final refreshed = await _loadSessionWithRetry();
    if (refreshed == null) {
      throw AuthFailure("We couldn't create your workspace. Please try again.");
    }
    return refreshed;
  }

  Future<AuthSession?> _loadSessionWithRetry() async {
    // Trigger handle_new_user may lag a moment behind auth.users insert.
    for (var attempt = 0; attempt < 6; attempt++) {
      final session = await _loadSession();
      if (session != null) return session;
      await Future<void>.delayed(Duration(milliseconds: 250 * (attempt + 1)));
    }
    return null;
  }

  Future<AuthSession?> _loadSession() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    try {
      final profileRow = await _client
          .from('profiles')
          .select('*, organizations(*)')
          .eq('id', user.id)
          .maybeSingle()
          .timeout(_timeout);
      if (profileRow == null) return null;
      final org = profileRow['organizations'] as Map<String, dynamic>?;
      if (org == null) return null;
      final profileEmail = (profileRow['email'] as String?)?.trim();
      final createdRaw = profileRow['created_at'] as String?;
      return AuthSession(
        profile: Profile(
          id: profileRow['id'] as String,
          orgId: profileRow['org_id'] as String,
          displayName: profileRow['display_name'] as String? ?? '',
          email: (profileEmail != null && profileEmail.isNotEmpty)
              ? profileEmail
              : (user.email ?? ''),
          role: (profileRow['role'] as String?) == 'employee'
              ? ProfileRole.employee
              : ProfileRole.admin,
          createdAt: createdRaw == null ? null : DateTime.parse(createdRaw),
        ),
        organization: _organizationFromRow(org),
      );
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Organization _organizationFromRow(Map<String, dynamic> org) {
    final completedRaw = org['onboarding_completed_at'] as String?;
    final logo = (org['logo_url'] as String?)?.trim();
    return Organization(
      id: org['id'] as String,
      name: org['name'] as String,
      slug: org['slug'] as String,
      createdAt: DateTime.parse(org['created_at'] as String),
      businessType: BusinessType.fromId(org['business_type'] as String?),
      onboardingCompletedAt: completedRaw == null
          ? null
          : DateTime.parse(completedRaw),
      planId: PlanIdX.fromWire(org['plan_id'] as String?),
      planStatus: org['plan_status'] as String? ?? 'active',
      logoUrl: (logo == null || logo.isEmpty) ? null : logo,
      showLogoOnForms: org['show_logo_on_forms'] as bool? ?? false,
    );
  }

  String _friendlyAuthMessage(AuthException e) {
    final message = e.message.toLowerCase();
    if (message.contains('invalid login')) {
      return 'Invalid email or password.';
    }
    if (message.contains('already registered') ||
        message.contains('user already')) {
      return 'An account with this email already exists. Sign in instead.';
    }
    if (message.contains('password')) {
      return 'Password must be at least 6 characters.';
    }
    if (message.contains('email')) {
      return e.message;
    }
    return e.message.isNotEmpty
        ? e.message
        : "We couldn't complete authentication. Please try again.";
  }
}
