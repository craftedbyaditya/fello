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
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              FelloBackButton(
                                tooltip: 'Back to forms',
                                onPressed: () => context.go('/forms'),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  form.title.isEmpty
                                      ? 'Untitled form'
                                      : form.title,
                                  style: FelloTypography.pageTitle(context),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _SectionBox(
                            title: 'General details',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                FelloTextField(
                                  label: 'Title',
                                  controller: _title,
                                ),
                                const SizedBox(height: 14),
                                FelloTextField(
                                  label: 'Description (optional)',
                                  controller: _description,
                                  maxLines: 3,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _SectionBox(
                            title: 'Questions',
                            trailing: SizedBox(
                              height: FelloMetrics.controlHeight,
                              child: FilledButton(
                                onPressed: () => _addQuestion(form),
                                style: FilledButton.styleFrom(
                                  minimumSize: FelloMetrics.controlMinSize,
                                  maximumSize: FelloMetrics.controlMaxSize,
                                  fixedSize: const Size.fromHeight(
                                    FelloMetrics.controlHeight,
                                  ),
                                  padding: FelloMetrics.controlPaddingH,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ),
                                child: const Text('Add question'),
                              ),
                            ),
                            child: form.questions.isEmpty
                                ? Text(
                                    'No questions yet. Add your first question to start collecting feedback.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: FelloColors.inkSoft,
                                    ),
                                  )
                                : Column(
                                    children: [
                                      for (var i = 0;
                                          i < form.questions.length;
                                          i++) ...[
                                        if (i > 0) const SizedBox(height: 8),
                                        _QuestionTile(
                                          question: form.questions[i],
                                          typeLabel: _typeLabel(
                                            form.questions[i].type,
                                          ),
                                          canDelete: isAdmin,
                                          onEdit: () => _editQuestion(
                                            form.questions[i],
                                          ),
                                          onDelete: () => context
                                              .read<FormsBloc>()
                                              .add(
                                                QuestionDeleteRequested(
                                                  form.questions[i].id,
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

class _SectionBox extends StatelessWidget {
  const _SectionBox({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: FelloColors.paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FelloColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(fontSize: 17),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _QuestionTile extends StatelessWidget {
  const _QuestionTile({
    required this.question,
    required this.typeLabel,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
  });

  final Question question;
  final String typeLabel;
  final bool canDelete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FelloColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question.label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _Tag(
                      label: typeLabel,
                      background: FelloColors.accentSoft,
                      foreground: FelloColors.accentDeep,
                    ),
                    _Tag(
                      label: question.required ? 'Required' : 'Optional',
                      background: question.required
                          ? const Color(0xFFFFF1E8)
                          : const Color(0xFFF3F4F6),
                      foreground: question.required
                          ? const Color(0xFFC2410C)
                          : FelloColors.inkSoft,
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit',
            onPressed: onEdit,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
            icon: const Icon(
              Icons.edit_outlined,
              size: 18,
              color: FelloColors.inkSoft,
            ),
          ),
          if (canDelete)
            IconButton(
              tooltip: 'Delete',
              onPressed: onDelete,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.delete_outline,
                size: 18,
                color: FelloColors.danger,
              ),
            ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
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
