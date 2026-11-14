import 'package:equatable/equatable.dart';

/// Kaydo monthly subscription catalog (INR).
enum PlanId {
  free,
  starter,
  growth,
  custom,
}

extension PlanIdX on PlanId {
  String get wireName => name;

  static PlanId fromWire(String? value) {
    return PlanId.values.firstWhere(
      (p) => p.name == value,
      orElse: () => PlanId.free,
    );
  }
}

class SubscriptionPlan extends Equatable {
  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.tagline,
    required this.priceInrMonthly,
    required this.maxSurveys,
    required this.maxResponsesPerMonth,
    required this.highlights,
    this.isCustom = false,
  });

  final PlanId id;
  final String name;
  final String tagline;

  /// Monthly price in Indian rupees. `0` = free.
  final int priceInrMonthly;

  /// Max surveys (forms) in the workspace. `null` = unlimited.
  final int? maxSurveys;

  /// Max responses collected per calendar month. `null` = unlimited.
  final int? maxResponsesPerMonth;

  final List<String> highlights;
  final bool isCustom;

  String get priceLabel =>
      priceInrMonthly == 0 ? 'Free' : '₹$priceInrMonthly/mo';

  String get surveysLabel =>
      maxSurveys == null ? 'Unlimited surveys' : '$maxSurveys surveys';

  String get responsesLabel => maxResponsesPerMonth == null
      ? 'Unlimited responses / month'
      : '$maxResponsesPerMonth responses / month';

  bool allowsAnotherSurvey(int currentSurveyCount) {
    final max = maxSurveys;
    if (max == null) return true;
    return currentSurveyCount < max;
  }

  bool allowsAnotherResponse(int responsesThisMonth) {
    final max = maxResponsesPerMonth;
    if (max == null) return true;
    return responsesThisMonth < max;
  }

  /// Workspace logo on public forms is a paid-plan feature.
  bool get allowsWorkspaceLogo => id != PlanId.free;

  static const free = SubscriptionPlan(
    id: PlanId.free,
    name: 'Free',
    tagline: 'Try Kaydo with light limits',
    priceInrMonthly: 0,
    maxSurveys: 1,
    maxResponsesPerMonth: 50,
    highlights: [
      '1 survey',
      '50 responses / month',
      'Dashboard & exports',
    ],
  );

  static const starter = SubscriptionPlan(
    id: PlanId.starter,
    name: 'Starter',
    tagline: 'For a single location getting started',
    priceInrMonthly: 99,
    maxSurveys: 2,
    maxResponsesPerMonth: 250,
    highlights: [
      '2 surveys',
      '250 responses / month',
      'Share links & QR',
      'Team invites',
      'Workspace logo',
    ],
  );

  static const growth = SubscriptionPlan(
    id: PlanId.growth,
    name: 'Growth',
    tagline: 'For growing multi-location teams',
    priceInrMonthly: 499,
    maxSurveys: 10,
    maxResponsesPerMonth: 2500,
    highlights: [
      '10 surveys',
      '2,500 responses / month',
      'Everything in Starter',
      'Workspace logo',
      'Priority dashboard refresh',
    ],
  );

  static const custom = SubscriptionPlan(
    id: PlanId.custom,
    name: 'Custom',
    tagline: 'Higher volume & tailored limits',
    priceInrMonthly: 999,
    maxSurveys: null,
    maxResponsesPerMonth: 10000,
    isCustom: true,
    highlights: [
      'Unlimited surveys',
      '10,000 responses / month',
      'Workspace logo',
      'Custom limits on request',
      'Priority support',
    ],
  );

  static const List<SubscriptionPlan> catalog = [
    free,
    starter,
    growth,
    custom,
  ];

  static const List<SubscriptionPlan> paidCatalog = [
    starter,
    growth,
    custom,
  ];

  static SubscriptionPlan byId(PlanId id) {
    return catalog.firstWhere((p) => p.id == id, orElse: () => free);
  }

  @override
  List<Object?> get props => [
        id,
        name,
        tagline,
        priceInrMonthly,
        maxSurveys,
        maxResponsesPerMonth,
        highlights,
        isCustom,
      ];
}

class PlanUsage extends Equatable {
  const PlanUsage({
    required this.plan,
    required this.surveyCount,
    required this.responsesThisMonth,
    required this.periodStart,
    required this.periodEnd,
  });

  final SubscriptionPlan plan;
  final int surveyCount;
  final int responsesThisMonth;
  final DateTime periodStart;
  final DateTime periodEnd;

  bool get atSurveyLimit => !plan.allowsAnotherSurvey(surveyCount);
  bool get atResponseLimit =>
      !plan.allowsAnotherResponse(responsesThisMonth);

  double? get surveyProgress {
    final max = plan.maxSurveys;
    if (max == null || max == 0) return null;
    return (surveyCount / max).clamp(0.0, 1.0);
  }

  double? get responseProgress {
    final max = plan.maxResponsesPerMonth;
    if (max == null || max == 0) return null;
    return (responsesThisMonth / max).clamp(0.0, 1.0);
  }

  @override
  List<Object?> get props =>
      [plan, surveyCount, responsesThisMonth, periodStart, periodEnd];
}
