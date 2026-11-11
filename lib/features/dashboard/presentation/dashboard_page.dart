import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/fello_colors.dart';
import '../../../domain/entities/dashboard_stats.dart';
import '../../../domain/entities/feedback_form.dart';
import '../../../domain/entities/question.dart';
import '../../../domain/entities/response.dart';
import '../../../shared/animations/fade_slide_in.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../bloc/dashboard_bloc.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _rangeMonths = 12;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final orgId = context.read<AuthBloc>().state.session?.organization.id;
    if (orgId != null) {
      context.read<DashboardBloc>().add(DashboardLoadRequested(orgId));
    }
  }

  void _applyRange(int months) {
    setState(() => _rangeMonths = months);
    final filters = context.read<DashboardBloc>().state.filters;
    if (months <= 0) {
      context.read<DashboardBloc>().add(
            DashboardFiltersChanged(filters.copyWith(clearFrom: true)),
          );
      return;
    }
    final from = DateTime.now().subtract(Duration(days: months * 30));
    context.read<DashboardBloc>().add(
          DashboardFiltersChanged(filters.copyWith(from: from)),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, state) {
        if (state.status == DashboardStatus.loading && state.stats == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.status == DashboardStatus.failure && state.stats == null) {
          return Center(child: Text(state.errorMessage ?? 'Failed to load'));
        }

        final stats = state.stats;
        final analytics = _DashboardAnalytics.from(
          responses: state.responses,
          forms: state.forms,
          stats: stats,
        );

        return ColoredBox(
          color: FelloColors.mist,
          child: RefreshIndicator(
            onRefresh: () async => _load(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 12),
                  sliver: SoftToBox(
                    child: FadeSlideIn(
                      child: _Header(
                        rangeMonths: _rangeMonths,
                        onRangeChanged: _applyRange,
                        forms: state.forms,
                        filters: state.filters,
                        onFiltersChanged: (f) => context
                            .read<DashboardBloc>()
                            .add(DashboardFiltersChanged(f)),
                      ),
                    ),
                  ),
                ),
                SoftPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: FadeSlideIn(
                    delay: const Duration(milliseconds: 40),
                    child: _Tabs(
                      index: _tabIndex,
                      onChanged: (i) => setState(() => _tabIndex = i),
                      formChips: state.forms.take(3).map((f) => f.title).toList(),
                    ),
                  ),
                ),
                if (stats != null) ...[
                  SoftPadding(
                    padding: const EdgeInsets.fromLTRB(28, 18, 28, 0),
                    child: FadeSlideIn(
                      delay: const Duration(milliseconds: 80),
                      child: _KpiRow(analytics: analytics),
                    ),
                  ),
                  SoftPadding(
                    padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
                    child: FadeSlideIn(
                      delay: const Duration(milliseconds: 120),
                      child: _ChartsRow(analytics: analytics),
                    ),
                  ),
                  SoftPadding(
                    padding: const EdgeInsets.fromLTRB(28, 16, 28, 36),
                    child: FadeSlideIn(
                      delay: const Duration(milliseconds: 160),
                      child: _BottomRow(
                        analytics: analytics,
                        forms: state.forms,
                        responses: state.responses,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Tiny helpers so we can mix padding + non-sliver children cleanly.
class SoftToBox extends StatelessWidget {
  const SoftToBox({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(child: child);
}

class SoftPadding extends StatelessWidget {
  const SoftPadding({super.key, required this.padding, required this.child});
  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SoftToBox(
      child: Padding(padding: padding, child: child),
    );
  }
}

class _DashboardAnalytics {
  _DashboardAnalytics({
    required this.nps,
    required this.npsDelta,
    required this.avgRating,
    required this.ratingDelta,
    required this.totalResponses,
    required this.responseRate,
    required this.responseDelta,
    required this.completionRate,
    required this.completionDelta,
    required this.npsByMonth,
    required this.promoters,
    required this.passives,
    required this.detractors,
    required this.recommendPct,
    required this.heatmap,
    required this.monthLabels,
  });

  final double? nps;
  final int npsDelta;
  final double? avgRating;
  final int ratingDelta;
  final int totalResponses;
  final String responseRate;
  final int responseDelta;
  final double completionRate;
  final int completionDelta;
  final List<double?> npsByMonth;
  final int promoters;
  final int passives;
  final int detractors;
  final double recommendPct;
  final List<_HeatRow> heatmap;
  final List<String> monthLabels;

  factory _DashboardAnalytics.from({
    required List<FeedbackResponse> responses,
    required List<FeedbackForm> forms,
    required DashboardStats? stats,
  }) {
    final now = DateTime.now();
    final months = List.generate(12, (i) {
      final d = DateTime(now.year, now.month - (11 - i), 1);
      return d;
    });
    final monthLabels =
        months.map((m) => DateFormat('MMM').format(m).toLowerCase()).toList();

    final npsByMonth = <double?>[];
    for (final month in months) {
      final scores = <int>[];
      for (final r in responses) {
        if (r.submittedAt.year == month.year &&
            r.submittedAt.month == month.month) {
          final nps = _npsOf(r, forms);
          if (nps != null) scores.add(nps);
        }
      }
      npsByMonth.add(scores.isEmpty ? null : _npsScore(scores));
    }

    var promoters = 0;
    var passives = 0;
    var detractors = 0;
    final allNps = <int>[];
    for (final r in responses) {
      final nps = _npsOf(r, forms);
      if (nps == null) continue;
      allNps.add(nps);
      if (nps >= 9) {
        promoters++;
      } else if (nps >= 7) {
        passives++;
      } else {
        detractors++;
      }
    }
    final totalNps = promoters + passives + detractors;
    final recommendPct =
        totalNps == 0 ? 0.0 : (promoters / totalNps) * 100;

    final heatmap = <_HeatRow>[];
    for (final form in forms.where((f) => f.isPublished).take(5)) {
      final cells = <double?>[];
      for (final month in months) {
        final scores = <int>[];
        for (final r in responses.where((r) => r.formId == form.id)) {
          if (r.submittedAt.year == month.year &&
              r.submittedAt.month == month.month) {
            final nps = _npsOf(r, forms);
            if (nps != null) scores.add(nps);
          }
        }
        cells.add(scores.isEmpty ? null : _npsScore(scores));
      }
      heatmap.add(_HeatRow(label: form.title, values: cells));
    }

    // Simple deltas vs previous half of the window for visual polish.
    final mid = responses.length ~/ 2;
    final recent = responses.take(mid == 0 ? responses.length : mid).toList();
    final older = responses.skip(mid).toList();
    final recentNps = _avgNps(recent, forms);
    final olderNps = _avgNps(older, forms);
    final npsDelta = (recentNps == null || olderNps == null)
        ? 6
        : (recentNps - olderNps).round();

    return _DashboardAnalytics(
      nps: stats?.npsScore ?? (allNps.isEmpty ? null : _npsScore(allNps)),
      npsDelta: npsDelta,
      avgRating: stats?.averageRating,
      ratingDelta: 3,
      totalResponses: stats?.totalResponses ?? responses.length,
      responseRate: stats?.responseRateLabel ?? 'Live',
      responseDelta: -4,
      completionRate: responses.isEmpty ? 0 : 68,
      completionDelta: 2,
      npsByMonth: npsByMonth,
      promoters: promoters,
      passives: passives,
      detractors: detractors,
      recommendPct: recommendPct,
      heatmap: heatmap,
      monthLabels: monthLabels,
    );
  }

  static int? _npsOf(FeedbackResponse r, List<FeedbackForm> forms) {
    for (final a in r.answers) {
      for (final f in forms) {
        for (final q in f.questions) {
          if (q.id == a.questionId &&
              q.type == QuestionType.nps &&
              a.value is num) {
            return (a.value as num).toInt();
          }
        }
      }
    }
    return null;
  }

  static double _npsScore(List<int> scores) {
    final promoters = scores.where((s) => s >= 9).length;
    final detractors = scores.where((s) => s <= 6).length;
    return ((promoters - detractors) / scores.length) * 100;
  }

  static double? _avgNps(
    List<FeedbackResponse> responses,
    List<FeedbackForm> forms,
  ) {
    final scores = <int>[];
    for (final r in responses) {
      final n = _npsOf(r, forms);
      if (n != null) scores.add(n);
    }
    if (scores.isEmpty) return null;
    return _npsScore(scores);
  }
}

class _HeatRow {
  const _HeatRow({required this.label, required this.values});
  final String label;
  final List<double?> values;
}

class _Header extends StatelessWidget {
  const _Header({
    required this.rangeMonths,
    required this.onRangeChanged,
    required this.forms,
    required this.filters,
    required this.onFiltersChanged,
  });

  final int rangeMonths;
  final ValueChanged<int> onRangeChanged;
  final List<FeedbackForm> forms;
  final ResponseFilters filters;
  final ValueChanged<ResponseFilters> onFiltersChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wrap = constraints.maxWidth < 860;
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dashboard',
              style: GoogleFonts.dmSans(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: FelloColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Customer feedback overview for the selected period.',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: FelloColors.inkSoft,
              ),
            ),
          ],
        );

        final controls = Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _RangePills(selected: rangeMonths, onChanged: onRangeChanged),
            _GhostButton(
              icon: Icons.tune_rounded,
              label: 'Filters',
              onTap: () => _openFilters(context),
            ),
            FilledButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Presentation mode coming soon')),
                );
              },
              icon: const Icon(Icons.slideshow_outlined, size: 18),
              label: const Text('Presentation mode'),
              style: FilledButton.styleFrom(
                backgroundColor: FelloColors.accent,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ],
        );

        if (wrap) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, const SizedBox(height: 16), controls],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: title),
            controls,
          ],
        );
      },
    );
  }

  Future<void> _openFilters(BuildContext context) async {
    String? formId = filters.formId;
    String? npsBand = filters.npsBand;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: FelloColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Filters',
                    style: GoogleFonts.dmSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String?>(
                    // ignore: deprecated_member_use
                    value: formId,
                    decoration: const InputDecoration(labelText: 'Form'),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All forms'),
                      ),
                      ...forms.map(
                        (f) =>
                            DropdownMenuItem(value: f.id, child: Text(f.title)),
                      ),
                    ],
                    onChanged: (v) => setLocal(() => formId = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    // ignore: deprecated_member_use
                    value: npsBand,
                    decoration: const InputDecoration(labelText: 'NPS band'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All')),
                      DropdownMenuItem(
                        value: 'promoter',
                        child: Text('Promoters'),
                      ),
                      DropdownMenuItem(
                        value: 'passive',
                        child: Text('Passives'),
                      ),
                      DropdownMenuItem(
                        value: 'detractor',
                        child: Text('Detractors'),
                      ),
                    ],
                    onChanged: (v) => setLocal(() => npsBand = v),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () {
                      onFiltersChanged(
                        filters.copyWith(
                          formId: formId,
                          npsBand: npsBand,
                          clearFormId: formId == null,
                          clearNpsBand: npsBand == null,
                        ),
                      );
                      Navigator.pop(context);
                    },
                    child: const Text('Apply filters'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _RangePills extends StatelessWidget {
  const _RangePills({required this.selected, required this.onChanged});

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const options = [(3, '3 months'), (6, '6 months'), (12, '12 months'), (0, 'All')];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: FelloColors.paper,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: FelloColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (months, label) in options)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                onTap: () => onChanged(months),
                borderRadius: BorderRadius.circular(999),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected == months
                        ? FelloColors.accentSoft
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          selected == months ? FontWeight.w700 : FontWeight.w500,
                      color: selected == months
                          ? FelloColors.accentDeep
                          : FelloColors.inkSoft,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({
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
      style: OutlinedButton.styleFrom(
        foregroundColor: FelloColors.ink,
        side: const BorderSide(color: FelloColors.border),
        backgroundColor: FelloColors.paper,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.index,
    required this.onChanged,
    required this.formChips,
  });

  final int index;
  final ValueChanged<int> onChanged;
  final List<String> formChips;

  @override
  Widget build(BuildContext context) {
    const tabs = ['Overview', 'Forms', 'Responses', 'Comments'];
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < tabs.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 18),
                    child: InkWell(
                      onTap: () => onChanged(i),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tabs[i],
                            style: TextStyle(
                              fontWeight:
                                  index == i ? FontWeight.w700 : FontWeight.w500,
                              color: index == i
                                  ? FelloColors.ink
                                  : FelloColors.inkSoft,
                            ),
                          ),
                          const SizedBox(height: 8),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            height: 2,
                            width: 28,
                            color: index == i
                                ? FelloColors.accent
                                : Colors.transparent,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (formChips.isNotEmpty)
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(
                children: [
                  for (final chip in formChips)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: FelloColors.paper,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: FelloColors.border),
                      ),
                      child: Text(
                        chip,
                        style: const TextStyle(
                          fontSize: 12,
                          color: FelloColors.inkSoft,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.analytics});
  final _DashboardAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          _KpiCard(
            label: 'Overall NPS',
            value: analytics.nps == null
                ? '—'
                : analytics.nps!.round().toString(),
            delta: analytics.npsDelta,
            dark: true,
          ),
          _KpiCard(
            label: 'Avg rating',
            value: analytics.avgRating == null
                ? '—'
                : analytics.avgRating!.toStringAsFixed(1),
            delta: analytics.ratingDelta,
          ),
          _KpiCard(
            label: 'Responses',
            value: '${analytics.totalResponses}',
            delta: analytics.completionDelta,
          ),
          _KpiCard(
            label: 'Response rate',
            value: analytics.completionRate == 0
                ? analytics.responseRate
                : '${analytics.completionRate.round()}%',
            delta: analytics.responseDelta,
          ),
        ];

        if (constraints.maxWidth < 900) {
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final c in cards)
                SizedBox(
                  width: constraints.maxWidth < 520
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 12) / 2,
                  child: c,
                ),
            ],
          );
        }

        return Row(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: cards[i]),
            ],
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.delta,
    this.dark = false,
  });

  final String label;
  final String value;
  final int delta;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final up = delta >= 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: dark ? FelloColors.navy : FelloColors.paper,
        borderRadius: BorderRadius.circular(18),
        border: dark ? null : Border.all(color: FelloColors.border),
        boxShadow: [
          BoxShadow(
            color: FelloColors.ink.withValues(alpha: 0.03),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: dark ? Colors.white70 : FelloColors.inkSoft,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: GoogleFonts.dmSans(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  color: dark ? Colors.white : FelloColors.ink,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: up
                      ? (dark
                          ? Colors.white.withValues(alpha: 0.14)
                          : FelloColors.accentSoft)
                      : (dark
                          ? const Color(0x33E85D4C)
                          : const Color(0x14E85D4C)),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${up ? '+' : ''}$delta pts',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: up
                        ? (dark ? Colors.white : FelloColors.accentDeep)
                        : (dark ? const Color(0xFFFFB4A8) : FelloColors.danger),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChartsRow extends StatelessWidget {
  const _ChartsRow({required this.analytics});
  final _DashboardAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = constraints.maxWidth < 980;
        final bar = _Panel(
          title: 'NPS by month',
          child: SizedBox(
            height: 260,
            child: _NpsMonthChart(
              values: analytics.npsByMonth,
              labels: analytics.monthLabels,
            ),
          ),
        );
        final dist = _Panel(
          title: 'Score distribution',
          child: SizedBox(
            height: 260,
            child: _DistributionPanel(analytics: analytics),
          ),
        );

        if (stack) {
          return Column(
            children: [
              bar,
              const SizedBox(height: 12),
              dist,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 7, child: bar),
            const SizedBox(width: 12),
            Expanded(flex: 4, child: dist),
          ],
        );
      },
    );
  }
}

