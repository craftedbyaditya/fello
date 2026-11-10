import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/fello_colors.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/repositories/form_repository.dart';
import '../../../shared/animations/fade_slide_in.dart';
import '../../../shared/widgets/fello_logo.dart';
import '../../auth/bloc/auth_bloc.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _orgController = TextEditingController();
  final _formTitle = TextEditingController(text: 'Customer feedback');
  final _formDescription = TextEditingController(
    text: 'Tell us how we did — it takes under a minute.',
  );
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final session = context.read<AuthBloc>().state.session;
    _orgController.text = session?.organization.name ?? '';
  }

  @override
  void dispose() {
    _orgController.dispose();
    _formTitle.dispose();
    _formDescription.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final session = context.read<AuthBloc>().state.session;
    if (session == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await getIt<AuthRepository>().updateOrganization(
        name: _orgController.text.trim(),
      );
      final form = await getIt<FormRepository>().createForm(
        orgId: session.organization.id,
        title: _formTitle.text.trim(),
        description: _formDescription.text.trim(),
      );
      if (!mounted) return;
      context.read<AuthBloc>().add(const AuthOnboardingCompleted());
      context.go('/forms/${form.id}');
    } catch (e) {
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE8F5F1), FelloColors.mist],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: FadeSlideIn(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const FelloLogo(size: 36),
                      const SizedBox(height: 28),
                      Text(
                        'Set up your workspace',
                        style: theme.textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Confirm your organisation and create your first feedback form.',
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _orgController,
                        decoration: const InputDecoration(
                          labelText: 'Organisation name',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _formTitle,
                        decoration: const InputDecoration(
                          labelText: 'First form title',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _formDescription,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Form description',
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: TextStyle(color: FelloColors.danger),
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _saving ? null : _finish,
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Continue to form builder'),
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
  }
}
