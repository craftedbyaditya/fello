import 'dart:async';

import '../../domain/entities/feedback_form.dart';
import '../../domain/entities/org_invite.dart';
import '../../domain/entities/organization.dart';
import '../../domain/entities/profile.dart';
import '../../domain/entities/response.dart';
import '../../domain/repositories/auth_repository.dart';
import 'mock_seed.dart';

/// Shared mutable store for all mock repositories.
class MockStore {
  MockStore({MockSeedData? seed}) : seed = seed ?? MockSeedData() {
    this.seed.registerSeed();
    organizations.addAll(this.seed.orgsById.values);
    profiles.addAll(this.seed.profilesById.values);
    passwords.addAll(this.seed.passwordsByEmail);
    forms.addAll(this.seed.forms);
    responses.addAll(this.seed.responses);
  }

  final MockSeedData seed;

  final List<Organization> organizations = [];
  final List<Profile> profiles = [];
  final Map<String, String> passwords = {};
  final List<FeedbackForm> forms = [];
  final List<FeedbackResponse> responses = [];
  final List<OrgInvite> invites = [];

  /// clientKey|formId → (windowStart, count)
  final Map<String, (DateTime, int)> submitRateWindows = {};
  final Set<String> submitDedupeIds = {};

  AuthSession? currentSession;
  final _authController = StreamController<AuthSession?>.broadcast();

  Stream<AuthSession?> get authStateChanges => _authController.stream;

  void setSession(AuthSession? session) {
    currentSession = session;
    _authController.add(session);
  }

  void dispose() {
    _authController.close();
  }
}
