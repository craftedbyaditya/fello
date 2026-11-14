import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/theme/fello_colors.dart';
import '../../../core/theme/fello_metrics.dart';
import '../../../core/theme/fello_typography.dart';
import '../../../domain/entities/feedback_form.dart';
import '../../../domain/entities/question.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../../shared/animations/fade_slide_in.dart';
import '../../../shared/widgets/fello_back_button.dart';
import '../../../shared/widgets/fello_text_field.dart';
import '../../../shared/widgets/kaydo_toast.dart';
import '../bloc/forms_bloc.dart';
import 'widgets/add_question_dialog.dart';
import 'widgets/publish_success_dialog.dart';

class FormBuilderPage extends StatefulWidget {
  const FormBuilderPage({super.key, required this.formId});

  final String formId;

  @override
  State<FormBuilderPage> createState() => _FormBuilderPageState();
}

class _FormBuilderPageState extends State<FormBuilderPage> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  bool _hydrated = false;
  bool _savingDraft = false;

  @override
  void initState() {
    super.initState();
    context.read<FormsBloc>().add(FormSelected(widget.formId));
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  void _hydrate(FeedbackForm form) {
    if (_hydrated && _title.text == form.title) return;
    _title.text = form.title;
    _description.text = form.description;
    _hydrated = true;
  }

  FeedbackForm _editedFrom(FeedbackForm form) {
    return form.copyWith(
      title: _title.text.trim().isEmpty ? form.title : _title.text.trim(),
      description: _description.text.trim(),
    );
  }

  void _saveDraft(FeedbackForm form) {
    setState(() => _savingDraft = true);
    context.read<FormsBloc>().add(FormUpdated(_editedFrom(form)));
  }

  void _publish(FeedbackForm form) {
    setState(() => _savingDraft = false);
    context.read<FormsBloc>().add(FormPublishRequested(_editedFrom(form)));
  }

  Future<void> _addQuestion(FeedbackForm form) async {
    final result = await showAddQuestionDialog(context);
    if (result == null || !mounted) return;
    context.read<FormsBloc>().add(
          QuestionUpsertRequested(
            Question(
              id: const Uuid().v4(),
              formId: form.id,
              type: result.type,
              label: result.label,
              required: result.required,
              options: result.options,
              sortOrder: form.questions.length,
            ),
          ),
        );
  }

  Future<void> _editQuestion(Question question) async {
    final result = await showAddQuestionDialog(context, initial: question);
    if (result == null || !mounted) return;
    context.read<FormsBloc>().add(
          QuestionUpsertRequested(
            question.copyWith(
              type: result.type,
              label: result.label,
              required: result.required,
              options: result.options,
            ),
          ),
        );
  }

  String _typeLabel(QuestionType t) => switch (t) {
        QuestionType.starRating => 'Star rating (1–5)',
        QuestionType.nps => 'NPS (0–10)',
        QuestionType.shortText => 'Short text',
        QuestionType.longText => 'Long text',
        QuestionType.yesNo => 'Yes / No',
        QuestionType.singleChoice => 'Single choice',
        QuestionType.multiChoice => 'Multi choice',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAdmin =
        context.watch<AuthBloc>().state.session?.profile.isAdmin ?? false;

    return BlocConsumer<FormsBloc, FormsState>(
      listenWhen: (p, c) =>
          c.justPublished ||
          (c.errorMessage != null && c.errorMessage != p.errorMessage) ||
          (p.status == FormsStatus.saving &&
              c.status == FormsStatus.ready &&
              !c.justPublished),
      listener: (context, state) async {
        if (state.errorMessage != null) {
          setState(() => _savingDraft = false);
          showKaydoToast(
            context,
            message: state.errorMessage!,
            tone: KaydoToastTone.error,
          );
          return;
        }

        if (state.justPublished && state.selected != null) {
          final form = state.selected!;
          final link = '${getIt<AppConfig>().publicBaseUrl}/f/${form.slug}';
          await showPublishSuccessDialog(
            context: context,
            formTitle: form.title,
            link: link,
          );
          if (context.mounted) {
            context.go('/forms');
          }
          return;
        }

        if (_savingDraft &&
            state.status == FormsStatus.ready &&
            !state.justPublished) {
          setState(() => _savingDraft = false);
          showKaydoToast(
            context,
            message: 'Successfully saved as draft',
            tone: KaydoToastTone.success,
          );
        }
      },
      builder: (context, state) {
        final form = state.selected;
        if (form == null ||
            (state.status == FormsStatus.loading && form.id != widget.formId)) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        _hydrate(form);
        final busy = state.status == FormsStatus.saving;
        final pad = FelloTypography.pagePadding(context);

        return Scaffold(
          backgroundColor: FelloColors.paper,
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(pad, 0, pad, 24),
                  children: [
                    FadeSlideIn(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: FelloBackButton(
                              tooltip: 'Back to forms',
                              onPressed: () => context.go('/forms'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            form.title.isEmpty ? 'Untitled form' : form.title,
                            style: FelloTypography.pageTitle(context),
                          ),
                          const SizedBox(height: 20),
                          FelloTextField(
                            label: 'Title',
                            controller: _title,
                          ),
                          const SizedBox(height: 16),
                          FelloTextField(
                            label: 'Description (optional)',
                            controller: _description,
                            maxLines: 3,
                          ),
                          const SizedBox(height: 24),
                          const Divider(height: 1),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Questions',
                                  style: theme.textTheme.titleLarge,
                                ),
                              ),
                              FilledButton(
                                onPressed: () => _addQuestion(form),
                                child: const Text('Add question'),
                              ),
                            ],
                          ),
                          if (form.questions.isEmpty)
                            const SizedBox(height: 8)
                          else ...[
                            const SizedBox(height: 12),
                            ...form.questions.map(
                              (q) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: FelloColors.paper,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: FelloColors.border,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              q.label,
                                              style: theme
                                                  .textTheme.titleLarge
                                                  ?.copyWith(fontSize: 16),
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Edit',
                                            onPressed: () =>
                                                _editQuestion(q),
                                            visualDensity:
                                                VisualDensity.compact,
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                              color: FelloColors.inkSoft,
                                            ),
                                          ),
                                          if (isAdmin)
                                            IconButton(
                                              tooltip: 'Delete',
                                              onPressed: () => context
                                                  .read<FormsBloc>()
                                                  .add(
                                                    QuestionDeleteRequested(
                                                      q.id,
                                                    ),
                                                  ),
                                              visualDensity:
                                                  VisualDensity.compact,
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                color: FelloColors.danger,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: FelloColors.accentSoft,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              _typeLabel(q.type),
                                              style: theme
                                                  .textTheme.labelLarge
                                                  ?.copyWith(
                                                color:
                                                    FelloColors.accentDeep,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: q.required
                                                  ? const Color(0xFFFFF1E8)
                                                  : const Color(0xFFF3F4F6),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              q.required
                                                  ? 'Required'
                                                  : 'Optional',
                                              style: theme
                                                  .textTheme.labelLarge
                                                  ?.copyWith(
                                                color: q.required
                                                    ? const Color(0xFFC2410C)
                                                    : FelloColors.inkSoft,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _BottomActions(
                busy: busy,
                canPublish: form.questions.isNotEmpty,
                onSaveDraft: () => _saveDraft(form),
                onPublish: () => _publish(form),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.busy,
    required this.canPublish,
    required this.onSaveDraft,
    required this.onPublish,
  });

  final bool busy;
  final bool canPublish;
  final VoidCallback onSaveDraft;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FelloColors.paper,
      elevation: 8,
      shadowColor: FelloColors.ink.withValues(alpha: 0.08),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            FelloTypography.pagePadding(context),
            14,
            FelloTypography.pagePadding(context),
            14,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SizedBox(
                height: FelloMetrics.controlHeight,
                child: OutlinedButton(
                  onPressed: busy ? null : onSaveDraft,
                  child: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save as draft'),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: FelloMetrics.buttonMinWidth,
                height: FelloMetrics.controlHeight,
                child: FilledButton(
                  onPressed: busy || !canPublish ? null : onPublish,
                  child: const Text('Publish'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
