import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/fello_colors.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../shared/widgets/fello_text_field.dart';
import '../../../shared/widgets/kaydo_toast.dart';
import '../../auth/bloc/auth_bloc.dart';
import 'workspace_logo_page.dart';

class AccountSettingsPage extends StatelessWidget {
  const AccountSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthBloc>().state.session;
    if (session == null || !session.profile.isAdmin) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Only admins can manage account settings.',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
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

    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 48),
      children: [
        Text('Settings', style: theme.textTheme.headlineLarge),
        const SizedBox(height: 20),
        const _OrganizationNameCard(),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 620;
            final cards = [
              const _LogoSettingsCard(),
              _SubscriptionSettingsCard(),
            ];
            return stacked
                ? Column(
                    children: [cards[0], const SizedBox(height: 16), cards[1]],
                  )
                : SizedBox(
                    height: 190,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: cards[0]),
                        const SizedBox(width: 16),
                        Expanded(child: cards[1]),
                      ],
                    ),
                  );
          },
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 112,
          child: const _TeamComingSoonCard(
            icon: Icons.group_outlined,
            title: 'Manage team',
          ),
        ),
      ],
    );
  }
}

class _OrganizationNameCard extends StatelessWidget {
  const _OrganizationNameCard();

  Future<void> _edit(BuildContext context) async {
    final organization = context.read<AuthBloc>().state.session!.organization;
    final controller = TextEditingController(text: organization.name);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Organization name'),
        content: FelloTextField(
          label: 'Name',
          controller: controller,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              try {
                final updated = await getIt<AuthRepository>()
                    .updateOrganization(name: name);
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                context.read<AuthBloc>().add(AuthOrganizationUpdated(updated));
                showKaydoToast(context, message: 'Organization name updated');
              } catch (_) {
                if (!dialogContext.mounted) return;
                showKaydoToast(
                  dialogContext,
                  message: "We couldn't update the organization name.",
                  tone: KaydoToastTone.error,
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = context.watch<AuthBloc>().state.session!.organization.name;
    return _Panel(
      icon: Icons.business_outlined,
      title: 'Organization',
      child: Row(
        children: [
          Expanded(
            child: Text(name, style: Theme.of(context).textTheme.titleMedium),
          ),
          OutlinedButton.icon(
            onPressed: () => _edit(context),
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Edit name'),
          ),
        ],
      ),
    );
  }
}

class _TeamComingSoonCard extends StatelessWidget {
  const _TeamComingSoonCard({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: FelloColors.paper,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: FelloColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: FelloColors.mist,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: FelloColors.accent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Coming soon',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: FelloColors.inkSoft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: FelloColors.mist,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Not available',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: FelloColors.inkSoft,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoSettingsCard extends StatelessWidget {
  const _LogoSettingsCard();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      icon: Icons.image_outlined,
      title: 'Workspace logo',
      child: const SizedBox(
        height: 106,
        child: WorkspaceLogoPage(embedded: true),
      ),
    );
  }
}

class _SubscriptionSettingsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final plan = context.watch<AuthBloc>().state.session!.organization.plan;
    final theme = Theme.of(context);
    return _Panel(
      icon: Icons.credit_card_outlined,
      title: 'Subscription',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current plan: ${plan.name}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            plan.priceLabel,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: FelloColors.inkSoft,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => context.go('/settings/billing'),
            icon: const Icon(Icons.arrow_upward_rounded, size: 16),
            label: const Text('Upgrade plan'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.icon, required this.title, required this.child});

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FelloColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: FelloColors.accent, size: 24),
              const SizedBox(width: 10),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
