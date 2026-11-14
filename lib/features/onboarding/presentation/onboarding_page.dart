import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/fello_colors.dart';
import '../../../domain/entities/business_type.dart';
import '../../../shared/animations/fade_slide_in.dart';
import '../../../shared/widgets/fello_logo.dart';
import '../../../shared/widgets/fello_text_field.dart';
import '../../auth/bloc/auth_bloc.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _orgController = TextEditingController();
  final _orgFormKey = GlobalKey<FormState>();
  int _step = 0;
  BusinessType? _selectedType;
  bool _submitting = false;

  @override
  void dispose() {
    _orgController.dispose();
    super.dispose();
  }

  void _continueToBusinessType() {
    if (!_orgFormKey.currentState!.validate()) return;
    setState(() => _step = 1);
  }

  void _finish({BusinessType? businessType, bool skipped = false}) {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      if (!skipped && businessType != null) {
        _selectedType = businessType;
      }
    });
    context.read<AuthBloc>().add(
          AuthOnboardingCompleted(
            organizationName: _orgController.text.trim(),
            businessType: skipped ? null : (businessType ?? _selectedType),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (p, c) =>
          p.status != c.status ||
          p.needsOnboarding != c.needsOnboarding ||
          p.errorMessage != c.errorMessage,
      listener: (context, state) {
        if (state.isAuthenticated && !state.needsOnboarding) {
          context.go('/dashboard');
          return;
        }
        if (state.errorMessage != null &&
            state.status == AuthStatus.authenticated) {
          setState(() => _submitting = false);
        }
      },
      builder: (context, state) {
        final loading =
            _submitting || state.status == AuthStatus.loading;
        return Scaffold(
          backgroundColor: FelloColors.paper,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: FadeSlideIn(
                    key: ValueKey(_step),
                    child: _step == 0
                        ? _OrgStep(
                            theme: theme,
                            formKey: _orgFormKey,
                            controller: _orgController,
                            loading: loading,
                            errorMessage: state.errorMessage,
                            onContinue: _continueToBusinessType,
                          )
                        : _BusinessTypeStep(
                            theme: theme,
                            selected: _selectedType,
                            loading: loading,
                            errorMessage: state.errorMessage,
                            onSelect: (type) =>
                                setState(() => _selectedType = type),
                            onContinue: () =>
                                _finish(businessType: _selectedType),
                            onSkip: () => _finish(skipped: true),
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OrgStep extends StatelessWidget {
  const _OrgStep({
    required this.theme,
    required this.formKey,
    required this.controller,
    required this.loading,
    required this.errorMessage,
    required this.onContinue,
  });

  final ThemeData theme;
  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final bool loading;
  final String? errorMessage;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FelloLogo(size: 36),
        const SizedBox(height: 28),
        Text(
          "Let's set up your workspace",
          style: theme.textTheme.headlineLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'This name appears across your dashboard and feedback experience.',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: FelloColors.paper.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: FelloColors.border),
          ),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FelloTextField(
                  label: 'Organisation name',
                  controller: controller,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => onContinue(),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    errorMessage!,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: FelloColors.danger),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: loading ? null : onContinue,
                  child: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Continue'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BusinessTypeStep extends StatelessWidget {
  const _BusinessTypeStep({
    required this.theme,
    required this.selected,
    required this.loading,
    required this.errorMessage,
    required this.onSelect,
    required this.onContinue,
    required this.onSkip,
  });

  final ThemeData theme;
  final BusinessType? selected;
  final bool loading;
  final String? errorMessage;
  final ValueChanged<BusinessType> onSelect;
  final VoidCallback onContinue;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FelloLogo(size: 36),
        const SizedBox(height: 28),
        Text(
          'What kind of business do you run?',
          style: theme.textTheme.headlineLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Optional — we use this to suggest a starter feedback form later.',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final type in BusinessType.values)
              _BusinessTypeChip(
                label: type.label,
                selected: selected == type,
                onTap: loading ? null : () => onSelect(type),
              ),
          ],
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: 16),
          Text(
            errorMessage!,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: FelloColors.danger),
          ),
        ],
        const SizedBox(height: 28),
        FilledButton(
          onPressed: loading ? null : onContinue,
          child: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  selected == null
                      ? 'Continue to dashboard'
                      : 'Continue',
                ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: loading ? null : onSkip,
          child: const Text('Skip for now'),
        ),
      ],
    );
  }
}

class _BusinessTypeChip extends StatelessWidget {
  const _BusinessTypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? FelloColors.accentSoft : FelloColors.paper,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 140),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? FelloColors.accent : FelloColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: FelloColors.ink,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
          ),
        ),
      ),
    );
  }
}
