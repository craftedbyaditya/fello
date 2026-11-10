import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/organization.dart';
import '../../domain/entities/profile.dart';
import '../../domain/repositories/auth_repository.dart';

/// Production auth repository. Requires valid SUPABASE_URL + ANON_KEY.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  Stream<AuthSession?> get authStateChanges async* {
    yield await _loadSession();
    await for (final state in _client.auth.onAuthStateChange) {
      if (state.session == null) {
        yield null;
      } else {
        yield await _loadSession();
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
    await _client.auth.signInWithPassword(email: email, password: password);
    final session = await _loadSession();
    if (session == null) throw Exception('Unable to load profile.');
    return session;
  }

  @override
  Future<AuthSession> signUp({
    required String email,
    required String password,
    required String organizationName,
    required String displayName,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'display_name': displayName,
        'organization_name': organizationName,
      },
    );
    if (response.user == null) {
      throw Exception('Sign up failed.');
    }
    // Profile + org created by DB trigger on auth.users
    final session = await _loadSession();
    if (session == null) {
      throw Exception(
        'Account created. Confirm email if required, then sign in.',
      );
    }
    return session;
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<Organization> updateOrganization({
    required String name,
    String? slug,
  }) async {
    final session = await _loadSession();
    if (session == null) throw Exception('Not signed in.');
    final payload = <String, dynamic>{'name': name};
    if (slug != null && slug.isNotEmpty) payload['slug'] = slug;
    final row = await _client
        .from('organizations')
        .update(payload)
        .eq('id', session.organization.id)
        .select()
        .single();
    return Organization(
      id: row['id'] as String,
      name: row['name'] as String,
      slug: row['slug'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  Future<AuthSession?> _loadSession() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final profileRow = await _client
        .from('profiles')
        .select('*, organizations(*)')
        .eq('id', user.id)
        .maybeSingle();
    if (profileRow == null) return null;
    final org = profileRow['organizations'] as Map<String, dynamic>;
    return AuthSession(
      profile: Profile(
        id: profileRow['id'] as String,
        orgId: profileRow['org_id'] as String,
        displayName: profileRow['display_name'] as String? ?? '',
        email: user.email ?? '',
        role: (profileRow['role'] as String?) == 'member'
            ? ProfileRole.member
            : ProfileRole.admin,
      ),
      organization: Organization(
        id: org['id'] as String,
        name: org['name'] as String,
        slug: org['slug'] as String,
        createdAt: DateTime.parse(org['created_at'] as String),
      ),
    );
  }
}
