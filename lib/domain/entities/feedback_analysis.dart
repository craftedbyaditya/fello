import 'package:equatable/equatable.dart';

enum FeedbackSentiment { positive, neutral, mixed, negative }

enum FeedbackUrgency { low, medium, high, critical }

extension FeedbackSentimentX on FeedbackSentiment {
  String get wire => name;

  static FeedbackSentiment fromWire(String? value) {
    return FeedbackSentiment.values.firstWhere(
      (e) => e.name == value,
      orElse: () => FeedbackSentiment.neutral,
    );
  }

  String get label => switch (this) {
        FeedbackSentiment.positive => 'Positive',
        FeedbackSentiment.neutral => 'Neutral',
        FeedbackSentiment.mixed => 'Mixed',
        FeedbackSentiment.negative => 'Negative',
      };
}

extension FeedbackUrgencyX on FeedbackUrgency {
  String get wire => name;

  static FeedbackUrgency fromWire(String? value) {
    return FeedbackUrgency.values.firstWhere(
      (e) => e.name == value,
      orElse: () => FeedbackUrgency.low,
    );
  }

  String get label => switch (this) {
        FeedbackUrgency.low => 'Low',
        FeedbackUrgency.medium => 'Medium',
        FeedbackUrgency.high => 'High',
        FeedbackUrgency.critical => 'Critical',
      };
}

class FeedbackAnalysis extends Equatable {
  const FeedbackAnalysis({
    required this.id,
    required this.orgId,
    required this.responseId,
    required this.sentiment,
    required this.primaryCategory,
    required this.categories,
    required this.positiveAspects,
    required this.urgency,
    required this.summary,
    required this.actionRecommended,
    required this.confidence,
    required this.createdAt,
    this.model,
  });

  final String id;
  final String orgId;
  final String responseId;
  final FeedbackSentiment sentiment;
  final String primaryCategory;
  final List<String> categories;
  final List<String> positiveAspects;
  final FeedbackUrgency urgency;
  final String summary;
  final bool actionRecommended;
  final double confidence;
  final String? model;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
        id,
        orgId,
        responseId,
        sentiment,
        primaryCategory,
        categories,
        positiveAspects,
        urgency,
        summary,
        actionRecommended,
        confidence,
        model,
        createdAt,
      ];
}
