import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/fello_colors.dart';
import '../../../domain/entities/org_invite.dart';
import '../../../domain/repositories/team_repository.dart';
import '../../../shared/widgets/fello_logo.dart';
import '../../../shared/widgets/fello_text_field.dart';
import '../../auth/bloc/auth_bloc.dart';

class AcceptInvitePage extends StatefulWidget {
  const AcceptInvitePage({super.key, required this.token});

  final String token;

  @override
  State<AcceptInvitePage> createState() => _AcceptInvitePageState();
}

class _AcceptInvitePageState extends State<AcceptInvitePage> {
  InvitePreview? _preview;
  String? _loadError;
  bool _loading = true;

  final _email = TextEditingController();
  final _name = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final preview =
          await getIt<TeamRepository>().getInvitePreview(widget.token);
      if (!mounted) return;
      if (preview == null) {
        setState(() {
          _loading = false;
          _loadError = 'This invite link is invalid.';
        });
        return;
      }
      if (!preview.isPending) {
        setState(() {
          _loading = false;
          _preview = preview;
          _loadError = preview.status == InviteStatus.accepted
              ? 'This invite was already accepted. Sign in instead.'
              : 'This invite is no longer valid.';
        });
        return;
      }
      _email.text = preview.email;
      setState(() {
        _loading = false;
        _preview = preview;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = "We couldn't load this invite. Please try again.";
      });
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final preview = _preview;
    if (preview == null) return;
    context.read<AuthBloc>().add(
          AuthSignUpSubmitted(
            email: preview.email,
            password: _password.text,
            displayName: _name.text,
            inviteToken: preview.token,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (p, c) =>
          p.status != c.status || p.errorMessage != c.errorMessage,
      listener: (context, state) {
        if (state.isAuthenticated) {
          context.go(
            state.needsOnboarding ? '/onboarding' : '/dashboard',
          );
        }
      },
      builder: (context, authState) {
        final submitting = authState.status == AuthStatus.loading;

        return Scaffold(
          backgroundColor: FelloColors.paper,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: _loading
                      ? const CircularProgressIndicator()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const FelloLogo(size: 36),
                            const SizedBox(height: 28),
                            if (_preview != null) ...[
                              Text(
                                'Join ${_preview!.organizationName}',
                                style: theme.textTheme.headlineLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "You've been invited as an employee. "
                                'Create your account to get started.',
                                style: theme.textTheme.bodyLarge,
                              ),
                            ] else
                              Text(
                                'Invite',
                                style: theme.textTheme.headlineLarge,
                              ),
                            const SizedBox(height: 24),
                            if (_loadError != null) ...[
                              Text(
                                _loadError!,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: FelloColors.danger,
                                ),
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton(
                                onPressed: () => context.go('/sign-in'),
                                child: const Text('Go to sign in'),
                              ),
                            ] else if (_preview != null) ...[
                              Container(
                                padding: const EdgeInsets.all(22),
                                decoration: BoxDecoration(
                                  color: FelloColors.paper,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: FelloColors.border),
                                ),
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      FelloTextField(
                                        label: 'Work email',
                                        controller: _email,
                                        enabled: false,
                                      ),
                                      const SizedBox(height: 14),
                                      FelloTextField(
                                        label: 'Your name',
                                        controller: _name,
                                        textCapitalization:
                                            TextCapitalization.words,
                                        textInputAction: TextInputAction.next,
                                        validator: (v) =>
                                            v == null || v.trim().isEmpty
                                                ? 'Required'
                                                : null,
                                      ),
                                      const SizedBox(height: 14),
                                      FelloTextField(
                                        label: 'Password',
                                        controller: _password,
                                        obscureText: true,
                                        textInputAction: TextInputAction.done,
                                        onFieldSubmitted: (_) => _submit(),
                                        validator: (v) {
                                          if (v == null || v.length < 6) {
                                            return 'At least 6 characters';
                                          }
                                          return null;
                                        },
                                      ),
                                      if (authState.errorMessage != null) ...[
                                        const SizedBox(height: 12),
                                        Text(
                                          authState.errorMessage!,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                            color: FelloColors.danger,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 20),
                                      FilledButton(
                                        onPressed:
                                            submitting ? null : _submit,
                                        child: submitting
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : const Text('Join workspace'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: () => context.go('/sign-in'),
                                child: const Text(
                                  'Already have an account? Sign in',
                                ),
                              ),
                            ],
                          ],
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
