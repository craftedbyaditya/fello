import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/fello_colors.dart';
import '../../../domain/entities/complaint_task.dart';
import '../../../domain/repositories/workflow_repository.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../bloc/complaints_bloc.dart';

/// AI follow-ups for one survey — lives on the survey reviews page.
class SurveyFollowUpsSection extends StatelessWidget {
  const SurveyFollowUpsSection({
    super.key,
    required this.formId,
    this.highlightTaskId,
  });

  final String formId;
  final String? highlightTaskId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final orgId =
            context.read<AuthBloc>().state.session?.organization.id ?? '';
        return ComplaintsBloc(getIt<WorkflowRepository>())
          ..add(ComplaintsLoadRequested(orgId, formId: formId));
      },
      child: _SurveyFollowUpsBody(
        formId: formId,
        highlightTaskId: highlightTaskId,
      ),
    );
  }
}

class _SurveyFollowUpsBody extends StatefulWidget {
  const _SurveyFollowUpsBody({
    required this.formId,
    this.highlightTaskId,
  });

  final String formId;
  final String? highlightTaskId;

  @override
  State<_SurveyFollowUpsBody> createState() => _SurveyFollowUpsBodyState();
}

class _SurveyFollowUpsBodyState extends State<_SurveyFollowUpsBody> {
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.highlightTaskId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context
            .read<ComplaintsBloc>()
            .add(ComplaintTaskSelected(widget.highlightTaskId));
      });
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ComplaintsBloc, ComplaintsState>(
      builder: (context, state) {
        final selected = state.selectedTask;
        if (selected != null &&
            _notesController.text != selected.resolutionNotes) {
          _notesController.text = selected.resolutionNotes;
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
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
                  const Icon(
                    Icons.auto_awesome,
                    size: 18,
                    color: FelloColors.accentDeep,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'AI follow-ups',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: FelloColors.ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Action items from this survey’s feedback.',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: FelloColors.inkSoft,
                ),
              ),
              const SizedBox(height: 14),
              ..._body(context, state),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _body(BuildContext context, ComplaintsState state) {
    switch (state.status) {
      case ComplaintsStatus.initial:
      case ComplaintsStatus.loading:
        return const [
          SizedBox(
            height: 88,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ];
      case ComplaintsStatus.failure:
        return [
          Text(
            state.errorMessage ?? 'Could not load follow-ups.',
            style: const TextStyle(color: FelloColors.danger),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () {
                final orgId =
                    context.read<AuthBloc>().state.session?.organization.id;
                if (orgId == null) return;
                context.read<ComplaintsBloc>().add(
                      ComplaintsLoadRequested(orgId, formId: widget.formId),
                    );
              },
              child: const Text('Retry'),
            ),
          ),
        ];
      case ComplaintsStatus.ready:
        break;
    }

    final insights = state.insights;
    final open = insights?.openCount ?? 0;
    final resolved = insights?.resolvedCount ?? 0;

    if (state.tasks.isEmpty) {
      return [
        _EmptyState(
          icon: Icons.verified_outlined,
          title: 'No follow-ups for this survey',
          body:
              'When customers leave low ratings or actionable comments, Kaydo will create follow-up tasks here. Positive feedback stays in Reviews.',
        ),
      ];
    }

    if (open == 0 && resolved > 0) {
      return [
        _EmptyState(
          icon: Icons.check_circle_outline,
          title: 'All follow-ups resolved',
          body:
              'Nice work — $resolved ${resolved == 1 ? 'issue is' : 'issues are'} closed for this survey. New actionable feedback will appear here.',
        ),
        const SizedBox(height: 12),
        _TaskList(state: state, notesController: _notesController),
      ];
    }

    return [
      if (insights != null) ...[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Pill('Open · $open'),
            _Pill('Resolved · $resolved'),
            if (insights.risingCategories.isNotEmpty)
              _Pill('Rising · ${insights.risingCategories.first}'),
          ],
        ),
        const SizedBox(height: 12),
      ],
      _FiltersRow(state: state),
      const SizedBox(height: 12),
      _TaskList(state: state, notesController: _notesController),
      if (state.errorMessage != null) ...[
        const SizedBox(height: 8),
        Text(
          state.errorMessage!,
          style: const TextStyle(color: FelloColors.danger),
        ),
      ],
    ];
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: FelloColors.accentSoft.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: FelloColors.accentDeep, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: FelloColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: FelloColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: FelloColors.accentSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: FelloColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: FelloColors.accentDeep,
        ),
      ),
    );
  }
}

