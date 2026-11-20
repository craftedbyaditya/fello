import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/fello_colors.dart';
import '../../../shared/animations/fade_slide_in.dart';
import '../../../shared/widgets/fello_logo.dart';
import '../../../shared/widgets/fello_text_field.dart';
import 'widgets/google_one_tap.dart';
import '../bloc/auth_bloc.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, this.initialSignUp = false});

  final bool initialSignUp;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  late bool _signUp = widget.initialSignUp;
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _displayName = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late final TapGestureRecognizer _privacyRecognizer;
  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _toggleRecognizer;

  @override
  void initState() {
    super.initState();
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () => context.go('/privacy');
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () => context.go('/terms');
    _toggleRecognizer = TapGestureRecognizer()..onTap = _toggleMode;
    _applyModeDefaults();
  }

  @override
  void dispose() {
    _privacyRecognizer.dispose();
    _termsRecognizer.dispose();
    _toggleRecognizer.dispose();
    _email.dispose();
    _password.dispose();
    _displayName.dispose();
    super.dispose();
  }

  void _applyModeDefaults() {
    _email.clear();
    _password.clear();
    _displayName.clear();
  }

  void _toggleMode() {
    setState(() {
      _signUp = !_signUp;
      _applyModeDefaults();
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_signUp) {
      context.read<AuthBloc>().add(
        AuthSignUpSubmitted(
          email: _email.text,
          password: _password.text,
          displayName: _displayName.text,
        ),
      );
    } else {
      context.read<AuthBloc>().add(
        AuthSignInSubmitted(email: _email.text, password: _password.text),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
        final googleWebClientId = AppConfig.fromEnvironment().googleWebClientId;
        return Scaffold(
          backgroundColor: FelloColors.paper,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final form = ColoredBox(
                color: FelloColors.paper,
                child: SafeArea(
                  child: _AuthFormPanel(
                    signUp: _signUp,
                    loading: loading,
                    formKey: _formKey,
                    email: _email,
                    password: _password,
                    displayName: _displayName,
                    errorMessage: state.errorMessage,
                    onSubmit: _submit,
                    googleWebClientId: googleWebClientId,
                    onGoogleOAuth: () => context.read<AuthBloc>().add(
                      const AuthGoogleOAuthRequested(),
                    ),
                    onGoogleCredential: (idToken) => context
                        .read<AuthBloc>()
                        .add(AuthGoogleIdTokenSubmitted(idToken)),
                    privacyRecognizer: _privacyRecognizer,
                    termsRecognizer: _termsRecognizer,
                    toggleRecognizer: _toggleRecognizer,
                  ),
                ),
              );

              // The artwork is decorative. Removing it on narrow screens
              // preserves usable input widths instead of squeezing the form.
              if (constraints.maxWidth < 900) return form;
              return Row(
                children: [
                  const Expanded(flex: 30, child: _AuthArtPanel()),
                  Expanded(flex: 70, child: form),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _AuthArtPanel extends StatelessWidget {
  const _AuthArtPanel();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: FelloColors.paper,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Image.asset(
          'assets/images/auth_panel.jpg',
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          alignment: Alignment.center,
        ),
      ),
    );
  }
}

class _AuthFormPanel extends StatelessWidget {
  const _AuthFormPanel({
    required this.signUp,
    required this.loading,
    required this.formKey,
    required this.email,
    required this.password,
    required this.displayName,
    required this.errorMessage,
    required this.onSubmit,
    required this.googleWebClientId,
    required this.onGoogleOAuth,
    required this.onGoogleCredential,
    required this.privacyRecognizer,
    required this.termsRecognizer,
    required this.toggleRecognizer,
  });

  final bool signUp;
  final bool loading;
  final GlobalKey<FormState> formKey;
  final TextEditingController email;
  final TextEditingController password;
  final TextEditingController displayName;
  final String? errorMessage;
  final VoidCallback onSubmit;
  final String googleWebClientId;
  final VoidCallback onGoogleOAuth;
  final ValueChanged<String> onGoogleCredential;
  final TapGestureRecognizer privacyRecognizer;
  final TapGestureRecognizer termsRecognizer;
  final TapGestureRecognizer toggleRecognizer;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 420;
    final titleStyle = GoogleFonts.poppins(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      color: FelloColors.ink,
      height: 1.2,
      letterSpacing: -0.4,
    );
    final subtitleStyle = GoogleFonts.poppins(
      fontSize: 15,
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.italic,
      color: FelloColors.accent,
      height: 1.5,
    );
    final finePrintStyle = GoogleFonts.poppins(
      fontSize: 12.5,
      fontWeight: FontWeight.w400,
      color: FelloColors.inkSoft,
      height: 1.5,
    );
    final creditStyle = GoogleFonts.poppins(
      fontSize: 11,
      fontWeight: FontWeight.w400,
      color: FelloColors.inkSoft.withValues(alpha: 0.72),
      height: 1.4,
      letterSpacing: 0.1,
    );
    final googleEnabled = googleWebClientId.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 24 : 48,
                vertical: 28,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: FadeSlideIn(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!signUp && googleEnabled)
                        GoogleOneTap(
                          clientId: googleWebClientId,
                          onCredential: onGoogleCredential,
                        ),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: FelloLogo(size: 36),
                      ),
                      const SizedBox(height: 40),
                      Text(
                        signUp
                            ? 'Create your organisation'
                            : 'Sign in to Kaydo',
                        style: titleStyle,
                      ),
                      if (!signUp) ...[
                        const SizedBox(height: 10),
                        Text(
                          'See what your customers are saying.',
                          style: subtitleStyle,
                        ),
                      ],
                      const SizedBox(height: 36),
                      Container(
                        padding: EdgeInsets.fromLTRB(
                          compact ? 20 : 28,
                          28,
                          compact ? 20 : 28,
                          24,
                        ),
                        decoration: BoxDecoration(
                          color: FelloColors.paper,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: FelloColors.accentLime,
                            width: 0.8,
                          ),
                        ),
                        child: Form(
                          key: formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (signUp) ...[
                                FelloTextField(
                                  label: 'Full name',
                                  controller: displayName,
                                  textCapitalization: TextCapitalization.words,
                                  textInputAction: TextInputAction.next,
                                  validator: (v) =>
                                      v == null || v.trim().isEmpty
                                      ? 'Enter your name'
                                      : null,
                                ),
                                const SizedBox(height: 20),
                              ],
                              FelloTextField(
                                label: 'Work email',
                                controller: email,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.email],
                                validator: (v) => v == null || !v.contains('@')
                                    ? 'Enter a valid email'
                                    : null,
                              ),
                              const SizedBox(height: 20),
                              FelloTextField(
                                label: 'Password',
                                controller: password,
                                obscureText: true,
                                showObscureToggle: true,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => onSubmit(),
                                autofillHints: [
                                  if (signUp)
                                    AutofillHints.newPassword
                                  else
                                    AutofillHints.password,
                                ],
                                validator: (v) => v == null || v.length < 6
                                    ? 'Use at least 6 characters'
                                    : null,
                              ),
                              if (errorMessage != null) ...[
                                const SizedBox(height: 16),
                                Text(
                                  errorMessage!,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: FelloColors.danger,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                              if (!signUp) ...[
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: loading
                                        ? null
                                        : () => context.go('/forgot-password'),
                                    child: Text(
                                      'Forgot password?',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: FelloColors.accentDeep,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 28),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: loading ? null : onSubmit,
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
                                          signUp ? 'Create account' : 'Sign in',
                                        ),
                                ),
                              ),
                              if (!signUp && googleEnabled) ...[
                                const SizedBox(height: 18),
                                Row(
                                  children: [
                                    const Expanded(child: Divider()),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      child: Text('or', style: finePrintStyle),
                                    ),
                                    const Expanded(child: Divider()),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: loading ? null : onGoogleOAuth,
                                    icon: const _GoogleMark(),
                                    label: const Text('Continue with Google'),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                              Text.rich(
                                TextSpan(
                                  style: finePrintStyle,
                                  children: [
                                    TextSpan(
                                      text: signUp
                                          ? 'Already have an account? '
                                          : 'New organisation? ',
                                    ),
                                    TextSpan(
                                      text: signUp
                                          ? 'Sign in'
                                          : 'Create an account',
                                      style: finePrintStyle.copyWith(
                                        color: FelloColors.accentDeep,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      recognizer: loading
                                          ? null
                                          : toggleRecognizer,
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text.rich(
                        TextSpan(
                          style: finePrintStyle,
                          children: [
                            const TextSpan(
                              text: 'By continuing, you agree to our ',
                            ),
                            TextSpan(
                              text: 'Terms of Service',
                              style: finePrintStyle.copyWith(
                                color: FelloColors.ink,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                                decorationColor: FelloColors.border,
                              ),
                              recognizer: termsRecognizer,
                            ),
                            const TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: finePrintStyle.copyWith(
                                color: FelloColors.ink,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                                decorationColor: FelloColors.border,
                              ),
                              recognizer: privacyRecognizer,
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 24 : 40,
            8,
            compact ? 24 : 40,
            20,
          ),
          child: Row(
            children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    launchUrl(
                      Uri.parse('https://sayge.in'),
                      webOnlyWindowName: '_blank',
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Powered by', style: creditStyle),
                      const SizedBox(width: 6),
                      Image.asset(
                        'assets/images/sayge_logo.png',
                        height: 16,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Text('v${AppConfig.appVersion}', style: creditStyle),
            ],
          ),
        ),
      ],
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) => Text(
    'G',
    style: GoogleFonts.poppins(
      color: const Color(0xFF4285F4),
      fontSize: 18,
      fontWeight: FontWeight.w700,
    ),
  );
}
