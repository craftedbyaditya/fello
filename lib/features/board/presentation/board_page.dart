import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/fello_colors.dart';
import '../../../core/theme/fello_metrics.dart';
import '../../../domain/entities/complaint_task.dart';
import '../../../domain/repositories/workflow_repository.dart';
import '../../../shared/widgets/fello_text_field.dart';
import '../../../shared/widgets/kaydo_toast.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../bloc/board_bloc.dart';

class BoardPage extends StatelessWidget {
  const BoardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthBloc>().state.session;
    if (session == null) {
      return const Center(child: Text('Sign in required.'));
    }

    return BlocProvider(
      create: (_) =>
          BoardBloc(getIt<WorkflowRepository>())
            ..add(BoardLoadRequested(session.organization.id)),
      child: const _BoardView(),
    );
  }
}

class _BoardView extends StatelessWidget {
  const _BoardView();

  @override
  Widget build(BuildContext context) {
    return BlocListener<BoardBloc, BoardState>(
      listenWhen: (p, c) =>
          p.errorMessage != c.errorMessage || p.infoMessage != c.infoMessage,
      listener: (context, state) {
        if (state.errorMessage != null) {
          showKaydoToast(
            context,
            message: state.errorMessage!,
            tone: KaydoToastTone.error,
          );
        } else if (state.infoMessage != null) {
          showKaydoToast(
            context,
            message: state.infoMessage!,
            tone: KaydoToastTone.success,
          );
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 960;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Board',
                              style: Theme.of(context).textTheme.headlineLarge,
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: () => _showCreateDialog(context),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('New task'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: BlocBuilder<BoardBloc, BoardState>(
                          builder: (context, state) {
                            if (state.status == BoardStatus.loading &&
                                state.tasks.isEmpty) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            if (state.status == BoardStatus.failure &&
                                state.tasks.isEmpty) {
                              return Center(
                                child: Text(
                                  state.errorMessage ?? 'Could not load board.',
                                ),
                              );
                            }
                            return _BoardColumns(wide: wide);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (wide)
                BlocBuilder<BoardBloc, BoardState>(
                  buildWhen: (p, c) => p.selectedTask != c.selectedTask,
                  builder: (context, state) {
                    if (state.selectedTask == null) {
                      return const SizedBox.shrink();
                    }
                    return const SizedBox(
                      width: 380,
                      child: _TaskDetailPanel(),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context) async {
    final title = TextEditingController();
    final desc = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New task'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FelloTextField(controller: title, label: 'Title'),
              const SizedBox(height: 12),
              FelloTextField(
                controller: desc,
                label: 'Description',
                maxLines: 4,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      context.read<BoardBloc>().add(
        BoardTaskCreateRequested(title: title.text, description: desc.text),
      );
    }
    title.dispose();
    desc.dispose();
  }
}

class _BoardColumns extends StatelessWidget {
  const _BoardColumns({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    final columns = BoardColumn.values;
    if (!wide) {
      return ListView(
        children: [
          for (final col in columns) ...[
            SizedBox(height: 320, child: _ColumnPane(column: col)),
            const SizedBox(height: 12),
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < columns.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: _ColumnPane(column: columns[i])),
        ],
      ],
    );
  }
}

class _ColumnPane extends StatelessWidget {
  const _ColumnPane({required this.column});

  final BoardColumn column;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BoardBloc, BoardState>(
      builder: (context, state) {
        final tasks = state.tasksFor(column);
        return DragTarget<ComplaintTask>(
          onWillAcceptWithDetails: (d) => d.data.boardColumn != column,
          onAcceptWithDetails: (d) {
            context.read<BoardBloc>().add(
              BoardStatusChanged(
                taskId: d.data.id,
                status: ComplaintTaskStatusX.fromBoardColumn(column),
              ),
            );
          },
          builder: (context, candidate, rejected) {
            final highlight = candidate.isNotEmpty;
            return Container(
              decoration: BoxDecoration(
                color: highlight
                    ? FelloColors.accentSoft.withValues(alpha: 0.45)
                    : const Color(0xFFF7F8F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: FelloColors.border),
              ),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        column.label,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: FelloColors.paper,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: FelloColors.border),
                        ),
                        child: Text(
                          '${tasks.length}',
                          style: const TextStyle(fontSize: 11.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: tasks.isEmpty
                        ? const Center(
                            child: Text(
                              'No tasks',
                              style: TextStyle(color: FelloColors.inkSoft),
                            ),
                          )
                        : ListView.separated(
                            itemCount: tasks.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              return _TaskCard(task: tasks[index]);
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _StatusMenu extends StatelessWidget {
  const _StatusMenu({required this.task});

  final ComplaintTask task;

  @override
  Widget build(BuildContext context) {
    final current = task.status == ComplaintTaskStatus.closed
        ? ComplaintTaskStatus.resolved
        : task.status;
    return PopupMenuButton<ComplaintTaskStatus>(
      tooltip: 'Change status',
      initialValue: current,
      onSelected: (status) {
        context.read<BoardBloc>().add(
          BoardStatusChanged(taskId: task.id, status: status),
        );
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: ComplaintTaskStatus.open, child: Text('Backlog')),
        PopupMenuItem(
          value: ComplaintTaskStatus.inProgress,
          child: Text('In Progress'),
        ),
        PopupMenuItem(value: ComplaintTaskStatus.resolved, child: Text('Done')),
      ],
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: FelloColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                current.label,
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task});

  final ComplaintTask task;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat.MMMd().format(task.createdAt.toLocal());
    final wide = MediaQuery.sizeOf(context).width >= 960;

    final card = Material(
      color: FelloColors.paper,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          context.read<BoardBloc>().add(BoardTaskSelected(task.id));
          if (!wide) {
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (_) => BlocProvider.value(
                value: context.read<BoardBloc>(),
                child: const SizedBox(height: 520, child: _TaskDetailPanel()),
              ),
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: FelloColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
              if (task.descriptionPreview.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  task.descriptionPreview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: FelloColors.inkSoft,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$date · ${task.displayCreator}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: FelloColors.inkSoft,
                      ),
                    ),
                  ),
                  if (task.commentCount > 0) ...[
                    const Icon(
                      Icons.chat_bubble_outline,
                      size: 13,
                      color: FelloColors.inkSoft,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${task.commentCount}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: FelloColors.inkSoft,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              _StatusMenu(task: task),
            ],
          ),
        ),
      ),
    );

    return LongPressDraggable<ComplaintTask>(
      data: task,
      feedback: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(width: 240, child: Opacity(opacity: 0.92, child: card)),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: card,
    );
  }
}

class _TaskDetailPanel extends StatefulWidget {
  const _TaskDetailPanel();

  @override
  State<_TaskDetailPanel> createState() => _TaskDetailPanelState();
}

class _TaskDetailPanelState extends State<_TaskDetailPanel> {
  final _commentController = TextEditingController();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String? _boundTaskId;

  @override
  void dispose() {
    _commentController.dispose();
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _bind(ComplaintTask task) {
    if (_boundTaskId == task.id) return;
    _boundTaskId = task.id;
    _titleController.text = task.title;
    _descController.text = task.description;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BoardBloc, BoardState>(
      builder: (context, state) {
        final task = state.selectedTask;
        if (task == null) {
          return const SizedBox.shrink();
        }
        _bind(task);
        final date = DateFormat.yMMMd().add_jm().format(
          task.createdAt.toLocal(),
        );

        return Container(
          decoration: const BoxDecoration(
            color: FelloColors.paper,
            border: Border(left: BorderSide(color: FelloColors.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Task',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => context.read<BoardBloc>().add(
                        const BoardTaskDeselected(),
                      ),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    FelloTextField(
                      controller: _titleController,
                      label: 'Title',
                    ),
                    const SizedBox(height: 10),
                    FelloTextField(
                      controller: _descController,
                      label: 'Description',
                      maxLines: 5,
                    ),
                    const SizedBox(height: 12),
                    Text('Status', style: _labelStyle),
                    const SizedBox(height: 6),
                    _StatusMenu(task: task),
                    const SizedBox(height: 14),
                    Text('Created by', style: _labelStyle),
                    Text(task.displayCreator),
                    const SizedBox(height: 8),
                    Text('Created at', style: _labelStyle),
                    Text(date),
                    const SizedBox(height: 8),
                    Text('Source', style: _labelStyle),
                    Text(task.source.label),
                    if (task.responseId != null) ...[
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: () {
                          // Prefer survey reviews deep-link when form known via payload later.
                          context.go('/dashboard');
                        },
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Open dashboard for feedback'),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton(
                        onPressed: state.busy
                            ? null
                            : () {
                                context.read<BoardBloc>().add(
                                  BoardTaskEditRequested(
                                    taskId: task.id,
                                    title: _titleController.text,
                                    description: _descController.text,
                                  ),
                                );
                              },
                        child: const Text('Save'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Comments',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    if (state.commentsStatus == BoardCommentsStatus.loading)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (state.comments.isEmpty)
                      const Text(
                        'No comments yet.',
                        style: TextStyle(color: FelloColors.inkSoft),
                      )
                    else
                      for (final c in state.comments) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            border: Border.all(color: FelloColors.border),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${c.authorName} · ${DateFormat.MMMd().add_jm().format(c.createdAt.toLocal())}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: FelloColors.inkSoft,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(c.body),
                            ],
                          ),
                        ),
                      ],
                    const SizedBox(height: 8),
                    FelloTextField(
                      controller: _commentController,
                      label: 'Add a comment',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton(
                        onPressed: state.busy
                            ? null
                            : () {
                                context.read<BoardBloc>().add(
                                  BoardCommentAddRequested(
                                    taskId: task.id,
                                    body: _commentController.text,
                                  ),
                                );
                                _commentController.clear();
                              },
                        style: FilledButton.styleFrom(
                          minimumSize: FelloMetrics.controlMinSize,
                        ),
                        child: const Text('Post comment'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static const _labelStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: FelloColors.inkSoft,
  );
}
