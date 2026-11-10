import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
  @override
  void initState() {
    super.initState();
    final orgId = context.read<AuthBloc>().state.session?.organization.id;
    if (orgId != null) {
      context.read<DashboardBloc>().add(DashboardLoadRequested(orgId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, state) {
        if (state.status == DashboardStatus.loading && state.stats == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.status == DashboardStatus.failure && state.stats == null) {
          return Center(child: Text(state.errorMessage ?? 'Failed to load'));
        }

        final stats = state.stats;
        return RefreshIndicator(
          onRefresh: () async {
            final orgId =
                context.read<AuthBloc>().state.session?.organization.id;
            if (orgId != null) {
              context.read<DashboardBloc>().add(DashboardLoadRequested(orgId));
            }
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                sliver: SliverToBoxAdapter(
                  child: FadeSlideIn(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Dashboard', style: theme.textTheme.headlineLarge),
                        const SizedBox(height: 6),
                        Text(
                          'See how customers are responding across your forms.',
                          style: theme.textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 20),
                        _FiltersBar(
                          forms: state.forms,
                          filters: state.filters,
                          onChanged: (f) => context
                              .read<DashboardBloc>()
                              .add(DashboardFiltersChanged(f)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (stats != null)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverToBoxAdapter(
                    child: FadeSlideIn(
                      delay: const Duration(milliseconds: 80),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth >= 800;
                          final cards = [
                            _StatCard(
                              label: 'Responses',
                              value: '${stats.totalResponses}',
                              hint: stats.responseRateLabel,
                            ),
                            _StatCard(
                              label: 'Avg rating',
                              value: stats.averageRating == null
                                  ? '—'
                                  : stats.averageRating!.toStringAsFixed(1),
                              hint: 'Out of 5',
                            ),
                            _StatCard(
                              label: 'NPS',
                              value: stats.npsScore == null
                                  ? '—'
                                  : stats.npsScore!.round().toString(),
                              hint: 'Net promoter score',
                            ),
                          ];
                          if (wide) {
                            return Row(
                              children: [
                                for (var i = 0; i < cards.length; i++) ...[
                                  if (i > 0) const SizedBox(width: 12),
                                  Expanded(child: cards[i]),
                                ],
                              ],
                            );
                          }
                          return Column(
                            children: [
                              for (final c in cards) ...[
                                c,
                                const SizedBox(height: 12),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              if (stats != null)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  sliver: SliverToBoxAdapter(
                    child: FadeSlideIn(
                      delay: const Duration(milliseconds: 140),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final stack = constraints.maxWidth < 900;
                          final charts = [
                            Expanded(
                              child: _ChartPanel(
                                title: 'Volume over time',
                                child: _VolumeChart(volume: stats.volumeByDay),
                              ),
                            ),
                            Expanded(
                              child: _ChartPanel(
                                title: 'NPS distribution',
                                child: _NpsChart(
                                  distribution: stats.npsDistribution,
                                ),
                              ),
                            ),
                          ];
                          if (stack) {
                            return Column(
                              children: [
                                SizedBox(
                                  height: 260,
                                  child: _ChartPanel(
                                    title: 'Volume over time',
                                    child: _VolumeChart(
                                      volume: stats.volumeByDay,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 260,
                                  child: _ChartPanel(
                                    title: 'NPS distribution',
                                    child: _NpsChart(
                                      distribution: stats.npsDistribution,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }
                          return SizedBox(
                            height: 280,
                            child: Row(
                              children: [
                                charts[0],
                                const SizedBox(width: 12),
                                charts[1],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                sliver: SliverToBoxAdapter(
                  child: FadeSlideIn(
                    delay: const Duration(milliseconds: 200),
                    child: _ResponsesList(
                      responses: state.responses,
                      forms: state.forms,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.forms,
    required this.filters,
    required this.onChanged,
  });

  final List<FeedbackForm> forms;
  final ResponseFilters filters;
  final ValueChanged<ResponseFilters> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<String?>(
            // ignore: deprecated_member_use
            value: filters.formId,
            decoration: const InputDecoration(labelText: 'Form'),
            items: [
              const DropdownMenuItem(value: null, child: Text('All forms')),
              ...forms.map(
                (f) => DropdownMenuItem(value: f.id, child: Text(f.title)),
              ),
            ],
            onChanged: (v) => onChanged(
              filters.copyWith(formId: v, clearFormId: v == null),
            ),
          ),
        ),
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<String?>(
            // ignore: deprecated_member_use
            value: filters.npsBand,
            decoration: const InputDecoration(labelText: 'NPS band'),
            items: const [
              DropdownMenuItem(value: null, child: Text('All')),
              DropdownMenuItem(value: 'promoter', child: Text('Promoters')),
              DropdownMenuItem(value: 'passive', child: Text('Passives')),
              DropdownMenuItem(value: 'detractor', child: Text('Detractors')),
            ],
            onChanged: (v) => onChanged(
              filters.copyWith(npsBand: v, clearNpsBand: v == null),
            ),
          ),
        ),
        SizedBox(
          width: 160,
          child: DropdownButtonFormField<int?>(
            // ignore: deprecated_member_use
            value: filters.minRating,
            decoration: const InputDecoration(labelText: 'Min rating'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Any')),
              for (var i = 1; i <= 5; i++)
                DropdownMenuItem(value: i, child: Text('$i+')),
            ],
            onChanged: (v) => onChanged(
              filters.copyWith(minRating: v, clearMinRating: v == null),
            ),
          ),
        ),
        TextButton(
          onPressed: () => onChanged(const ResponseFilters()),
          child: const Text('Clear filters'),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.hint,
  });

  final String label;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FelloColors.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FelloColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Text(value, style: theme.textTheme.headlineLarge),
          const SizedBox(height: 4),
          Text(hint, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _ChartPanel extends StatelessWidget {
  const _ChartPanel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FelloColors.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FelloColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _VolumeChart extends StatelessWidget {
  const _VolumeChart({required this.volume});

  final Map<DateTime, int> volume;

  @override
  Widget build(BuildContext context) {
    if (volume.isEmpty) {
      return const Center(child: Text('No responses in this range'));
    }
    final days = volume.keys.toList()..sort();
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 28),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (days.length / 4).clamp(1, 10).toDouble(),
              getTitlesWidget: (value, meta) {
                final i = value.round();
                if (i < 0 || i >= days.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    DateFormat.Md().format(days[i]),
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < days.length; i++)
                FlSpot(i.toDouble(), (volume[days[i]] ?? 0).toDouble()),
            ],
            isCurved: true,
            color: FelloColors.accent,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: FelloColors.accent.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

class _NpsChart extends StatelessWidget {
  const _NpsChart({required this.distribution});

  final Map<int, int> distribution;

  @override
  Widget build(BuildContext context) {
    final total = distribution.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) {
      return const Center(child: Text('No NPS answers yet'));
    }
    return BarChart(
      BarChartData(
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 28),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i <= 10; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: (distribution[i] ?? 0).toDouble(),
                  color: i <= 6
                      ? FelloColors.danger
                      : i <= 8
                          ? FelloColors.warning
                          : FelloColors.success,
                  width: 12,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ResponsesList extends StatelessWidget {
  const _ResponsesList({required this.responses, required this.forms});

  final List<FeedbackResponse> responses;
  final List<FeedbackForm> forms;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formById = {for (final f in forms) f.id: f};

    return Container(
      decoration: BoxDecoration(
        color: FelloColors.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FelloColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              'Recent responses',
              style: theme.textTheme.titleLarge,
            ),
          ),
          if (responses.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No responses match these filters.'),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: responses.length.clamp(0, 50),
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final r = responses[index];
                final form = formById[r.formId];
                final summary = r.answers.map((a) {
                  final q = form?.questions
                      .cast<Question?>()
                      .firstWhere(
                        (q) => q?.id == a.questionId,
                        orElse: () => null,
                      );
                  if (q == null) return '${a.value}';
                  return '${q.label}: ${a.value}';
                }).take(2).join(' · ');
                return ListTile(
                  title: Text(form?.title ?? 'Form'),
                  subtitle: Text(
                    summary.isEmpty ? 'No answers' : summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    DateFormat.MMMd().add_jm().format(r.submittedAt),
                    style: theme.textTheme.bodyMedium,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
