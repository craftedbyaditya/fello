import 'package:equatable/equatable.dart';

import 'business_type.dart';
import 'subscription_plan.dart';

class Organization extends Equatable {
  const Organization({
    required this.id,
    required this.name,
    required this.slug,
    required this.createdAt,
    this.businessType,
    this.onboardingCompletedAt,
    this.planId = PlanId.free,
    this.planStatus = 'active',
    this.logoUrl,
    this.showLogoOnForms = false,
  });

  final String id;
  final String name;
  final String slug;
  final DateTime createdAt;
  final BusinessType? businessType;
  final DateTime? onboardingCompletedAt;
  final PlanId planId;
  final String planStatus;
  final String? logoUrl;
  final bool showLogoOnForms;

  bool get needsOnboarding => onboardingCompletedAt == null;

  bool get hasLogo => logoUrl != null && logoUrl!.trim().isNotEmpty;

  bool get displaysLogoOnForms => showLogoOnForms && hasLogo;

  SubscriptionPlan get plan => SubscriptionPlan.byId(planId);

  Organization copyWith({
    String? id,
    String? name,
    String? slug,
    DateTime? createdAt,
    BusinessType? businessType,
    DateTime? onboardingCompletedAt,
    PlanId? planId,
    String? planStatus,
    String? logoUrl,
    bool? showLogoOnForms,
    bool clearBusinessType = false,
    bool clearOnboardingCompletedAt = false,
    bool clearLogoUrl = false,
  }) {
    return Organization(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      createdAt: createdAt ?? this.createdAt,
      businessType:
          clearBusinessType ? null : (businessType ?? this.businessType),
      onboardingCompletedAt: clearOnboardingCompletedAt
          ? null
          : (onboardingCompletedAt ?? this.onboardingCompletedAt),
      planId: planId ?? this.planId,
      planStatus: planStatus ?? this.planStatus,
      logoUrl: clearLogoUrl ? null : (logoUrl ?? this.logoUrl),
      showLogoOnForms: showLogoOnForms ?? this.showLogoOnForms,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        slug,
        createdAt,
        businessType,
        onboardingCompletedAt,
        planId,
        planStatus,
        logoUrl,
        showLogoOnForms,
      ];
}
