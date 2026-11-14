import '../entities/subscription_plan.dart';

abstract class BillingRepository {
  Future<PlanUsage> getUsage(String orgId);

  /// Reserved for payment webhooks. Client calls currently fail closed
  /// (plan_id is locked in Postgres until billing ships).
  Future<void> selectPlan({
    required String orgId,
    required PlanId planId,
  });
}
