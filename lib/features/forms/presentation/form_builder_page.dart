import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/fello_colors.dart';
import '../../../domain/entities/feedback_form.dart';
import '../../../domain/entities/question.dart';
import '../../../shared/animations/fade_slide_in.dart';
import '../bloc/forms_bloc.dart';

class FormBuilderPage extends StatefulWidget {
  const FormBuilderPage({super.key, required this.formId});

  final String formId;

  @override
  State<FormBuilderPage> createState() => _FormBuilderPageState();
}

class _FormBuilderPageState extends State<FormBuilderPage> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _slug = TextEditingController();
  bool _hydrated = false;

  @override
  void initState() {
    super.initState();
    context.read<FormsBloc>().add(FormSelected(widget.formId));
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _slug.dispose();
    super.dispose();
  }

  void _hydrate(FeedbackForm form) {
    if (_hydrated && _title.text == form.title) return;
    _title.text = form.title;
    _description.text = form.description;
    _slug.text = form.slug;
    _hydrated = true;
  }

  Future<void> _addQuestion(FeedbackForm form) async {
    QuestionType type = QuestionType.starRating;
    final label = TextEditingController();
    final options = TextEditingController();
    var required = true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('Add question'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<QuestionType>(
                      // ignore: deprecated_member_use
                      value: type,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: QuestionType.values
                          .map(
                            (t) => DropdownMenuItem(
                              value: t,
                              child: Text(_typeLabel(t)),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setLocal(() => type = v!),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: label,
                      decoration: const InputDecoration(labelText: 'Label'),
                    ),
                    if (type == QuestionType.singleChoice ||
                        type == QuestionType.multiChoice) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: options,
                        decoration: const InputDecoration(
                          labelText: 'Options (comma separated)',
                        ),
                      ),
                    ],
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Required'),
                      value: required,
                      onChanged: (v) => setLocal(() => required = v),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (label.text.trim().isEmpty) return;
                    Navigator.pop(context, true);
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok == true && mounted) {
      final optionList = options.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      context.read<FormsBloc>().add(
            QuestionUpsertRequested(
              Question(
                id: const Uuid().v4(),
                formId: form.id,
                type: type,
                label: label.text.trim(),
                required: required,
                options: optionList,
                sortOrder: form.questions.length,
              ),
            ),
          );
    }
    label.dispose();
    options.dispose();
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

    return BlocConsumer<FormsBloc, FormsState>(
      listenWhen: (p, c) =>
          c.justPublished ||
          (c.errorMessage != null && c.errorMessage != p.errorMessage),
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
        }
        if (state.justPublished && state.selected != null) {
          context.go('/forms/${state.selected!.id}/share');
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

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/forms'),
            ),
            title: Text(form.title),
            actions: [
              if (form.isPublished)
                TextButton(
                  onPressed: () => context.go('/forms/${form.id}/share'),
                  child: const Text('Share / QR'),
                ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: state.status == FormsStatus.saving
                    ? null
                    : () => context
                        .read<FormsBloc>()
                        .add(FormPublishRequested(form.id)),
                child: Text(form.isPublished ? 'Update publish' : 'Publish'),
              ),
              const SizedBox(width: 16),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 48),
            children: [
              FadeSlideIn(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Form details', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _title,
                        decoration: const InputDecoration(labelText: 'Title'),
                        onEditingComplete: () {
                          context.read<FormsBloc>().add(
                                FormUpdated(
                                  form.copyWith(
                                    title: _title.text,
                                    description: _description.text,
                                    slug: _slug.text,
                                  ),
                                ),
                              );
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _description,
                        maxLines: 3,
                        decoration:
                            const InputDecoration(labelText: 'Description'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _slug,
                        decoration: const InputDecoration(
                          labelText: 'Public slug',
                          helperText: 'Used in /f/your-slug',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton(
                          onPressed: () {
                            context.read<FormsBloc>().add(
                                  FormUpdated(
                                    form.copyWith(
                                      title: _title.text,
                                      description: _description.text,
                                      slug: _slug.text,
                                    ),
                                  ),
                                );
                          },
                          child: const Text('Save details'),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Questions',
                              style: theme.textTheme.titleLarge,
                            ),
                          ),
                          FilledButton.tonal(
                            onPressed: () => _addQuestion(form),
                            child: const Text('Add question'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (form.questions.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: FelloColors.border),
                            color: FelloColors.paper,
                          ),
                          child: const Text(
                            'No questions yet. Add a rating, NPS, or text question to get started.',
                          ),
                        )
                      else
                        ...form.questions.map(
                          (q) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: FelloColors.paper,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: FelloColors.border),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: FelloColors.accentSoft,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _typeLabel(q.type),
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(
                                        color: FelloColors.accentDeep,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          q.label,
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(fontSize: 16),
                                        ),
                                        Text(
                                          q.required
                                              ? 'Required'
                                              : 'Optional',
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Delete',
                                    onPressed: () => context
                                        .read<FormsBloc>()
                                        .add(QuestionDeleteRequested(q.id)),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
