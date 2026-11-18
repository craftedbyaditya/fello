import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/fello_colors.dart';
import '../../../domain/entities/feedback_form.dart';
import '../../../domain/entities/question.dart';
import '../../../domain/repositories/response_repository.dart';
import '../../../shared/animations/fade_slide_in.dart';
import '../../../shared/widgets/fello_back_button.dart';
import '../../../shared/widgets/kaydo_search_field.dart';
import '../../../shared/widgets/kaydo_toast.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../bloc/dashboard_bloc.dart';
import '../export/review_exporter.dart';
import 'form_reviews_page.dart' show SoftPadding;
import 'widgets/export_reviews_sheet.dart';
import 'widgets/review_feed.dart';

class AllReviewsPage extends StatefulWidget {
  const AllReviewsPage({super.key, required this.formId});

  final String formId;

  @override
  State<AllReviewsPage> createState() => _AllReviewsPageState();
}

class _AllReviewsPageState extends State<AllReviewsPage> {
  final _searchController = TextEditingController();
  String? _questionId;
  String? _answerValue;
  final Set<String> _selectedIds = <String>{};
  bool _hidingSelected = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bloc = context.read<DashboardBloc>();
      final orgId =
          bloc.state.orgId ??
          context.read<AuthBloc>().state.session?.organization.id;
      if (orgId != null &&
          (bloc.state.forms.isEmpty || bloc.state.responses.isEmpty)) {
        bloc.add(DashboardLoadRequested(orgId));
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ReviewItem> _applyFilters(List<ReviewItem> all) {
    var items = sortReviews(all, ReviewSort.recent);

    if (_questionId != null && _answerValue != null) {
      items = items.where((review) {
        final answer = review.answers.where((a) => a.questionId == _questionId);
        if (answer.isEmpty) return false;
        final value = answer.first;
        if (_answerValue == _hasAnswer) return value.hasValue;
        if (value.value is List) {
          return (value.value as List).contains(_answerValue);
        }
        return value.displayText == _answerValue;
      }).toList();
    }

    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      items = items.where((r) => r.searchableText.contains(q)).toList();
    }

    return items;
  }

  static const _hasAnswer = '__has_answer__';

