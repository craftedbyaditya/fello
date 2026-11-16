import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/fello_colors.dart';
import '../../../domain/entities/feedback_form.dart';
import '../../../shared/animations/fade_slide_in.dart';
import '../../../shared/widgets/fello_back_button.dart';
import '../../../shared/widgets/kaydo_search_field.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../bloc/dashboard_bloc.dart';
import 'form_reviews_page.dart' show SoftPadding;
import 'widgets/review_feed.dart';

enum _RatingFilter { all, five, fourPlus, threePlus }

class AllReviewsPage extends StatefulWidget {
  const AllReviewsPage({super.key, required this.formId});

  final String formId;

  @override
  State<AllReviewsPage> createState() => _AllReviewsPageState();
}

class _AllReviewsPageState extends State<AllReviewsPage> {
  final _searchController = TextEditingController();
  ReviewSort _sort = ReviewSort.recent;
  _RatingFilter _ratingFilter = _RatingFilter.all;
  bool _withCommentsOnly = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bloc = context.read<DashboardBloc>();
      final orgId = bloc.state.orgId ??
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
    var items = sortReviews(all, _sort);

    switch (_ratingFilter) {
      case _RatingFilter.all:
        break;
      case _RatingFilter.five:
        items = items.where((r) => r.stars == 5).toList();
      case _RatingFilter.fourPlus:
        items = items.where((r) => r.stars >= 4).toList();
      case _RatingFilter.threePlus:
        items = items.where((r) => r.stars >= 3).toList();
    }

    if (_withCommentsOnly) {
      items = items.where((r) => r.hasTextAnswer).toList();
    }

    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      items = items.where((r) => r.searchableText.contains(q)).toList();
    }

    return items;
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

        final summary = ReviewSummary.from(form, state.responses);
        final reviews = _applyFilters(summary.reviews);
        final title = form.title;
        final formId = form.id;

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
                  child: _FilterBar(
                    ratingFilter: _ratingFilter,
                    withCommentsOnly: _withCommentsOnly,
                    sort: _sort,
                    onRatingChanged: (value) =>
                        setState(() => _ratingFilter = value),
                    onCommentsToggled: () => setState(
                      () => _withCommentsOnly = !_withCommentsOnly,
                    ),
                    onSortChanged: (value) => setState(() => _sort = value),
                  ),
                ),
                SoftPadding(
                  padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
                  child: Text(
                    '${reviews.length} review${reviews.length == 1 ? '' : 's'}',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: FelloColors.inkSoft,
                      fontWeight: FontWeight.w500,
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
                              _query.isEmpty &&
                                      _ratingFilter == _RatingFilter.all &&
                                      !_withCommentsOnly
                                  ? 'No reviews yet.'
                                  : 'No reviews match your filters.',
                              style: const TextStyle(color: FelloColors.inkSoft),
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            for (var i = 0; i < reviews.length; i++) ...[
                              if (i > 0) const SizedBox(height: 12),
                              ReviewCard(
                                review: reviews[i],
                                onVisibilityChanged: () {
                                  final orgId = context
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
                                    context
                                        .read<DashboardBloc>()
                                        .add(DashboardLoadRequested(orgId));
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

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.ratingFilter,
    required this.withCommentsOnly,
    required this.sort,
    required this.onRatingChanged,
    required this.onCommentsToggled,
    required this.onSortChanged,
  });

  final _RatingFilter ratingFilter;
  final bool withCommentsOnly;
  final ReviewSort sort;
  final ValueChanged<_RatingFilter> onRatingChanged;
  final VoidCallback onCommentsToggled;
  final ValueChanged<ReviewSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    Widget chip({
      required String label,
      required bool selected,
      required VoidCallback onTap,
      bool emphasis = false,
    }) {
      final selectedColor = emphasis ? FelloColors.ink : FelloColors.accent;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
          color: selected
              ? (emphasis
                  ? FelloColors.ink
                  : FelloColors.accent.withValues(alpha: 0.12))
              : FelloColors.paper,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected ? selectedColor : FelloColors.border,
                ),
              ),
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? (emphasis ? Colors.white : FelloColors.accent)
                      : FelloColors.inkSoft,
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
          chip(
            label: 'All ratings',
            selected: ratingFilter == _RatingFilter.all,
            onTap: () => onRatingChanged(_RatingFilter.all),
          ),
          chip(
            label: '5 stars',
            selected: ratingFilter == _RatingFilter.five,
            onTap: () => onRatingChanged(_RatingFilter.five),
          ),
          chip(
            label: '4+ stars',
            selected: ratingFilter == _RatingFilter.fourPlus,
            onTap: () => onRatingChanged(_RatingFilter.fourPlus),
          ),
          chip(
            label: '3+ stars',
            selected: ratingFilter == _RatingFilter.threePlus,
            onTap: () => onRatingChanged(_RatingFilter.threePlus),
          ),
          chip(
            label: 'With comments',
            selected: withCommentsOnly,
            onTap: onCommentsToggled,
          ),
          chip(
            label: 'Recent',
            selected: sort == ReviewSort.recent,
            onTap: () => onSortChanged(ReviewSort.recent),
            emphasis: true,
          ),
          chip(
            label: 'Highest rated',
            selected: sort == ReviewSort.highest,
            onTap: () => onSortChanged(ReviewSort.highest),
            emphasis: true,
          ),
          chip(
            label: 'With photos',
            selected: sort == ReviewSort.photos,
            onTap: () => onSortChanged(ReviewSort.photos),
            emphasis: true,
          ),
        ],
      ),
    );
  }
}
