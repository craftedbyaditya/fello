import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/auth_failure.dart';
import '../../domain/entities/subscription_plan.dart';
import '../../domain/repositories/billing_repository.dart';

class SupabaseBillingRepository implements BillingRepository {
  SupabaseBillingRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<PlanUsage> getUsage(String orgId) async {
    try {
      final org = await _client
          .from('organizations')
          .select('plan_id')
          .eq('id', orgId)
          .single();
      final plan = SubscriptionPlan.byId(
        PlanIdX.fromWire(org['plan_id'] as String?),
      );

      final surveyCount = await _client.rpc(
        'org_survey_count',
        params: {'p_org_id': orgId},
      );
      final responseCount = await _client.rpc(
        'org_response_count_this_month',
        params: {'p_org_id': orgId},
      );

      final now = DateTime.now().toUtc();
      final periodStart = DateTime.utc(now.year, now.month);
      final periodEnd = DateTime.utc(now.year, now.month + 1);

      return PlanUsage(
        plan: plan,
        surveyCount: (surveyCount as num?)?.toInt() ?? 0,
        responsesThisMonth: (responseCount as num?)?.toInt() ?? 0,
        periodStart: periodStart,
        periodEnd: periodEnd,
      );
    } on PostgrestException catch (e) {
      throw AuthFailure(
        e.message.isNotEmpty ? e.message : "Couldn't load plan usage.",
      );
    }
  }

  @override
  Future<void> selectPlan({
    required String orgId,
    required PlanId planId,
  }) async {
    // Entitlements are locked in Postgres until payment webhooks land.
    // Do not write plan_id from the client.
    throw AuthFailure(
      'Paid plans unlock with billing. Self-serve upgrades are not available yet — '
      'you’re on your current plan until payments go live.',
    );
  }
}
