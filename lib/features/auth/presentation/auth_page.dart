import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/fello_colors.dart';
import '../../../shared/animations/fade_slide_in.dart';
import '../../../shared/widgets/fello_logo.dart';
import '../bloc/auth_bloc.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, this.initialSignUp = false});

  final bool initialSignUp;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  late bool _signUp = widget.initialSignUp;
  final _email = TextEditingController(text: 'ada@harbor.coffee');
  final _password = TextEditingController(text: 'fello123');
  final _orgName = TextEditingController();
  final _displayName = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _orgName.dispose();
    _displayName.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_signUp) {
      context.read<AuthBloc>().add(
            AuthSignUpSubmitted(
              email: _email.text,
              password: _password.text,
              organizationName: _orgName.text,
              displayName: _displayName.text,
            ),
          );
    } else {
      context.read<AuthBloc>().add(
            AuthSignInSubmitted(
              email: _email.text,
              password: _password.text,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (p, c) =>
          p.status != c.status || p.errorMessage != c.errorMessage,
      listener: (context, state) {
        if (state.isAuthenticated) {
          if (state.needsOnboarding) {
            context.go('/onboarding');
          } else {
            context.go('/dashboard');
          }
        }
      },
      builder: (context, state) {
        final loading = state.status == AuthStatus.loading;
        return Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFE8F5F1),
                  FelloColors.mist,
                  Color(0xFFF0F4F2),
                ],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: FadeSlideIn(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const FelloLogo(size: 44),
                          const SizedBox(height: 28),
                          Text(
                            _signUp
                                ? 'Start collecting clearer feedback'
                                : 'Welcome back',
                            style: theme.textTheme.displayMedium?.copyWith(
                              fontSize: 34,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _signUp
                                ? 'Create your organisation account. Customers never need to sign in.'
                                : 'Sign in to your Fello workspace. Demo: ada@harbor.coffee / fello123',
                            style: theme.textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 28),
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: FelloColors.paper.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: FelloColors.border),
                              boxShadow: [
                                BoxShadow(
                                  color: FelloColors.ink.withValues(alpha: 0.04),
                                  blurRadius: 24,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  if (_signUp) ...[
                                    TextFormField(
                                      controller: _orgName,
                                      decoration: const InputDecoration(
                                        labelText: 'Organisation name',
                                      ),
                                      validator: (v) =>
                                          v == null || v.trim().isEmpty
                                              ? 'Required'
                                              : null,
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _displayName,
                                      decoration: const InputDecoration(
                                        labelText: 'Your name',
                                      ),
                                      validator: (v) =>
                                          v == null || v.trim().isEmpty
                                              ? 'Required'
                                              : null,
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  TextFormField(
                                    controller: _email,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: const InputDecoration(
                                      labelText: 'Work email',
                                    ),
                                    validator: (v) =>
                                        v == null || !v.contains('@')
                                            ? 'Enter a valid email'
                                            : null,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _password,
                                    obscureText: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Password',
                                    ),
                                    validator: (v) =>
                                        v == null || v.length < 6
                                            ? 'Min 6 characters'
                                            : null,
                                  ),
                                  if (state.errorMessage != null) ...[
                                    const SizedBox(height: 12),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        state.errorMessage!,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(color: FelloColors.danger),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton(
                                      onPressed: loading ? null : _submit,
                                      child: loading
                                          ? const SizedBox(
                                              height: 18,
                                              width: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : Text(
                                              _signUp
                                                  ? 'Create account'
                                                  : 'Sign in',
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextButton(
                                    onPressed: loading
                                        ? null
                                        : () => setState(
                                              () => _signUp = !_signUp,
                                            ),
                                    child: Text(
                                      _signUp
                                          ? 'Already have an account? Sign in'
                                          : 'New organisation? Create account',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
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