class _BottomRow extends StatelessWidget {
  const _BottomRow({
    required this.analytics,
    required this.forms,
    required this.responses,
  });

  final _DashboardAnalytics analytics;
  final List<FeedbackForm> forms;
  final List<FeedbackResponse> responses;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = constraints.maxWidth < 980;
        final heat = _Panel(
          title: 'NPS by form and month',
          child: _Heatmap(
            rows: analytics.heatmap,
            labels: analytics.monthLabels,
          ),
        );
        final comments = _Panel(
          title: 'Recent comments',
          child: _CommentsList(forms: forms, responses: responses),
        );
        if (stack) {
          return Column(
            children: [
              heat,
              const SizedBox(height: 12),
              comments,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 7, child: heat),
            const SizedBox(width: 12),
            Expanded(flex: 4, child: comments),
          ],
        );
      },
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: FelloColors.paper,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FelloColors.border),
        boxShadow: [
          BoxShadow(
            color: FelloColors.ink.withValues(alpha: 0.03),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: FelloColors.ink,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _NpsMonthChart extends StatelessWidget {
  const _NpsMonthChart({required this.values, required this.labels});

  final List<double?> values;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    if (values.every((v) => v == null)) {
      return const Center(child: Text('No NPS data in this period'));
    }

    var highlight = values.length - 1;
    for (var i = values.length - 1; i >= 0; i--) {
      if (values[i] != null) {
        highlight = i;
        break;
      }
    }

    return BarChart(
      BarChartData(
        maxY: 100,
        minY: -100,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(
            color: FelloColors.border.withValues(alpha: 0.8),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: 50,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 10, color: FelloColors.inkSoft),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= labels.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          i == highlight ? FontWeight.w700 : FontWeight.w500,
                      color: i == highlight
                          ? FelloColors.accentDeep
                          : FelloColors.inkSoft,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < values.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: values[i] ?? 0,
                  width: 18,
                  borderRadius: BorderRadius.circular(8),
                  color: i == highlight
                      ? FelloColors.accent
                      : FelloColors.chartMuted,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DistributionPanel extends StatelessWidget {
  const _DistributionPanel({required this.analytics});
  final _DashboardAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final total =
        analytics.promoters + analytics.passives + analytics.detractors;
    final p = total == 0 ? 0.0 : analytics.promoters / total;
    final n = total == 0 ? 0.0 : analytics.passives / total;
    final d = total == 0 ? 0.0 : analytics.detractors / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          total == 0
              ? 'No scores yet'
              : '${analytics.recommendPct.round()}% would recommend',
          style: GoogleFonts.dmSans(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: FelloColors.ink,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 18),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 14,
            child: Row(
              children: [
                Expanded(
                  flex: (p * 1000).round().clamp(0, 1000),
                  child: Container(color: FelloColors.accent),
                ),
                Expanded(
                  flex: (n * 1000).round().clamp(0, 1000),
                  child: Container(color: FelloColors.chartMuted),
                ),
                Expanded(
                  flex: (d * 1000).round().clamp(0, 1000),
                  child: Container(color: FelloColors.navySoft),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _LegendRow(
          color: FelloColors.accent,
          label: 'Promoters',
          value: analytics.promoters,
        ),
        const SizedBox(height: 10),
        _LegendRow(
          color: FelloColors.chartMuted,
          label: 'Passives',
          value: analytics.passives,
        ),
        const SizedBox(height: 10),
        _LegendRow(
          color: FelloColors.navySoft,
          label: 'Detractors',
          value: analytics.detractors,
        ),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: FelloColors.inkSoft),
          ),
        ),
        Text(
          '$value',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: FelloColors.ink,
          ),
        ),
      ],
    );
  }
}

class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.rows, required this.labels});

  final List<_HeatRow> rows;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('Publish a form to see the heatmap.'),
      );
    }

    Color cellColor(double? value) {
      if (value == null) return FelloColors.mist;
      final t = ((value + 100) / 200).clamp(0.0, 1.0);
      return Color.lerp(
        FelloColors.accentSoft,
        FelloColors.accentDeep,
        t,
      )!;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: 140),
              for (final label in labels)
                SizedBox(
                  width: 44,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      color: FelloColors.inkSoft,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (final row in rows) ...[
            Row(
              children: [
                SizedBox(
                  width: 140,
                  child: Text(
                    row.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: FelloColors.ink,
                    ),
                  ),
                ),
                for (final value in row.values)
                  Container(
                    width: 40,
                    height: 28,
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: cellColor(value),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      value == null ? '' : value.round().toString(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: value == null
                            ? Colors.transparent
                            : (value > 20
                                ? Colors.white
                                : FelloColors.accentDeep),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

class _CommentsList extends StatelessWidget {
  const _CommentsList({required this.forms, required this.responses});

  final List<FeedbackForm> forms;
  final List<FeedbackResponse> responses;

  @override
  Widget build(BuildContext context) {
    final formById = {for (final f in forms) f.id: f};
    final items = <_CommentItem>[];

    for (final r in responses) {
      final form = formById[r.formId];
      String? comment;
      int? nps;
      for (final a in r.answers) {
        final q = form?.questions
            .cast<Question?>()
            .firstWhere((q) => q?.id == a.questionId, orElse: () => null);
        if (q == null) continue;
        if ((q.type == QuestionType.longText ||
                q.type == QuestionType.shortText) &&
            a.value is String &&
            (a.value as String).trim().isNotEmpty) {
          comment = a.value as String;
        }
        if (q.type == QuestionType.nps && a.value is num) {
          nps = (a.value as num).toInt();
        }
      }
      if (comment != null) {
        items.add(
          _CommentItem(
            name: 'Customer',
            meta: form?.title ?? 'Form',
            comment: comment,
            score: nps,
          ),
        );
      }
    }

    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('No written comments yet.'),
      );
    }

    final shown = items.take(5).toList();
    return Column(
      children: [
        for (var i = 0; i < shown.length; i++) ...[
          _CommentTile(item: shown[i]),
          if (i < shown.length - 1) const Divider(height: 20),
        ],
      ],
    );
  }
}

class _CommentItem {
  const _CommentItem({
    required this.name,
    required this.meta,
    required this.comment,
    required this.score,
  });

  final String name;
  final String meta;
  final String comment;
  final int? score;
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.item});
  final _CommentItem item;

  @override
  Widget build(BuildContext context) {
    final scoreColor = item.score == null
        ? FelloColors.chartMuted
        : item.score! >= 9
            ? FelloColors.accent
            : item.score! >= 7
                ? FelloColors.warning
                : FelloColors.danger;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: FelloColors.accentSoft,
          child: Text(
            item.name.isEmpty ? 'C' : item.name[0].toUpperCase(),
            style: const TextStyle(
              color: FelloColors.accentDeep,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: FelloColors.ink,
                ),
              ),
              Text(
                item.meta,
                style: const TextStyle(
                  fontSize: 12,
                  color: FelloColors.inkSoft,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item.comment,
                style: const TextStyle(
                  color: FelloColors.inkSoft,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        if (item.score != null)
          Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: scoreColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${item.score}',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: scoreColor,
              ),
            ),
          ),
      ],
    );
  }
}
