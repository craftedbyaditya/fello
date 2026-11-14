import 'package:equatable/equatable.dart';

import 'question.dart';

enum FormStatus { draft, published }

class FeedbackForm extends Equatable {
  const FeedbackForm({
    required this.id,
    required this.orgId,
    required this.title,
    required this.description,
    required this.slug,
    required this.status,
    required this.createdAt,
    this.questions = const [],
    this.orgLogoUrl,
    this.showOrgLogo = false,
    this.orgAllowsLogo = false,
  });

  final String id;
  final String orgId;
  final String title;
  final String description;
  final String slug;
  final FormStatus status;
  final DateTime createdAt;
  final List<Question> questions;
  final String? orgLogoUrl;
  final bool showOrgLogo;

  /// Paid-plan gate mirrored from the org (free plans never display).
  final bool orgAllowsLogo;

  bool get isPublished => status == FormStatus.published;

  bool get displaysOrgLogo =>
      orgAllowsLogo &&
      showOrgLogo &&
      orgLogoUrl != null &&
      orgLogoUrl!.trim().isNotEmpty;

  FeedbackForm copyWith({
    String? id,
    String? orgId,
    String? title,
    String? description,
    String? slug,
    FormStatus? status,
    DateTime? createdAt,
    List<Question>? questions,
    String? orgLogoUrl,
    bool? showOrgLogo,
    bool? orgAllowsLogo,
    bool clearOrgLogoUrl = false,
  }) {
    return FeedbackForm(
      id: id ?? this.id,
      orgId: orgId ?? this.orgId,
      title: title ?? this.title,
      description: description ?? this.description,
      slug: slug ?? this.slug,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      questions: questions ?? this.questions,
      orgLogoUrl:
          clearOrgLogoUrl ? null : (orgLogoUrl ?? this.orgLogoUrl),
      showOrgLogo: showOrgLogo ?? this.showOrgLogo,
      orgAllowsLogo: orgAllowsLogo ?? this.orgAllowsLogo,
    );
  }

  @override
  List<Object?> get props => [
        id,
        orgId,
        title,
        description,
        slug,
        status,
        createdAt,
        questions,
        orgLogoUrl,
        showOrgLogo,
        orgAllowsLogo,
      ];
}
