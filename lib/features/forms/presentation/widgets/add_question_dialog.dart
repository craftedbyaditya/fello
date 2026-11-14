import 'package:flutter/material.dart';

import '../../../../core/theme/fello_colors.dart';
import '../../../../core/theme/fello_metrics.dart';
import '../../../../domain/entities/question.dart';
import '../../../../shared/widgets/fello_text_field.dart';

class AddQuestionResult {
  const AddQuestionResult({
    required this.type,
    required this.label,
    required this.required,
    this.options = const [],
  });

  final QuestionType type;
  final String label;
  final bool required;
  final List<String> options;
}

/// Wide, stepped dialog for creating or editing a question.
Future<AddQuestionResult?> showAddQuestionDialog(
  BuildContext context, {
  Question? initial,
}) {
  return showDialog<AddQuestionResult>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _AddQuestionDialog(initial: initial),
  );
}

class _AddQuestionDialog extends StatefulWidget {
  const _AddQuestionDialog({this.initial});

  final Question? initial;

  @override
  State<_AddQuestionDialog> createState() => _AddQuestionDialogState();
}

class _AddQuestionDialogState extends State<_AddQuestionDialog> {
  static const _types = <(QuestionType, String, String, IconData)>[
    (
      QuestionType.singleChoice,
      'Single option',
      'Customer picks one answer',
      Icons.radio_button_checked_outlined,
    ),
    (
      QuestionType.multiChoice,
      'Multiple options',
      'Customer can pick several answers',
      Icons.checklist_rounded,
    ),
    (
      QuestionType.shortText,
      'Short text',
      'A brief written answer',
      Icons.short_text_rounded,
    ),
    (
      QuestionType.starRating,
      'Rating stars',
      '1–5 star rating',
      Icons.star_outline_rounded,
    ),
    (
      QuestionType.yesNo,
      'Yes / No',
      'A simple yes or no answer',
      Icons.thumbs_up_down_outlined,
    ),
  ];

