import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/config/app_config.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/theme/fello_colors.dart';
import '../../../domain/entities/question.dart';
import '../../../domain/repositories/form_repository.dart';
import '../../../domain/repositories/response_repository.dart';
import '../../../shared/animations/fade_slide_in.dart';
import '../../../shared/widgets/fello_logo.dart';
import '../../../shared/widgets/fello_text_field.dart';
import '../../../shared/widgets/pressable_scale.dart';
import '../../../shared/widgets/turnstile_widget.dart';
import '../bloc/public_form_bloc.dart';

class PublicFormPage extends StatelessWidget {
  const PublicFormPage({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context) {
    final config = getIt<AppConfig>();
    return BlocProvider(
      create: (_) => PublicFormBloc(
        formRepository: getIt<FormRepository>(),
        responseRepository: getIt<ResponseRepository>(),
        requireTurnstile: config.turnstileEnabled,
      )..add(PublicFormLoadRequested(slug)),
      child: _PublicFormView(turnstileSiteKey: config.turnstileSiteKey),
    );
  }
}

class _PublicFormView extends StatelessWidget {
  const _PublicFormView({required this.turnstileSiteKey});

  final String turnstileSiteKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: FelloColors.paper,
      body: SafeArea(
        child: BlocBuilder<PublicFormBloc, PublicFormState>(
          builder: (context, state) {
              if (state.status == PublicFormStatus.loading ||
                  state.status == PublicFormStatus.initial) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state.status == PublicFormStatus.notFound ||
                  state.status == PublicFormStatus.failure) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const FelloLogo(size: 36),
                        const SizedBox(height: 20),
                        Text(
                          state.errorMessage ?? 'Form unavailable',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                );
              }
              if (state.status == PublicFormStatus.submitted) {
                return Center(
                  child: FadeSlideIn(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const FelloLogo(size: 40),
                          const SizedBox(height: 24),
                          Text(
                            'Thank you',
                            style: theme.textTheme.displayMedium,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Your feedback was received. You can close this page.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              final form = state.form!;
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                    children: [
                      FadeSlideIn(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (form.displaysOrgLogo)
                              Image.network(
                                form.orgLogoUrl!,
                                height: 40,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    const FelloLogo(size: 32),
                              )
                            else
                              const FelloLogo(size: 32),
                            const SizedBox(height: 24),
                            Text(
                              form.title,
                              style: theme.textTheme.headlineLarge,
                            ),
                            if (form.description.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                form.description,
                                style: theme.textTheme.bodyLarge,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      ...form.questions.asMap().entries.map((entry) {
                        final index = entry.key;
                        final q = entry.value;
                        return FadeSlideIn(
                          delay: Duration(milliseconds: 60 * index),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _QuestionCard(
                              question: q,
                              value: state.answers[q.id],
                              onChanged: (value) => context
                                  .read<PublicFormBloc>()
                                  .add(
                                    PublicFormAnswerChanged(
                                      questionId: q.id,
                                      value: value,
                                    ),
                                  ),
                            ),
                          ),
                        );
                      }),
                      if (turnstileSiteKey.isNotEmpty) ...[
                        TurnstileWidget(
                          siteKey: turnstileSiteKey,
                          onToken: (token) => context
                              .read<PublicFormBloc>()
                              .add(PublicFormTurnstileUpdated(token)),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (state.errorMessage != null) ...[
                        Text(
                          state.errorMessage!,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: FelloColors.danger),
                        ),
                        const SizedBox(height: 12),
                      ],
                      PressableScale(
                        onTap: state.status == PublicFormStatus.submitting
                            ? null
                            : () => context
                                .read<PublicFormBloc>()
                                .add(const PublicFormSubmitted()),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed:
                                state.status == PublicFormStatus.submitting
                                    ? null
                                    : () => context
                                        .read<PublicFormBloc>()
                                        .add(const PublicFormSubmitted()),
                            child: state.status == PublicFormStatus.submitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Submit feedback'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
          },
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.question,
    required this.value,
    required this.onChanged,
  });

  final Question question;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: FelloColors.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FelloColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: question.label,
              style: theme.textTheme.titleLarge?.copyWith(fontSize: 17),
              children: [
                if (question.required)
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(color: FelloColors.danger),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildInput(context),
        ],
      ),
    );
  }

  Widget _buildInput(BuildContext context) {
    switch (question.type) {
      case QuestionType.starRating:
        final current = value is int ? value as int : 0;
        return Row(
          children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                onPressed: () => onChanged(i),
                icon: Icon(
                  i <= current ? Icons.star : Icons.star_border,
                  color: FelloColors.accent,
                  size: 32,
                ),
              ),
          ],
        );
      case QuestionType.nps:
        final current = value is int ? value as int : -1;
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i <= 10; i++)
              PressableScale(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: current == i
                        ? FelloColors.accent
                        : FelloColors.mist,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: current == i
                          ? FelloColors.accent
                          : FelloColors.border,
                    ),
                  ),
                  child: Text(
                    '$i',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: current == i ? Colors.white : FelloColors.ink,
                    ),
                  ),
                ),
              ),
          ],
        );
      case QuestionType.shortText:
        return FelloTextField(
          initialValue: value is String ? value as String : '',
          onChanged: onChanged,
        );
      case QuestionType.longText:
        return FelloTextField(
          initialValue: value is String ? value as String : '',
          maxLines: 4,
          onChanged: onChanged,
        );
      case QuestionType.yesNo:
        final current = value is bool ? value as bool? : null;
        return Row(
          children: [
            ChoiceChip(
              label: const Text('Yes'),
              selected: current == true,
              onSelected: (_) => onChanged(true),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('No'),
              selected: current == false,
              onSelected: (_) => onChanged(false),
            ),
          ],
        );
      case QuestionType.singleChoice:
        return Column(
          children: [
            for (final opt in question.options)
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(opt),
                value: opt,
                // ignore: deprecated_member_use
                groupValue: value is String ? value as String : null,
                // ignore: deprecated_member_use
                onChanged: (v) => onChanged(v),
              ),
          ],
        );
      case QuestionType.multiChoice:
        final selected =
            (value is List) ? List<String>.from(value as List) : <String>[];
        return Column(
          children: [
            for (final opt in question.options)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(opt),
                value: selected.contains(opt),
                onChanged: (checked) {
                  final next = [...selected];
                  if (checked == true) {
                    next.add(opt);
                  } else {
                    next.remove(opt);
                  }
                  onChanged(next);
                },
              ),
          ],
        );
    }
  }
}
