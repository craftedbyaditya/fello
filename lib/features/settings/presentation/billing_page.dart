import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/fello_colors.dart';
import '../../../domain/entities/subscription_plan.dart';
import '../../../domain/repositories/billing_repository.dart';
import '../../../shared/widgets/kaydo_toast.dart';
import '../../auth/bloc/auth_bloc.dart';

class BillingPage extends StatefulWidget {
  const BillingPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> {
  PlanUsage? _usage;
  String? _error;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = context.read<AuthBloc>().state.session;
    if (session == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final usage = await getIt<BillingRepository>().getUsage(
        session.organization.id,
      );
      if (!mounted) return;
      setState(() {
        _usage = usage;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _selectPlan(SubscriptionPlan plan) async {
    final session = context.read<AuthBloc>().state.session;
    if (session == null || _saving) return;
    if (session.organization.planId == plan.id) return;

    setState(() => _saving = true);
    try {
      await getIt<BillingRepository>().selectPlan(
        orgId: session.organization.id,
        planId: plan.id,
      );
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst(RegExp(r'^[^:]+:\s*'), '');
      showKaydoToast(
        context,
        message: message.isEmpty
            ? 'Plan changes unlock when billing goes live.'
            : message,
        tone: KaydoToastTone.info,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openPlansDialog() async {
    final usage = _usage;
    final session = context.read<AuthBloc>().state.session;
    if (usage == null || session == null) return;
    final currentPlan = usage.plan;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: FelloColors.paper,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: FelloColors.border),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 22, 12, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  'Choose a plan',
                  style: Theme.of(dialogContext).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(dialogContext).pop(),
                icon: const Icon(Icons.close, color: FelloColors.inkSoft),
              ),
            ],
          ),
          content: SizedBox(
            width: 720,
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final plan in SubscriptionPlan.catalog)
                    SizedBox(
                      width: 210,
                      child: _PlanPickCard(
                        plan: plan,
                        selected: currentPlan.id == plan.id,
                        busy: false,
                        onSelect: () {
                          Navigator.of(dialogContext).pop();
                          if (plan.id != currentPlan.id) {
                            _selectPlan(plan);
                          }
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthBloc>().state.session;
    if (session == null || !session.profile.isAdmin) {
      return _gate(context, 'Only admins can view pricing and billing.');
    }

    final theme = Theme.of(context);
    final usage = _usage;

    final body = _loading
        ? const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          )
        : _error != null
        ? Text(_error!, style: const TextStyle(color: FelloColors.danger))
        : _OverviewBody(
            usage: usage!,
            onUpgrade: _openPlansDialog,
            onManagePayments: () {
              showKaydoToast(
                context,
                message: 'Payment management unlocks when billing goes live.',
                tone: KaydoToastTone.info,
              );
            },
          );
    if (widget.embedded) return body;

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 48),
      children: [
        Text('Subscription', style: theme.textTheme.headlineLarge),
        const SizedBox(height: 24),
        body,
      ],
    );
  }

  Widget _gate(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('Back to dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewBody extends StatelessWidget {
  const _OverviewBody({
    required this.usage,
    required this.onUpgrade,
    required this.onManagePayments,
  });

  final PlanUsage usage;
  final VoidCallback onUpgrade;
  final VoidCallback onManagePayments;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 820;
        final planCard = _CurrentPlanCard(usage: usage, onUpgrade: onUpgrade);
        final paymentCard = _NextPaymentCard(
          usage: usage,
          onManagePayments: onManagePayments,
        );
        if (!wide) {
          return Column(
            children: [planCard, const SizedBox(height: 16), paymentCard],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: planCard),
            const SizedBox(width: 16),
            Expanded(flex: 4, child: paymentCard),
          ],
        );
      },
    );
  }
}

class _CurrentPlanCard extends StatelessWidget {
  const _CurrentPlanCard({required this.usage, required this.onUpgrade});

  final PlanUsage usage;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plan = usage.plan;
    final maxResponses = plan.maxResponsesPerMonth;
    final used = usage.responsesThisMonth;
    final progress =
        usage.responseProgress ??
        (maxResponses == null ? 0.15 : (used / maxResponses).clamp(0.0, 1.0));
    final usageLabel = maxResponses == null
        ? '$used responses this month'
        : '$used of $maxResponses responses';

    return Container(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 26),
      decoration: BoxDecoration(
        color: FelloColors.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FelloColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: FelloColors.ink,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  plan.name.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Plan',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: FelloColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            usageLabel,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: FelloColors.inkSoft,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: FelloColors.chartMuted,
              color: FelloColors.accent,
            ),
          ),
          const SizedBox(height: 28),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                plan.priceInrMonthly == 0 ? '₹0' : '₹${plan.priceInrMonthly}',
                style: theme.textTheme.displayMedium?.copyWith(
                  fontSize: 42,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  color: FelloColors.ink,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '/month',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: FelloColors.inkSoft,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: onUpgrade,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Upgrade Plan'),
                  SizedBox(width: 10),
                  CircleAvatar(
                    radius: 11,
                    backgroundColor: Colors.white24,
                    child: Icon(
                      Icons.arrow_forward,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NextPaymentCard extends StatelessWidget {
  const _NextPaymentCard({required this.usage, required this.onManagePayments});

  final PlanUsage usage;
  final VoidCallback onManagePayments;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nextDate = usage.periodEnd.toLocal().subtract(
      const Duration(days: 1),
    );
    final dateLabel = DateFormat('MMMM d, yyyy').format(nextDate);
    final isFree = usage.plan.priceInrMonthly == 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 26),
      decoration: BoxDecoration(
        color: FelloColors.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FelloColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isFree ? 'No payment due on Free' : 'Next payment on $dateLabel',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 18,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isFree
                ? 'Upgrade anytime to unlock higher limits and workspace logo.'
                : 'Billing renews monthly for ${usage.plan.name}.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: FelloColors.inkSoft,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 28),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: onManagePayments,
              style: OutlinedButton.styleFrom(
                foregroundColor: FelloColors.accentDeep,
                side: const BorderSide(color: FelloColors.accent),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
              ),
              child: const Text('Manage Payments'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanPickCard extends StatelessWidget {
  const _PlanPickCard({
    required this.plan,
    required this.selected,
    required this.busy,
    required this.onSelect,
  });

  final SubscriptionPlan plan;
  final bool selected;
  final bool busy;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FelloColors.paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? FelloColors.accent : FelloColors.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            plan.name,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            plan.priceLabel,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          for (final line in plan.highlights.take(3)) ...[
            Text(
              line,
              style: theme.textTheme.bodySmall?.copyWith(
                color: FelloColors.inkSoft,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 2),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: selected
                ? OutlinedButton(
                    onPressed: onSelect,
                    child: const Text('Current'),
                  )
                : FilledButton(
                    onPressed: onSelect,
                    child: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            plan.priceInrMonthly == 0 ? 'Use Free' : 'Choose',
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