  late int _step;
  QuestionType? _type;
  final _label = TextEditingController();
  late final List<TextEditingController> _optionControllers;
  var _required = true;
  String? _error;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _type = initial.type;
      _label.text = initial.label;
      _required = initial.required;
      _step = 1;
      final seeded = initial.options
          .map((o) => o.trim())
          .where((o) => o.isNotEmpty)
          .toList();
      if (seeded.length >= 2) {
        _optionControllers = [
          for (final option in seeded) TextEditingController(text: option),
        ];
      } else if (seeded.length == 1) {
        _optionControllers = [
          TextEditingController(text: seeded.first),
          TextEditingController(),
        ];
      } else {
        _optionControllers = [
          TextEditingController(),
          TextEditingController(),
        ];
      }
    } else {
      _step = 0;
      _optionControllers = [
        TextEditingController(),
        TextEditingController(),
      ];
    }
  }

  @override
  void dispose() {
    _label.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _needsOptions =>
      _type == QuestionType.singleChoice || _type == QuestionType.multiChoice;

  List<String> get _optionValues => _optionControllers
      .map((c) => c.text.trim())
      .where((t) => t.isNotEmpty)
      .toList();

  void _addOption() {
    setState(() {
      _optionControllers.add(TextEditingController());
      _error = null;
    });
  }

  void _removeOption(int index) {
    if (_optionControllers.length <= 2) return;
    setState(() {
      _optionControllers.removeAt(index).dispose();
      _error = null;
    });
  }

  void _next() {
    setState(() => _error = null);
    if (_step == 0) {
      if (_type == null) {
        setState(() => _error = 'Select a question type to continue.');
        return;
      }
      setState(() => _step = 1);
      return;
    }
    if (_step == 1) {
      if (_label.text.trim().isEmpty) {
        setState(() => _error = 'Enter the question text.');
        return;
      }
      setState(() => _step = 2);
      return;
    }

    final options = _optionValues;
    if (_needsOptions && options.length < 2) {
      setState(() => _error = 'Add at least two options.');
      return;
    }

    Navigator.pop(
      context,
      AddQuestionResult(
        type: _type!,
        label: _label.text.trim(),
        required: _required,
        options: _needsOptions ? options : const [],
      ),
    );
  }

  void _back() {
    if (_step == 0 || (_isEditing && _step == 1)) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _error = null;
      _step -= 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final dialogWidth = (width * 0.72).clamp(560.0, 840.0);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: FelloMetrics.dialogShape,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          minWidth: dialogWidth,
          minHeight: 420,
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      switch (_step) {
                        0 => 'What type of question?',
                        1 => 'Write your question',
                        _ => 'Finish setup',
                      },
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontSize: 22,
                      ),
                    ),
                  ),
                  Text(
                    'Step ${_step + 1} of 3',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: FelloColors.inkSoft,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                switch (_step) {
                  0 => 'Choose how customers should answer.',
                  1 => 'Keep it clear and short.',
                  _ => _needsOptions
                      ? 'Add the answer choices customers can pick from.'
                      : 'Confirm whether this question is required.',
                },
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: switch (_step) {
                    0 => _TypeStep(
                        types: _types,
                        selected: _type,
                        onSelect: (type) => setState(() {
                          _type = type;
                          _error = null;
                        }),
                      ),
                    1 => FelloTextField(
                        label: 'Question',
                        controller: _label,
                        autofocus: true,
                        maxLines: 3,
                      ),
                    _ => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_needsOptions) ...[
                            Text(
                              'Options',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 10),
                            for (var i = 0; i < _optionControllers.length; i++) ...[
                              if (i > 0) const SizedBox(height: 10),
                              _OptionRow(
                                index: i,
                                controller: _optionControllers[i],
                                canRemove: _optionControllers.length > 2,
                                onRemove: () => _removeOption(i),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: _addOption,
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('Add option'),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ] else
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: FelloColors.mist,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: FelloColors.border),
                              ),
                              child: Text(
                                switch (_type) {
                                  QuestionType.starRating =>
                                    'Customers will rate from 1 to 5 stars.',
                                  QuestionType.yesNo =>
                                    'Customers will choose Yes or No.',
                                  _ => 'Customers will type a short answer.',
                                },
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: FelloColors.ink,
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Required'),
                            subtitle: const Text(
                              'Customers must answer before submitting',
                            ),
                            value: _required,
                            onChanged: (v) => setState(() => _required = v),
                          ),
                        ],
                      ),
                  },
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: FelloColors.danger,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _back,
                    child: Text(
                      _step == 0 || (_isEditing && _step == 1)
                          ? 'Cancel'
                          : 'Back',
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _next,
                    child: Text(
                      _step == 2
                          ? (_isEditing ? 'Save changes' : 'Add question')
                          : 'Continue',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.index,
    required this.controller,
    required this.canRemove,
    required this.onRemove,
  });

  final int index;
  final TextEditingController controller;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: FelloTextField(
            label: 'Option ${index + 1}',
            controller: controller,
            autofocus: index == 0,
          ),
        ),
        const SizedBox(width: 4),
        Padding(
          padding: const EdgeInsets.only(top: 22),
          child: IconButton(
            tooltip: canRemove ? 'Remove option' : 'At least two options required',
            onPressed: canRemove ? onRemove : null,
            icon: Icon(
              Icons.delete_outline_rounded,
              color: canRemove ? FelloColors.danger : FelloColors.inkSoft,
            ),
          ),
        ),
      ],
    );
  }
}

class _TypeStep extends StatelessWidget {
  const _TypeStep({
    required this.types,
    required this.selected,
    required this.onSelect,
  });

  final List<(QuestionType, String, String, IconData)> types;
  final QuestionType? selected;
  final ValueChanged<QuestionType> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final (type, title, subtitle, icon) in types)
          SizedBox(
            width: 220,
            child: Material(
              color: selected == type
                  ? FelloColors.accentSoft
                  : FelloColors.paper,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: () => onSelect(type),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected == type
                          ? FelloColors.accent
                          : FelloColors.border,
                      width: selected == type ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        icon,
                        color: selected == type
                            ? FelloColors.accentDeep
                            : FelloColors.inkSoft,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
