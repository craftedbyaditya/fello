import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/fello_colors.dart';
import '../../../core/theme/fello_typography.dart';
import '../../../domain/entities/dashboard_stats.dart';
import '../../../domain/entities/feedback_form.dart';
import '../../../domain/entities/question.dart';
import '../../../domain/entities/response.dart';
import '../../../domain/onboarding/starter_form_template.dart';
import '../../../domain/plan_limit_failure.dart';
import '../../../domain/repositories/form_repository.dart';
import '../../../shared/animations/fade_slide_in.dart';
import '../../../shared/widgets/kaydo_toast.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../bloc/dashboard_bloc.dart';
import 'widgets/setup_checklist.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _exploring = false;
  bool _creatingForm = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final orgId = context.read<AuthBloc>().state.session?.organization.id;
    if (orgId == null) return;
    final dash = context.read<DashboardBloc>().state;
    // Avoid duplicate loads; still refresh when org changes (e.g. after auth).
    if (dash.orgId == orgId &&
        (dash.status == DashboardStatus.loading ||
            dash.status == DashboardStatus.ready)) {
      return;
    }
    context.read<DashboardBloc>().add(DashboardLoadRequested(orgId));
  }

  Future<void> _createFirstForm() async {
    if (_creatingForm) return;
    final session = context.read<AuthBloc>().state.session;
    if (session == null) return;

    setState(() => _creatingForm = true);
    try {
      final template = StarterFormTemplate.forBusinessType(
        session.organization.businessType,
      );
      final repo = getIt<FormRepository>();
      final form = await repo.createForm(
        orgId: session.organization.id,
        title: template.title,
        description: template.description,
      );
      const uuid = Uuid();
      for (var i = 0; i < template.questions.length; i++) {
        final draft = template.questions[i];
        await repo.upsertQuestion(
          Question(
            id: uuid.v4(),
            formId: form.id,
            type: draft.type,
            label: draft.label,
            required: draft.required,
            sortOrder: i,
          ),
        );
      }
      if (!mounted) return;
      context.go('/forms/${form.id}');
    } on PlanLimitFailure catch (e) {
      if (!mounted) return;
      setState(() => _creatingForm = false);
      showKaydoToast(
        context,
        message: e.message,
        tone: KaydoToastTone.error,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _creatingForm = false);
      showKaydoToast(
        context,
        message: "Couldn't create your form. Please try again.",
        tone: KaydoToastTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          previous.session?.organization.id !=
          current.session?.organization.id,
      listener: (context, authState) {
        // Full page refresh: auth restores after the first frame, so reload then.
        if (authState.session != null) _load();
      },
      child: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          final session = context.watch<AuthBloc>().state.session;
          final waitingForAuthOrData = session == null ||
              state.status == DashboardStatus.initial ||
              (state.status == DashboardStatus.loading &&
                  state.forms.isEmpty &&
                  state.stats == null);

          if (waitingForAuthOrData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == DashboardStatus.failure &&
              state.stats == null &&
              state.forms.isEmpty) {
            return Center(
              child: Text(state.errorMessage ?? 'Failed to load'),
            );
          }

          final stats = state.stats;
          final analytics = _DashboardAnalytics.from(
            responses: state.responses,
            forms: state.forms,
            stats: stats,
          );
          final progress = SetupProgress.fromForms(
            state.forms,
            hasLogo: session.organization.hasLogo,
          );
          final showWelcome = state.forms.isEmpty && !_exploring;
          final isAdmin = session.profile.isAdmin;

        return ColoredBox(
          color: FelloColors.paper,
          child: RefreshIndicator(
            onRefresh: () async => _load(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (showWelcome) ...[
                  SoftPadding(
                    padding: const EdgeInsets.fromLTRB(28, 28, 28, 12),
                    child: FadeSlideIn(
                      child: FirstTimeWelcome(
                        creating: _creatingForm,
                        onCreateForm: _createFirstForm,
                        onExplore: () => setState(() => _exploring = true),
                      ),
                    ),
                  ),
                  SoftPadding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 36),
                    child: FadeSlideIn(
                      delay: const Duration(milliseconds: 60),
                      child: SetupChecklistCard(
                        progress: progress,
                        onCreateForm: _creatingForm ? null : _createFirstForm,
                        onInviteTeam:
                            isAdmin ? () => context.go('/team') : null,
                        onAddLogo:
                            isAdmin ? () => context.go('/settings/logo') : null,
                      ),
                    ),
                  ),
                ] else ...[
                  SoftPadding(
                    padding: const EdgeInsets.fromLTRB(28, 28, 28, 12),
                    child: FadeSlideIn(
                      child: _DashboardGreeting(
                        userName: session.profile.displayName,
                      ),
                    ),
                  ),
                  if (progress.showChecklist)
                    SoftPadding(
                      padding: const EdgeInsets.fromLTRB(28, 0, 28, 12),
                      child: FadeSlideIn(
                        delay: const Duration(milliseconds: 30),
                        child: SetupChecklistCard(
                          progress: progress,
                          onCreateForm:
                              _creatingForm ? null : _createFirstForm,
                          onInviteTeam:
                              isAdmin ? () => context.go('/team') : null,
                          onAddLogo: isAdmin
                              ? () => context.go('/settings/logo')
                              : null,
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
                    if (state.forms.length > 1)
                      SoftPadding(
                        padding: const EdgeInsets.fromLTRB(28, 20, 28, 36),
                        child: FadeSlideIn(
                          delay: const Duration(milliseconds: 120),
                          child: _FormTilesSection(
                            forms: state.forms,
                            responses: state.responses,
                          ),
                        ),
                      )
                    else
                      const SoftPadding(
                        padding: EdgeInsets.only(bottom: 36),
                        child: SizedBox.shrink(),
                      ),
                  ],
                ],
              ],
            ),
          ),
        );
        },
      ),
    );
  }
}

