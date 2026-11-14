import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/fello_colors.dart';
import '../../../shared/widgets/fello_logo.dart';
import '../../../shared/widgets/fello_text_field.dart';
import '../bloc/auth_bloc.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _email = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _feedback;
  bool _feedbackOk = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _feedback = null;
      _feedbackOk = false;
    });
    context.read<AuthBloc>().add(
          AuthPasswordResetRequested(email: _email.text),
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (p, c) =>
          p.status != c.status || p.errorMessage != c.errorMessage,
      listener: (context, state) {
        if (state.status != AuthStatus.loading &&
            state.errorMessage != null) {
          final ok = state.errorMessage!.startsWith('If that email');
          setState(() {
            _feedback = state.errorMessage;
            _feedbackOk = ok;
          });
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
                        'Reset password',
                        style: theme.textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter your work email and we’ll send a reset link.',
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 24),
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FelloTextField(
                              label: 'Work email',
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              validator: (v) {
                                if (v == null || !v.contains('@')) {
                                  return 'Enter a valid email';
                                }
                                return null;
                              },
                            ),
                            if (_feedback != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _feedback!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: _feedbackOk
                                      ? FelloColors.accentDeep
                                      : FelloColors.danger,
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
                                  : const Text('Send reset link'),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () => context.go('/sign-in'),
                              child: const Text('Back to sign in'),
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
