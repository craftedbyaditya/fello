import '../domain/plan_limit_failure.dart';

PlanLimitFailure? planLimitFromError(Object error) {
  final text = error.toString();
  if (text.contains('PLAN_LIMIT_SURVEYS')) {
    return const PlanLimitFailure(
      'Your plan’s survey limit is reached. Upgrade on Billing to add more surveys.',
    );
  }
  if (text.contains('PLAN_LIMIT_RESPONSES')) {
    return const PlanLimitFailure(
      'This workspace has reached its monthly response limit.',
      upgradeHint: false,
    );
  }
  return null;
}
