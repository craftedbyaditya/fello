import '../entities/feedback_analysis.dart';
import '../entities/complaint_task.dart';

/// Deterministic offline analyzer for mock mode and unit tests.
/// Mirrors the Edge Function decision rules without calling a provider.
class FeedbackAiHeuristic {
  const FeedbackAiHeuristic();

  AnalyzedFeedback analyze({
    required String responseId,
    required String orgId,
    required String text,
    double? rating,
  }) {
    final lower = text.toLowerCase();
    final categories = <String>{};
    final positives = <String>{};

    void detect(String needle, String category) {
      if (lower.contains(needle)) categories.add(category);
    }

    detect('wait', 'Waiting Time');
    detect('slow', 'Waiting Time');
    detect('delay', 'Waiting Time');
    detect('queue', 'Waiting Time');
    detect('staff', 'Staff');
    detect('rude', 'Staff');
    detect('helpful', 'Staff');
    detect('clean', 'Cleanliness');
    detect('dirty', 'Cleanliness');
    detect('price', 'Pricing');
    detect('expensive', 'Pricing');
    detect('quality', 'Quality');
    detect('taste', 'Quality');
    detect('safe', 'Safety');
    detect('communicat', 'Communication');

    if (lower.contains('helpful') || lower.contains('friendly') || lower.contains('good')) {
      positives.add('Positive staff or service mention');
    }
    if (lower.contains('clean')) positives.add('Cleanliness praised');

    final hasNegativeCue = RegExp(
      r'(bad|terrible|awful|worst|rude|dirty|slow|wait|delay|expensive|never|long line)',
    ).hasMatch(lower);
    final hasPositiveCue = RegExp(
      r'\b(good|great|helpful|friendly|excellent|love|amazing)\b',
    ).hasMatch(lower);
    final lowRating = rating != null && rating <= 2;

    FeedbackSentiment sentiment;
    if ((hasNegativeCue || lowRating) && hasPositiveCue) {
      sentiment = FeedbackSentiment.mixed;
    } else if (hasNegativeCue || lowRating) {
      sentiment = FeedbackSentiment.negative;
    } else if (hasPositiveCue || (rating != null && rating >= 4)) {
      sentiment = FeedbackSentiment.positive;
    } else {
      sentiment = FeedbackSentiment.neutral;
    }

    FeedbackUrgency urgency;
    if (sentiment == FeedbackSentiment.negative &&
        (categories.contains('Waiting Time') || (rating != null && rating <= 2))) {
      urgency = FeedbackUrgency.high;
    } else if (sentiment == FeedbackSentiment.mixed ||
        sentiment == FeedbackSentiment.negative) {
      urgency = FeedbackUrgency.medium;
    } else {
      urgency = FeedbackUrgency.low;
    }

    final primary = categories.isNotEmpty
        ? categories.first
        : (rating != null && rating <= 3 ? 'Service Quality' : 'General');

    final action = sentiment == FeedbackSentiment.negative ||
        sentiment == FeedbackSentiment.mixed ||
        urgency == FeedbackUrgency.high ||
        urgency == FeedbackUrgency.critical;

    final summary = text.trim().isEmpty
        ? 'Low rating without written comments.'
        : (text.length <= 140 ? text.trim() : '${text.trim().substring(0, 137)}...');

    return AnalyzedFeedback(
      analysis: FeedbackAnalysis(
        id: 'analysis-$responseId',
        orgId: orgId,
        responseId: responseId,
        sentiment: sentiment,
        primaryCategory: primary,
        categories: categories.isEmpty ? [primary] : categories.toList(),
        positiveAspects: positives.toList(),
        urgency: urgency,
        summary: summary,
        actionRecommended: action,
        confidence: 0.82,
        model: 'heuristic',
        createdAt: DateTime.now().toUtc(),
      ),
      shouldCreateTask: action,
      priority: ComplaintPriorityX.fromWire(urgency.wire),
    );
  }
}

class AnalyzedFeedback {
  const AnalyzedFeedback({
    required this.analysis,
    required this.shouldCreateTask,
    required this.priority,
  });

  final FeedbackAnalysis analysis;
  final bool shouldCreateTask;
  final ComplaintPriority priority;
}
