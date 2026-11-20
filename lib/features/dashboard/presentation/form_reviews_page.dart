import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/fello_colors.dart';
import '../../../domain/entities/feedback_form.dart';
import '../../../shared/animations/fade_slide_in.dart';
import '../../../shared/widgets/fello_back_button.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../bloc/dashboard_bloc.dart';
import '../export/review_exporter.dart';
import 'widgets/export_reviews_sheet.dart';
import 'widgets/review_feed.dart';

const _starYellow = Color(0xFFF5C518);
const _barTrack = Color(0xFFE8ECF1);
const _barFill = Color(0xFF4F6EF7);

class FormReviewsPage extends StatefulWidget {
  const FormReviewsPage({super.key, required this.formId, this.taskId});

  final String formId;
  final String? taskId;

  @override
  State<FormReviewsPage> createState() => _FormReviewsPageState();
}

class _FormReviewsPageState extends State<FormReviewsPage> {
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
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, state) {
        FeedbackForm? form;
        for (final candidate in state.forms) {
          if (candidate.id == widget.formId) {
            form = candidate;
            break;
          }
        }
        if (form == null) {
          if (state.status == DashboardStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Survey not found'),
                TextButton(
                  onPressed: () => context.go('/dashboard'),
                  child: const Text('Back to dashboard'),
                ),
              ],
            ),
          );
        }

        final summary = ReviewSummary.from(form, state.responses);
        final recentReviews = sortReviews(
          summary.reviews,
          ReviewSort.recent,
        ).take(3).toList();
        final title = form.title;
        final createdAt = form.createdAt;
        final formId = form.id;

        return ColoredBox(
          color: FelloColors.paper,
          child: FadeSlideIn(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 980;
                return CustomScrollView(
                  slivers: [
                    SoftPadding(
                      padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
                      child: _Header(
                        title: title,
                        createdAt: createdAt,
                        onBack: () => context.go('/dashboard'),
                        onExport: () => showExportReviewsSheet(
                          context: context,
                          data: ReviewExportData(
                            surveyTitle: title,
                            createdAt: createdAt,
                            avgRating: summary.avgRating,
                            totalReviews: summary.totalReviews,
                            reviews: summary.reviews,
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
                      padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
                      child: _SummaryRow(summary: summary),
                    ),
                    SoftPadding(
                      padding: const EdgeInsets.fromLTRB(28, 20, 28, 16),
                      child: wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 300,
                                  child: _LeftColumn(summary: summary),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: _ReviewsColumn(
                                    reviews: recentReviews,
                                    totalCount: summary.totalReviews,
                                    onViewAll: () => context.go(
                                      '/dashboard/reviews/$formId/all',
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                _LeftColumn(summary: summary),
                                const SizedBox(height: 20),
                                _ReviewsColumn(
                                  reviews: recentReviews,
                                  totalCount: summary.totalReviews,
                                  onViewAll: () => context.go(
                                    '/dashboard/reviews/$formId/all',
                                  ),
                                ),
                              ],
                            ),
                    ),
                    const SoftPadding(
                      padding: EdgeInsets.only(bottom: 36),
                      child: SizedBox.shrink(),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class SoftPadding extends StatelessWidget {
  const SoftPadding({super.key, required this.padding, required this.child});
  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(padding: padding, child: child),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.createdAt,
    required this.onBack,
    required this.onExport,
  });

  final String title;
  final DateTime createdAt;
  final VoidCallback onBack;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final createdLabel =
        'Created on ${DateFormat('MMMM d, y').format(createdAt)}';

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
                title.isEmpty ? 'Untitled survey' : title,
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: FelloColors.ink,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                createdLabel,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: FelloColors.inkSoft,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        _GhostAction(
          icon: Icons.file_download_outlined,
          label: 'Export',
          onTap: onExport,
        ),
      ],
    );
  }
}

class _GhostAction extends StatelessWidget {
  const _GhostAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.summary});

  final ReviewSummary summary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          _SummaryCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.avgRating == 0
                      ? '—'
                      : summary.avgRating.toStringAsFixed(1),
                  style: _valueStyle,
                ),
                const SizedBox(height: 8),
                ReviewStarRow(rating: summary.avgRating, size: 18),
                const SizedBox(height: 12),
                Text(
                  'Based on ${summary.totalReviews} reviews',
                  style: _footerStyle,
                ),
              ],
            ),
          ),
          _SummaryCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${summary.totalReviews}', style: _valueStyle),
                const SizedBox(height: 8),
                Text('Total Reviews', style: _labelStyle),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.trending_up_rounded,
                      size: 16,
                      color: summary.volumeDeltaPct >= 0
                          ? FelloColors.accent
                          : FelloColors.danger,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${summary.volumeDeltaPct >= 0 ? '+' : ''}${summary.volumeDeltaPct}% from last month',
                        style: _footerStyle.copyWith(
                          color: summary.volumeDeltaPct >= 0
                              ? FelloColors.accent
                              : FelloColors.danger,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _SummaryCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${summary.fiveStarPct.round()}%', style: _valueStyle),
                const SizedBox(height: 8),
                Text('5-Star reviews', style: _labelStyle),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.thumb_up_alt_outlined,
                      size: 15,
                      color: FelloColors.accent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Excellent ratings',
                      style: _footerStyle.copyWith(color: FelloColors.accent),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _SummaryCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.thisMonthAvg == 0
                      ? '—'
                      : summary.thisMonthAvg.toStringAsFixed(1),
                  style: _valueStyle,
                ),
                const SizedBox(height: 8),
                Text('This Month', style: _labelStyle),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.trending_up_rounded,
                      size: 16,
                      color: summary.monthDelta >= 0
                          ? _barFill
                          : FelloColors.danger,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${summary.monthDelta >= 0 ? '+' : ''}${summary.monthDelta.toStringAsFixed(1)} from last month',
                      style: _footerStyle.copyWith(
                        color: summary.monthDelta >= 0
                            ? _barFill
                            : FelloColors.danger,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ];

        if (constraints.maxWidth < 900) {
          return Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final card in cards)
                SizedBox(
                  width: constraints.maxWidth < 560
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 14) / 2,
                  child: card,
                ),
            ],
          );
        }

        return Row(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 14),
              Expanded(child: cards[i]),
            ],
          ],
        );
      },
    );
  }

  static final _valueStyle = GoogleFonts.poppins(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    color: FelloColors.ink,
    height: 1,
  );
  static final _labelStyle = GoogleFonts.poppins(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: FelloColors.inkSoft,
  );
  static final _footerStyle = GoogleFonts.poppins(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: FelloColors.inkSoft,
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: FelloColors.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FelloColors.border),
        boxShadow: [
          BoxShadow(
            color: FelloColors.ink.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _LeftColumn extends StatelessWidget {
  const _LeftColumn({required this.summary});
  final ReviewSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PanelTitle('Ratings Breakdown'),
        const SizedBox(height: 10),
        _PanelCard(
          child: Column(
            children: [
              for (var star = 5; star >= 1; star--)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _BreakdownRow(
                    stars: star,
                    count: summary.starCounts[star] ?? 0,
                    total: summary.totalReviews,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (summary.categoryScores.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _PanelTitle('Question averages'),
              const SizedBox(height: 10),
              _PanelCard(
                child: Column(
                  children: [
                    for (final entry in summary.categoryScores.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.key,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: FelloColors.ink,
                                ),
                              ),
                            ),
                            Text(
                              entry.value.toStringAsFixed(1),
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: FelloColors.ink,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ReviewStarRow(rating: entry.value, size: 14),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.stars,
    required this.count,
    required this.total,
  });

  final int stars;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : count / total;
    return Row(
      children: [
        SizedBox(
          width: 18,
          child: Text(
            '$stars',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: FelloColors.ink,
            ),
          ),
        ),
        const Icon(Icons.star_rounded, size: 14, color: _starYellow),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: _barTrack,
              color: _barFill,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 28,
          child: Text(
            '$count',
            textAlign: TextAlign.right,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: FelloColors.inkSoft,
            ),
          ),
        ),
      ],
    );
  }
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: GoogleFonts.poppins(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: FelloColors.ink,
    ),
  );
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
      decoration: BoxDecoration(
        color: FelloColors.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FelloColors.border),
        boxShadow: [
          BoxShadow(
            color: FelloColors.ink.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ReviewsColumn extends StatelessWidget {
  const _ReviewsColumn({
    required this.reviews,
    required this.totalCount,
    required this.onViewAll,
  });

  final List<ReviewItem> reviews;
  final int totalCount;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Recent Reviews',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: FelloColors.ink,
                ),
              ),
            ),
            if (totalCount > 0)
              TextButton(
                onPressed: onViewAll,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('View all'),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, size: 16),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (reviews.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: FelloColors.paper,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: FelloColors.border),
            ),
            child: const Center(
              child: Text(
                'No reviews yet.',
                style: TextStyle(color: FelloColors.inkSoft),
              ),
            ),
          )
        else
          for (var i = 0; i < reviews.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            ReviewCard(
              review: reviews[i],
              onVisibilityChanged: () {
                final orgId =
                    context.read<DashboardBloc>().state.orgId ??
                    context.read<AuthBloc>().state.session?.organization.id;
                if (orgId != null) {
                  context.read<DashboardBloc>().add(
                    DashboardLoadRequested(orgId),
                  );
                }
              },
            ),
          ],
      ],
    );
  }
}