  Future<void> _hideSelected(String orgId) async {
    final ids = _selectedIds.toList(growable: false);
    if (ids.isEmpty || _hidingSelected) return;
    setState(() => _hidingSelected = true);
    try {
      for (final id in ids) {
        await getIt<ResponseRepository>().setResponsePublic(
          responseId: id,
          isPublic: false,
        );
      }
      if (!mounted) return;
      setState(() {
        _selectedIds.clear();
        _hidingSelected = false;
      });
      context.read<DashboardBloc>().add(DashboardLoadRequested(orgId));
      showKaydoToast(context, message: 'Selected reviews are now private.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _hidingSelected = false);
      showKaydoToast(
        context,
        message: 'We could not update every selected review.',
        tone: KaydoToastTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, state) {
        FeedbackForm? form;
        for (final f in state.forms) {
          if (f.id == widget.formId) {
            form = f;
            break;
          }
        }

        if (state.status == DashboardStatus.loading && form == null) {
          return const ColoredBox(
            color: FelloColors.paper,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (form == null) {
          return ColoredBox(
            color: FelloColors.paper,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Survey not found'),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.go('/dashboard'),
                    child: const Text('Back to dashboard'),
                  ),
                ],
              ),
            ),
          );
        }

        final currentForm = form;
        final summary = ReviewSummary.from(currentForm, state.responses);
        final reviews = _applyFilters(summary.reviews);
        final title = currentForm.title;
        final formId = currentForm.id;
        final isAdmin =
            context.watch<AuthBloc>().state.session?.profile.isAdmin ?? false;
        final orgId =
            state.orgId ??
            context.read<AuthBloc>().state.session?.organization.id;

        return ColoredBox(
          color: FelloColors.paper,
          child: FadeSlideIn(
            child: CustomScrollView(
              slivers: [
                SoftPadding(
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
                  child: _AllReviewsHeader(
                    title: title.isEmpty ? 'Untitled survey' : title,
                    totalCount: summary.totalReviews,
                    onBack: () => context.go('/dashboard/reviews/$formId'),
                  ),
                ),
                SoftPadding(
                  padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
                  child: KaydoSearchField(
                    controller: _searchController,
                    hintText: 'Search by name, comment, location…',
                    width: null,
                    onChanged: (value) => setState(() => _query = value),
                    onClear: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                  ),
                ),
                SoftPadding(
                  padding: const EdgeInsets.fromLTRB(28, 14, 28, 0),
                  child: _QuestionFilterBar(
                    questions: currentForm.questions,
                    selectedQuestionId: _questionId,
                    selectedAnswerValue: _answerValue,
                    onQuestionChanged: (id) => setState(() {
                      _questionId = id;
                      _answerValue = null;
                    }),
                    onAnswerChanged: (value) =>
                        setState(() => _answerValue = value),
                  ),
                ),
                SoftPadding(
                  padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
                  child: _ReviewBulkToolbar(
                    total: reviews.length,
                    selectedCount: _selectedIds.length,
                    allSelected:
                        reviews.isNotEmpty &&
                        reviews.every(
                          (review) => _selectedIds.contains(review.id),
                        ),
                    showBulkActions: isAdmin,
                    hiding: _hidingSelected,
                    onSelectAll: isAdmin
                        ? (selected) => setState(() {
                            if (selected) {
                              _selectedIds.addAll(reviews.map((r) => r.id));
                            } else {
                              _selectedIds.removeAll(reviews.map((r) => r.id));
                            }
                          })
                        : null,
                    onHide: isAdmin && orgId != null
                        ? () => _hideSelected(orgId)
                        : null,
                    onExport: () => showExportReviewsSheet(
                      context: context,
                      data: ReviewExportData(
                        surveyTitle: title,
                        createdAt: currentForm.createdAt,
                        avgRating: summary.avgRating,
                        totalReviews: reviews.length,
                        reviews: reviews,
                        organizationName: context
                            .read<AuthBloc>()
                            .state
                            .session
                            ?.organization
                            .name,
                        organizationLogoUrl: context
                            .read<AuthBloc>()
                            .state
                            .session
                            ?.organization
                            .logoUrl,
                      ),
                    ),
                  ),
                ),
                SoftPadding(
                  padding: const EdgeInsets.fromLTRB(28, 14, 28, 36),
                  child: reviews.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: FelloColors.paper,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: FelloColors.border),
                          ),
                          child: Center(
                            child: Text(
                              _query.isEmpty && _questionId == null
                                  ? 'No reviews yet.'
                                  : 'No reviews match your filters.',
                              style: const TextStyle(
                                color: FelloColors.inkSoft,
                              ),
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            for (var i = 0; i < reviews.length; i++) ...[
                              if (i > 0) const SizedBox(height: 12),
                              ReviewCard(
                                review: reviews[i],
                                selected: _selectedIds.contains(reviews[i].id),
                                onSelectionChanged: isAdmin
                                    ? (selected) => setState(() {
                                        if (selected) {
                                          _selectedIds.add(reviews[i].id);
                                        } else {
                                          _selectedIds.remove(reviews[i].id);
                                        }
                                      })
                                    : null,
                                onVisibilityChanged: () {
                                  final orgId =
                                      context
                                          .read<DashboardBloc>()
                                          .state
                                          .orgId ??
                                      context
                                          .read<AuthBloc>()
                                          .state
                                          .session
                                          ?.organization
                                          .id;
                                  if (orgId != null) {
                                    context.read<DashboardBloc>().add(
                                      DashboardLoadRequested(orgId),
                                    );
                                  }
                                },
                              ),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AllReviewsHeader extends StatelessWidget {
  const _AllReviewsHeader({
    required this.title,
    required this.totalCount,
    required this.onBack,
  });

  final String title;
  final int totalCount;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2, right: 4),
          child: FelloBackButton(onPressed: onBack),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'All reviews',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: FelloColors.ink,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$title · $totalCount total',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: FelloColors.inkSoft,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuestionFilterBar extends StatelessWidget {
  const _QuestionFilterBar({
    required this.questions,
    required this.selectedQuestionId,
    required this.selectedAnswerValue,
    required this.onQuestionChanged,
    required this.onAnswerChanged,
  });

  final List<Question> questions;
  final String? selectedQuestionId;
  final String? selectedAnswerValue;
  final ValueChanged<String?> onQuestionChanged;
  final ValueChanged<String?> onAnswerChanged;

  @override
  Widget build(BuildContext context) {
    final question = questions
        .where((q) => q.id == selectedQuestionId)
        .firstOrNull;
    final answers = switch (question?.type) {
      QuestionType.singleChoice ||
      QuestionType.multiChoice => question!.options,
      QuestionType.yesNo => const ['Yes', 'No'],
      QuestionType.starRating => const [
        '1 / 5',
        '2 / 5',
        '3 / 5',
        '4 / 5',
        '5 / 5',
      ],
      QuestionType.nps => List.generate(11, (index) => '$index / 10'),
      QuestionType.shortText ||
      QuestionType.longText => const [_AllReviewsPageState._hasAnswer],
      null => const <String>[],
    };

    return Wrap(
      spacing: 12,
      runSpacing: 10,
      children: [
        SizedBox(
          width: 280,
          child: DropdownButtonFormField<String>(
            key: const ValueKey('review-question-filter'),
            initialValue: selectedQuestionId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Filter by question'),
            items: [
              const DropdownMenuItem(value: null, child: Text('All responses')),
              for (final item in questions)
                DropdownMenuItem(value: item.id, child: Text(item.label)),
            ],
            onChanged: onQuestionChanged,
          ),
        ),
        if (question != null)
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String>(
              key: ValueKey('review-answer-filter-$selectedQuestionId'),
              initialValue: selectedAnswerValue,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Answer'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Any answer')),
                for (final answer in answers)
                  DropdownMenuItem(
                    value: answer,
                    child: Text(
                      answer == _AllReviewsPageState._hasAnswer
                          ? 'Has an answer'
                          : answer,
                    ),
                  ),
              ],
              onChanged: onAnswerChanged,
            ),
          ),
      ],
    );
  }
}

class _ReviewBulkToolbar extends StatelessWidget {
  const _ReviewBulkToolbar({
    required this.total,
    required this.selectedCount,
    required this.allSelected,
    required this.showBulkActions,
    required this.hiding,
    required this.onSelectAll,
    required this.onHide,
    required this.onExport,
  });

  final int total;
  final int selectedCount;
  final bool allSelected;
  final bool showBulkActions;
  final bool hiding;
  final ValueChanged<bool>? onSelectAll;
  final VoidCallback? onHide;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text(
        '$total review${total == 1 ? '' : 's'}',
        style: const TextStyle(color: FelloColors.inkSoft),
      ),
      if (showBulkActions)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: allSelected,
              onChanged: total == 0
                  ? null
                  : (v) => onSelectAll?.call(v ?? false),
            ),
            const Text('Select all'),
          ],
        ),
      if (showBulkActions && selectedCount > 0)
        OutlinedButton.icon(
          onPressed: hiding ? null : onHide,
          icon: const Icon(Icons.visibility_off_outlined, size: 18),
          label: Text(hiding ? 'Hiding…' : 'Hide selected ($selectedCount)'),
        ),
      OutlinedButton.icon(
        onPressed: onExport,
        icon: const Icon(Icons.file_download_outlined, size: 18),
        label: const Text('Export'),
      ),
    ],
  );
}
