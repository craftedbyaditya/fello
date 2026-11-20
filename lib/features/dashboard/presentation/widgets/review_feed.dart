import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/fello_colors.dart';
import '../../../../core/theme/fello_metrics.dart';
import '../../../../domain/entities/complaint_task.dart';
import '../../../../domain/entities/feedback_analysis.dart';
import '../../../../domain/entities/feedback_form.dart';
import '../../../../domain/entities/question.dart';
import '../../../../domain/entities/response.dart';
import '../../../../domain/repositories/response_repository.dart';
import '../../../../domain/repositories/workflow_repository.dart';
import '../../../../shared/widgets/kaydo_toast.dart';
import '../../../auth/bloc/auth_bloc.dart';
import '../../../complaints/presentation/widgets/ai_insight_panel.dart';

const reviewStarYellow = Color(0xFFF5C518);

enum ReviewSort { recent, highest, photos }

class ReviewAnswer {
  const ReviewAnswer({
    required this.questionId,
    required this.label,
    required this.type,
    required this.value,
  });

  final String questionId;
  final String label;
  final QuestionType type;
  final dynamic value;

  bool get hasValue {
    if (value == null) return false;
    if (value is String) return value.trim().isNotEmpty;
    if (value is List) return value.isNotEmpty;
    return true;
  }

  String get displayText {
    if (!hasValue) return 'No answer';
    switch (type) {
      case QuestionType.starRating:
        return '${(value as num).round()} / 5';
      case QuestionType.nps:
        return '${(value as num).round()} / 10';
      case QuestionType.yesNo:
        if (value is bool) return value ? 'Yes' : 'No';
        final text = '$value'.trim().toLowerCase();
        if (text == 'true' || text == 'yes') return 'Yes';
        if (text == 'false' || text == 'no') return 'No';
        return '$value';
      case QuestionType.multiChoice:
        if (value is List) {
          return value.map((e) => '$e').where((e) => e.isNotEmpty).join(', ');
        }
        return '$value';
      case QuestionType.singleChoice:
      case QuestionType.shortText:
      case QuestionType.longText:
        return '$value'.trim();
    }
  }
}

class ReviewItem {
  const ReviewItem({
    required this.id,
    required this.formId,
    required this.displayName,
    required this.submittedAt,
    required this.location,
    required this.stars,
    required this.answers,
    this.formVersion,
    this.isPublic = false,
  });

  final String id;
  final String formId;
  final String displayName;
  final DateTime submittedAt;
  final String location;
  final int stars;
  final List<ReviewAnswer> answers;
  final int? formVersion;
  final bool isPublic;

  bool get hasTextAnswer => answers.any(
    (a) =>
        (a.type == QuestionType.shortText || a.type == QuestionType.longText) &&
        a.hasValue,
  );

  String get previewText {
    for (final answer in answers) {
      if ((answer.type == QuestionType.shortText ||
              answer.type == QuestionType.longText) &&
          answer.hasValue) {
        return answer.displayText;
      }
    }
    for (final answer in answers) {
      if ((answer.type == QuestionType.singleChoice ||
              answer.type == QuestionType.multiChoice ||
              answer.type == QuestionType.yesNo) &&
          answer.hasValue) {
        return answer.displayText;
      }
    }
    return '${answers.length} answer${answers.length == 1 ? '' : 's'}';
  }

  String get searchableText => [
    displayName,
    location,
    for (final answer in answers) ...[answer.label, answer.displayText],
  ].join(' ').toLowerCase();
}

class ReviewSummary {
  ReviewSummary({
    required this.avgRating,
    required this.totalReviews,
    required this.fiveStarPct,
    required this.thisMonthAvg,
    required this.monthDelta,
    required this.volumeDeltaPct,
    required this.starCounts,
    required this.categoryScores,
    required this.reviews,
  });

  final double avgRating;
  final int totalReviews;
  final double fiveStarPct;
  final double thisMonthAvg;
  final double monthDelta;
  final int volumeDeltaPct;
  final Map<int, int> starCounts;
  final Map<String, double> categoryScores;
  final List<ReviewItem> reviews;