class _FiltersRow extends StatelessWidget {
  const _FiltersRow({required this.state});
  final ComplaintsState state;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        DropdownButton<ComplaintTaskStatus?>(
          value: state.filters.status,
          hint: const Text('Status'),
          items: [
            const DropdownMenuItem(value: null, child: Text('All statuses')),
            ...ComplaintTaskStatus.values.map(
              (s) => DropdownMenuItem(value: s, child: Text(s.label)),
            ),
          ],
          onChanged: (v) {
            context.read<ComplaintsBloc>().add(
                  ComplaintsFiltersChanged(
                    state.filters.copyWith(
                      status: v,
                      clearStatus: v == null,
                      formId: state.formId,
                    ),
                  ),
                );
          },
        ),
        DropdownButton<ComplaintPriority?>(
          value: state.filters.priority,
          hint: const Text('Priority'),
          items: [
            const DropdownMenuItem(value: null, child: Text('All priorities')),
            ...ComplaintPriority.values.map(
              (p) => DropdownMenuItem(value: p, child: Text(p.label)),
            ),
          ],
          onChanged: (v) {
            context.read<ComplaintsBloc>().add(
                  ComplaintsFiltersChanged(
                    state.filters.copyWith(
                      priority: v,
                      clearPriority: v == null,
                      formId: state.formId,
                    ),
                  ),
                );
          },
        ),
      ],
    );
  }
}

class _TaskList extends StatelessWidget {
  const _TaskList({
    required this.state,
    required this.notesController,
  });

  final ComplaintsState state;
  final TextEditingController notesController;

  @override
  Widget build(BuildContext context) {
    final selected = state.selectedTask;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final list = ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: state.tasks.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final task = state.tasks[index];
            final active = state.selectedTaskId == task.id;
            return Material(
              color: active ? FelloColors.accentSoft : FelloColors.paper,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => context
                    .read<ComplaintsBloc>()
                    .add(ComplaintTaskSelected(task.id)),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: FelloColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _MiniChip(task.status.label),
                          _MiniChip(task.priority.label),
                          _MiniChip(task.category),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );

        final detail = selected == null
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Select a follow-up to update status and notes.',
                  style: TextStyle(color: FelloColors.inkSoft),
                ),
              )
            : _TaskDetail(task: selected, notesController: notesController);

        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              list,
              const SizedBox(height: 12),
              detail,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: list),
            const SizedBox(width: 12),
            Expanded(flex: 6, child: detail),
          ],
        );
      },
    );
  }
}

class _TaskDetail extends StatelessWidget {
  const _TaskDetail({
    required this.task,
    required this.notesController,
  });

  final ComplaintTask task;
  final TextEditingController notesController;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: FelloColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            task.title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Text(task.description, style: const TextStyle(height: 1.4)),
          const SizedBox(height: 8),
          Text(
            'Assignee: ${task.assigneeName ?? 'Unassigned'}',
            style: const TextStyle(color: FelloColors.inkSoft, fontSize: 13),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ComplaintTaskStatus>(
            // ignore: deprecated_member_use
            value: task.status,
            decoration: const InputDecoration(labelText: 'Status'),
            items: ComplaintTaskStatus.values
                .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                .toList(),
            onChanged: (status) {
              if (status == null) return;
              context.read<ComplaintsBloc>().add(
                    ComplaintTaskUpdateRequested(
                      taskId: task.id,
                      status: status,
                    ),
                  );
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Resolution notes',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: () {
                context.read<ComplaintsBloc>().add(
                      ComplaintTaskUpdateRequested(
                        taskId: task.id,
                        resolutionNotes: notesController.text.trim(),
                      ),
                    );
              },
              child: const Text('Save notes'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: FelloColors.border),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }
}
