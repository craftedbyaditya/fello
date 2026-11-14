import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/fello_colors.dart';
import '../../../shared/widgets/fello_logo.dart';
import '../../../shared/widgets/fello_text_field.dart';
import '../bloc/auth_bloc.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthBloc>().add(
          AuthPasswordUpdateRequested(newPassword: _password.text),
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (p, c) =>
          p.status != c.status || p.errorMessage != c.errorMessage,
      listener: (context, state) {
        if (state.isAuthenticated &&
            state.errorMessage == null &&
            state.status == AuthStatus.authenticated) {
          context.go(
            state.needsOnboarding ? '/onboarding' : '/dashboard',
          );
        }
        if (!state.isAuthenticated &&
            state.errorMessage == 'Password updated. Please sign in.') {
          context.go('/sign-in');
        }
      },
      builder: (context, state) {
        final loading = state.status == AuthStatus.loading;
        return Scaffold(
          backgroundColor: FelloColors.paper,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const FelloLogo(size: 36),
                      const SizedBox(height: 28),
                      Text(
                        'Choose a new password',
                        style: theme.textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 24),
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FelloTextField(
                              label: 'New password',
                              controller: _password,
                              obscureText: true,
                              textInputAction: TextInputAction.next,
                              validator: (v) {
                                if (v == null || v.length < 6) {
                                  return 'At least 6 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            FelloTextField(
                              label: 'Confirm password',
                              controller: _confirm,
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              validator: (v) {
                                if (v != _password.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),
                            if (state.errorMessage != null &&
                                state.errorMessage !=
                                    'Password updated. Please sign in.') ...[
                              const SizedBox(height: 12),
                              Text(
                                state.errorMessage!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: FelloColors.danger,
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: loading ? null : _submit,
                              child: loading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Update password'),
                            ),
                          ],
                        ),
                      ),
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