  factory ReviewSummary.from(
    FeedbackForm form,
    List<FeedbackResponse> responses,
  ) {
    final formResponses = responses
        .where((r) => r.formId == form.id)
        .toList(growable: false);
    final starCounts = {for (var i = 1; i <= 5; i++) i: 0};
    final ratings = <double>[];
    final thisMonthRatings = <double>[];
    final lastMonthRatings = <double>[];
    final now = DateTime.now();
    final reviews = <ReviewItem>[];

    final currentQuestions = {for (final q in form.questions) q.id: q};
    final questionAverages = <String, List<double>>{};

    for (var index = 0; index < formResponses.length; index++) {
      final response = formResponses[index];
      final mappedAnswers = <ReviewAnswer>[
        for (final answer in response.answers)
          ReviewAnswer(
            questionId: answer.questionId,
            // A response carries its original definition. Current questions
            // are used only as a compatibility fallback for pre-version data.
            label:
                answer.questionLabel ??
                currentQuestions[answer.questionId]?.label ??
                'Question',
            type: QuestionType.values.firstWhere(
              (type) => type.name == answer.questionType,
              orElse: () =>
                  currentQuestions[answer.questionId]?.type ??
                  QuestionType.shortText,
            ),
            value: _unwrapAnswerValue(answer.value),
          ),
      ];

      var stars = 0;
      for (final answer in mappedAnswers) {
        if (answer.type != QuestionType.starRating || answer.value is! num) {
          continue;
        }
        final score = (answer.value as num).round().clamp(1, 5);
        questionAverages
            .putIfAbsent(answer.label, () => <double>[])
            .add(score.toDouble());
        if (stars == 0) stars = score;
      }
      if (stars == 0) {
        for (final answer in mappedAnswers) {
          if (answer.type == QuestionType.nps && answer.value is num) {
            final nps = (answer.value as num).toDouble();
            stars = ((nps / 2).round()).clamp(1, 5);
            break;
          }
        }
      }

      if (stars > 0) {
        starCounts[stars] = (starCounts[stars] ?? 0) + 1;
        ratings.add(stars.toDouble());
      }

      final submitted = response.submittedAt;
      if (stars > 0) {
        if (submitted.year == now.year && submitted.month == now.month) {
          thisMonthRatings.add(stars.toDouble());
        } else if ((submitted.year == now.year &&
                submitted.month == now.month - 1) ||
            (now.month == 1 &&
                submitted.year == now.year - 1 &&
                submitted.month == 12)) {
          lastMonthRatings.add(stars.toDouble());
        }
      }

      final metaName =
          response.metadata['displayName'] ??
          response.metadata['name'] ??
          response.metadata['respondent_name'];
      final metaLocation =
          response.metadata['location'] ??
          response.metadata['city'] ??
          response.metadata['source'];

      reviews.add(
        ReviewItem(
          id: response.id,
          formId: form.id,
          displayName: metaName is String && metaName.trim().isNotEmpty
              ? metaName.trim()
              : visibleResponseId(response.id),
          submittedAt: submitted,
          location: metaLocation is String && metaLocation.trim().isNotEmpty
              ? metaLocation.trim()
              : 'Web',
          stars: stars,
          answers: mappedAnswers,
          formVersion: response.formVersion,
          isPublic: response.isPublic,
        ),
      );
    }

    double avg(List<double> values) =>
        values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length;

    final avgRating = avg(ratings);
    final thisMonthAvg = thisMonthRatings.isEmpty
        ? avgRating
        : avg(thisMonthRatings);
    final lastMonthAvg = lastMonthRatings.isEmpty
        ? avgRating
        : avg(lastMonthRatings);
    final fiveStarPct = ratings.isEmpty
        ? 0.0
        : ((starCounts[5] ?? 0) / ratings.length) * 100;
    final volumeDeltaPct = lastMonthRatings.isEmpty
        ? (thisMonthRatings.isEmpty ? 0 : 100)
        : (((thisMonthRatings.length - lastMonthRatings.length) /
                      lastMonthRatings.length) *
                  100)
              .round();

    return ReviewSummary(
      avgRating: avgRating,
      totalReviews: formResponses.length,
      fiveStarPct: fiveStarPct,
      thisMonthAvg: thisMonthAvg,
      monthDelta: thisMonthAvg - lastMonthAvg,
      volumeDeltaPct: volumeDeltaPct,
      starCounts: starCounts,
      categoryScores: {
        for (final entry in questionAverages.entries)
          if (entry.value.isNotEmpty) entry.key: avg(entry.value),
      },
      reviews: reviews,
    );
  }

  /// Supabase jsonb may arrive as raw JSON types or nested wrappers.
  static dynamic _unwrapAnswerValue(dynamic raw) {
    if (raw == null) return null;
    if (raw is num || raw is bool || raw is String) return raw;
    if (raw is List) {
      return raw.map(_unwrapAnswerValue).toList();
    }
    if (raw is Map) {
      if (raw.containsKey('value')) return _unwrapAnswerValue(raw['value']);
      return raw;
    }
    return raw;
  }
}

