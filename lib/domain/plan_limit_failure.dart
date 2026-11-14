/// Thrown when an action would exceed the organisation's subscription limits.
class PlanLimitFailure implements Exception {
  const PlanLimitFailure(this.message, {this.upgradeHint = true});

  final String message;
  final bool upgradeHint;

  @override
  String toString() => message;
}
