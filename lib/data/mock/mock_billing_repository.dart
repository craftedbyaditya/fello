import '../../domain/auth_failure.dart';
import '../../domain/entities/subscription_plan.dart';
import '../../domain/repositories/billing_repository.dart';
import 'mock_store.dart';

class MockBillingRepository implements BillingRepository {
  MockBillingRepository(this._store);

  final MockStore _store;

  @override
  Future<PlanUsage> getUsage(String orgId) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final org = _store.organizations.firstWhere((o) => o.id == orgId);
    final now = DateTime.now().toUtc();
    final periodStart = DateTime.utc(now.year, now.month);
    final periodEnd = DateTime.utc(now.year, now.month + 1);
    final formIds = _store.forms
        .where((f) => f.orgId == orgId)
        .map((f) => f.id)
        .toSet();
    final responses = _store.responses.where((r) {
      if (!formIds.contains(r.formId)) return false;
      return !r.submittedAt.toUtc().isBefore(periodStart);
    }).length;
    return PlanUsage(
      plan: org.plan,
      surveyCount: formIds.length,
      responsesThisMonth: responses,
      periodStart: periodStart,
      periodEnd: periodEnd,
    );
  }

  @override
  Future<void> selectPlan({
    required String orgId,
    required PlanId planId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final session = _store.currentSession;
    if (session == null || !session.profile.isAdmin) {
      throw AuthFailure('Only admins can change the plan.');
    }
    if (session.organization.id != orgId) {
      throw AuthFailure('Workspace not found.');
    }
    // Mirror production: plan_id is locked until billing exists.
    throw AuthFailure(
      'Paid plans unlock with billing. Self-serve upgrades are not available yet — '
      'you’re on your current plan until payments go live.',
    );
  }
}