/// Keeps anonymous feedback identifiable without assigning a misleading
/// sequential respondent name or exposing a full database identifier.
String responseDisplayId(String responseId) {
  final compact = responseId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
  final shortId = compact.isEmpty
      ? 'UNKNOWN'
      : compact.substring(0, compact.length.clamp(0, 8)).toUpperCase();
  return shortId;
}

/// A short, neutral response identifier. The hash prefix makes it visually
/// distinct from a person's name while avoiding sequential respondent labels.
String visibleResponseId(String responseId) =>
    '#${responseDisplayId(responseId)}';

String readableResponseTimestamp(DateTime submittedAt) =>
    DateFormat('MMM d, y, h:mm a').format(submittedAt);

List<ReviewItem> sortReviews(List<ReviewItem> all, ReviewSort sort) {
  final items = [...all];
  switch (sort) {
    case ReviewSort.recent:
      items.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    case ReviewSort.highest:
      items.sort((a, b) {
        final byStars = b.stars.compareTo(a.stars);
        if (byStars != 0) return byStars;
        return b.submittedAt.compareTo(a.submittedAt);
      });
    case ReviewSort.photos:
      return items.where((r) => r.hasTextAnswer).toList()
        ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
  }
  return items;
}

class ReviewStarRow extends StatelessWidget {
  const ReviewStarRow({super.key, required this.rating, this.size = 16});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            rating >= i
                ? Icons.star_rounded
                : rating >= i - 0.5
                ? Icons.star_half_rounded
                : Icons.star_border_rounded,
            size: size,
            color: reviewStarYellow,
          ),
      ],
    );
  }
}

String reviewInitials(String name) {
  return name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .take(2)
      .map((p) => p[0].toUpperCase())
      .join();
}

Future<void> showReviewDetailDialog(
  BuildContext context,
  ReviewItem review, {
  VoidCallback? onVisibilityChanged,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _ReviewDetailDialog(
      review: review,
      onVisibilityChanged: onVisibilityChanged,
    ),
  );
}

class _ReviewDetailDialog extends StatefulWidget {
  const _ReviewDetailDialog({required this.review, this.onVisibilityChanged});

  final ReviewItem review;
  final VoidCallback? onVisibilityChanged;

  @override
  State<_ReviewDetailDialog> createState() => _ReviewDetailDialogState();
}

class _ReviewDetailDialogState extends State<_ReviewDetailDialog> {
  late bool _isPublic = widget.review.isPublic;
  bool _saving = false;