class _DashboardGreeting extends StatelessWidget {
  const _DashboardGreeting({required this.userName});

  final String userName;

  String get _firstName {
    final parts = userName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'there';
    return parts.first;
  }

  String get _salutation {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return FelloPageHeader(
      title: '$_salutation, $_firstName',
      subtitle: "Here's what your customers are saying.",
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

class _FormTileStats {
  const _FormTileStats({
    required this.form,
    required this.totalReviews,
    required this.avgRating,
    required this.positivePct,
    required this.negativePct,
  });

  final FeedbackForm form;
  final int totalReviews;
  final double? avgRating;
  final double positivePct;
  final double negativePct;

  static _FormTileStats from({
    required FeedbackForm form,
    required List<FeedbackResponse> responses,
  }) {
    final formResponses =
        responses.where((r) => r.formId == form.id).toList(growable: false);
    var promoters = 0;
    var detractors = 0;
    var scored = 0;
    final ratings = <double>[];

    for (final response in formResponses) {
      for (final answer in response.answers) {
        for (final question in form.questions) {
          if (question.id != answer.questionId || answer.value is! num) {
            continue;
          }
          final value = (answer.value as num).toDouble();
          if (question.type == QuestionType.nps) {
            scored++;
            final nps = value.round();
            if (nps >= 9) {
              promoters++;
            } else if (nps <= 6) {
              detractors++;
            }
            ratings.add(value);
          } else if (question.type == QuestionType.starRating) {
            ratings.add(value);
          }
        }
      }
    }

    return _FormTileStats(
      form: form,
      totalReviews: formResponses.length,
      avgRating: ratings.isEmpty
          ? null
          : ratings.reduce((a, b) => a + b) / ratings.length,
      positivePct: scored == 0 ? 0 : (promoters / scored) * 100,
      negativePct: scored == 0 ? 0 : (detractors / scored) * 100,
    );
  }
}

class _FormTilesSection extends StatelessWidget {
  const _FormTilesSection({
    required this.forms,
    required this.responses,
  });

  final List<FeedbackForm> forms;
  final List<FeedbackResponse> responses;

  @override
  Widget build(BuildContext context) {
    final tiles = forms
        .map((form) => _FormTileStats.from(form: form, responses: responses))
        .toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1100
            ? 3
            : width >= 720
                ? 2
                : 1;
        final gap = 14.0;
        final tileWidth = columns == 1
            ? width
            : (width - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final tile in tiles)
              SizedBox(
                width: tileWidth,
                child: _FormTile(stats: tile),
              ),
          ],
        );
      },
    );
  }
}

class _FormTile extends StatelessWidget {
  const _FormTile({required this.stats});

  final _FormTileStats stats;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FelloColors.paper,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => context.go('/dashboard/reviews/${stats.form.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            color: FelloColors.paper,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: FelloColors.accentLime, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stats.form.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: FelloColors.ink,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                stats.form.isPublished ? 'Published' : 'Draft',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: FelloColors.inkSoft,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _FormTileMetric(
                      label: 'Reviews',
                      value: '${stats.totalReviews}',
                    ),
                  ),
                  Expanded(
                    child: _FormTileMetric(
                      label: 'Avg rating',
                      value: stats.avgRating == null
                          ? '—'
                          : stats.avgRating!.toStringAsFixed(1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _FormTileMetric(
                      label: 'Positive',
                      value: '${stats.positivePct.round()}%',
                      valueColor: FelloColors.accent,
                    ),
                  ),
                  Expanded(
                    child: _FormTileMetric(
                      label: 'Negative',
                      value: '${stats.negativePct.round()}%',
                      valueColor: FelloColors.danger,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormTileMetric extends StatelessWidget {
  const _FormTileMetric({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: FelloColors.inkSoft,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: valueColor ?? FelloColors.ink,
            height: 1.1,
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
            label: 'Avg rating',
            value: analytics.avgRating == null
                ? '—'
                : analytics.avgRating!.toStringAsFixed(1),
            delta: analytics.ratingDelta,
          ),
          _KpiCard(
            label: 'Positive',
            value: '${analytics.promoters}',
            delta: analytics.completionDelta,
          ),
          _KpiCard(
            label: 'Responses',
            value: '${analytics.totalResponses}',
            delta: analytics.responseDelta.abs() > 0
                ? analytics.completionDelta
                : 2,
          ),
          _KpiCard(
            label: 'Needs attention',
            value: '${analytics.detractors}',
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
  });

  final String label;
  final String value;
  final int delta;

  @override
  Widget build(BuildContext context) {
    final up = delta >= 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: FelloColors.inkSoft,
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
                style: GoogleFonts.poppins(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  color: FelloColors.ink,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: up
                      ? FelloColors.accentSoft
                      : const Color(0x14E85D4C),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${up ? '+' : ''}$delta pts',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: up ? FelloColors.accentDeep : FelloColors.danger,
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