  Future<void> _togglePublic(bool value) async {
    setState(() => _saving = true);
    try {
      await getIt<ResponseRepository>().setResponsePublic(
        responseId: widget.review.id,
        isPublic: value,
      );
      if (!mounted) return;
      setState(() {
        _isPublic = value;
        _saving = false;
      });
      widget.onVisibilityChanged?.call();
      showKaydoToast(
        context,
        message: value ? 'Marked Public for API' : 'Marked Private',
        tone: KaydoToastTone.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showKaydoToast(
        context,
        message: e.toString().replaceFirst(RegExp(r'^[^:]+:\s*'), ''),
        tone: KaydoToastTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final review = widget.review;
    final timestamp = readableResponseTimestamp(review.submittedAt);
    final initials = reviewInitials(review.displayName);
    final isAdmin =
        context.watch<AuthBloc>().state.session?.profile.isAdmin ?? false;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.8;

    return Dialog(
      shape: FelloMetrics.dialogShape,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 560, maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 14, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: FelloColors.accentSoft,
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: FelloColors.accentDeep,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          review.displayName.startsWith('#')
                              ? review.displayName
                              : '#${review.displayName}',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: FelloColors.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          timestamp,
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            color: FelloColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
            ),
            if (isAdmin)
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: FelloColors.border),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isPublic ? 'Public' : 'Private',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              _isPublic
                                  ? 'Included in Reviews API responses'
                                  : 'Hidden from Reviews API',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: FelloColors.inkSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Transform.scale(
                        scale: 0.78,
                        child: Switch.adaptive(
                          value: _isPublic,
                          activeThumbColor: FelloColors.accent,
                          onChanged: _saving ? null : _togglePublic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _AiInsightLoader(
                      responseId: review.id,
                      formId: review.formId,
                    ),
                    const SizedBox(height: 14),
                    for (var i = 0; i < review.answers.length; i++) ...[
                      if (i > 0) const SizedBox(height: 14),
                      _ReviewAnswerBlock(answer: review.answers[i]),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiInsightLoader extends StatelessWidget {
  const _AiInsightLoader({required this.responseId, required this.formId});

  final String responseId;
  final String formId;

  @override
  Widget build(BuildContext context) {
    if (!getIt.isRegistered<WorkflowRepository>()) {
      return const SizedBox.shrink();
    }
    final repo = getIt<WorkflowRepository>();
    return FutureBuilder<({FeedbackAnalysis? a, ComplaintTask? t})>(
      future: () async {
        final a = await repo.getAnalysisForResponse(responseId);
        final t = await repo.getTaskForResponse(responseId);
        return (a: a, t: t);
      }(),
      builder: (context, snap) {
        final data = snap.data;
        if (data?.a == null) return const SizedBox.shrink();
        return AiInsightPanel(
          analysis: data!.a!,
          task: data.t,
          onOpenTask: data.t == null
              ? null
              : () {
                  final taskId = data.t!.id;
                  Navigator.pop(context);
                  context.go('/dashboard/reviews/$formId?task=$taskId');
                },
        );
      },
    );
  }
}

class _ReviewAnswerBlock extends StatelessWidget {
  const _ReviewAnswerBlock({required this.answer});

  final ReviewAnswer answer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          answer.label,
          style: GoogleFonts.poppins(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: FelloColors.inkSoft,
          ),
        ),
        const SizedBox(height: 6),
        switch (answer.type) {
          QuestionType.starRating when answer.value is num => ReviewStarRow(
            rating: (answer.value as num).toDouble().clamp(1, 5),
            size: 18,
          ),
          QuestionType.nps when answer.value is num => Text(
            '${(answer.value as num).round()} / 10',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: FelloColors.ink,
            ),
          ),
          _ => Text(
            answer.displayText,
            style: GoogleFonts.poppins(
              fontSize: 14,
              height: 1.5,
              color: answer.hasValue ? FelloColors.ink : FelloColors.inkSoft,
              fontStyle: answer.hasValue ? FontStyle.normal : FontStyle.italic,
            ),
          ),
        },
      ],
    );
  }
}

class ReviewCard extends StatelessWidget {
  const ReviewCard({
    super.key,
    required this.review,
    this.onVisibilityChanged,
    this.selected = false,
    this.onSelectionChanged,
  });

  final ReviewItem review;
  final VoidCallback? onVisibilityChanged;
  final bool selected;
  final ValueChanged<bool>? onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    final timestamp = readableResponseTimestamp(review.submittedAt);
    final initials = reviewInitials(review.displayName);
    final details = <ReviewAnswer>[];
    for (final answer in review.answers) {
      if (!answer.hasValue) continue;
      details.add(answer);
      if (details.length == 2) break;
    }

    return Material(
      color: FelloColors.paper,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => showReviewDetailDialog(
          context,
          review,
          onVisibilityChanged: onVisibilityChanged,
        ),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: FelloColors.border),
          ),
          child: Row(
            children: [
              if (onSelectionChanged != null) ...[
                Checkbox(
                  value: selected,
                  onChanged: (value) => onSelectionChanged!(value ?? false),
                ),
                const SizedBox(width: 4),
              ],
              CircleAvatar(
                radius: 18,
                backgroundColor: FelloColors.accentSoft,
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: FelloColors.accentDeep,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            review.displayName,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: FelloColors.ink,
                            ),
                          ),
                        ),
                        if (review.isPublic) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: FelloColors.accentSoft,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Public',
                              style: GoogleFonts.poppins(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: FelloColors.accentDeep,
                              ),
                            ),
                          ),
                        ],
                        if (review.formVersion != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: FelloColors.paper,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: FelloColors.border),
                            ),
                            child: Text(
                              'Version ${review.formVersion}',
                              style: GoogleFonts.poppins(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: FelloColors.inkSoft,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      timestamp,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        color: FelloColors.inkSoft,
                      ),
                    ),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      for (final answer in details)
                        Text(
                          '${answer.label}: ${answer.displayText}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: FelloColors.inkSoft,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ReviewStarRow(rating: review.stars.toDouble(), size: 14),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                color: FelloColors.inkSoft,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ReviewSortTabs extends StatelessWidget {
  const ReviewSortTabs({
    super.key,
    required this.sort,
    required this.onChanged,
  });

  final ReviewSort sort;
  final ValueChanged<ReviewSort> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, ReviewSort value) {
      final selected = sort == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
          color: selected ? FelloColors.ink : FelloColors.paper,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            onTap: () => onChanged(value),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected ? FelloColors.ink : FelloColors.border,
                ),
              ),
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : FelloColors.inkSoft,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip('Recent Reviews', ReviewSort.recent),
          chip('Highest Rated', ReviewSort.highest),
          chip('With Photos', ReviewSort.photos),
        ],
      ),
    );
  }
}
