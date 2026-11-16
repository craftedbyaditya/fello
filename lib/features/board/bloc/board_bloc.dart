import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/entities/complaint_task.dart';
import '../../../domain/repositories/workflow_repository.dart';

part 'board_event.dart';
part 'board_state.dart';

class BoardBloc extends Bloc<BoardEvent, BoardState> {
  BoardBloc(this._workflow) : super(const BoardState()) {
    on<BoardLoadRequested>(_onLoad);
    on<BoardTaskSelected>(_onSelect);
    on<BoardTaskDeselected>(_onDeselect);
    on<BoardStatusChanged>(_onStatus);
    on<BoardTaskCreateRequested>(_onCreate);
    on<BoardTaskEditRequested>(_onEdit);
    on<BoardCommentsLoadRequested>(_onLoadComments);
    on<BoardCommentAddRequested>(_onAddComment);
  }

  final WorkflowRepository _workflow;
  static const _uuid = Uuid();

  Future<void> _onLoad(
    BoardLoadRequested event,
    Emitter<BoardState> emit,
  ) async {
    emit(state.copyWith(status: BoardStatus.loading, clearError: true));
    try {
      final tasks = await _workflow.listTasks(orgId: event.orgId, limit: 200);
      emit(
        state.copyWith(
          status: BoardStatus.ready,
          orgId: event.orgId,
          tasks: tasks,
          clearError: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: BoardStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  void _onSelect(BoardTaskSelected event, Emitter<BoardState> emit) {
    ComplaintTask? task;
    for (final t in state.tasks) {
      if (t.id == event.taskId) {
        task = t;
        break;
      }
    }
    emit(state.copyWith(selectedTask: task, clearComments: true));
    if (task != null) {
      add(BoardCommentsLoadRequested(task.id));
    }
  }

  void _onDeselect(BoardTaskDeselected event, Emitter<BoardState> emit) {
    emit(state.copyWith(clearSelected: true, clearComments: true));
  }

  Future<void> _onStatus(
    BoardStatusChanged event,
    Emitter<BoardState> emit,
  ) async {
    emit(state.copyWith(busy: true, clearError: true));
    try {
      final updated = await _workflow.updateTask(
        taskId: event.taskId,
        status: event.status,
      );
      final tasks = [
        for (final t in state.tasks)
          if (t.id == updated.id) updated else t,
      ];
      emit(
        state.copyWith(
          busy: false,
          tasks: tasks,
          selectedTask: state.selectedTask?.id == updated.id
              ? updated
              : state.selectedTask,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          busy: false,
          errorMessage: e.toString().replaceFirst(RegExp(r'^[^:]+:\s*'), ''),
        ),
      );
    }
  }

  Future<void> _onCreate(
    BoardTaskCreateRequested event,
    Emitter<BoardState> emit,
  ) async {
    emit(state.copyWith(busy: true, clearError: true));
    try {
      final created = await _workflow.createManualTask(
        title: event.title,
        description: event.description,
      );
      emit(
        state.copyWith(
          busy: false,
          tasks: [created, ...state.tasks],
          infoMessage: 'Task created',
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          busy: false,
          errorMessage: e.toString().replaceFirst(RegExp(r'^[^:]+:\s*'), ''),
        ),
      );
    }
  }

  Future<void> _onEdit(
    BoardTaskEditRequested event,
    Emitter<BoardState> emit,
  ) async {
    emit(state.copyWith(busy: true, clearError: true));
    try {
      final updated = await _workflow.updateTask(
        taskId: event.taskId,
        title: event.title,
        description: event.description,
        status: event.status,
      );
      final tasks = [
        for (final t in state.tasks)
          if (t.id == updated.id) updated else t,
      ];
      emit(
        state.copyWith(
          busy: false,
          tasks: tasks,
          selectedTask: updated,
          infoMessage: 'Task updated',
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          busy: false,
          errorMessage: e.toString().replaceFirst(RegExp(r'^[^:]+:\s*'), ''),
        ),
      );
    }
  }

  Future<void> _onLoadComments(
    BoardCommentsLoadRequested event,
    Emitter<BoardState> emit,
  ) async {
    emit(state.copyWith(commentsStatus: BoardCommentsStatus.loading));
    try {
      final comments = await _workflow.listTaskComments(event.taskId);
      emit(
        state.copyWith(
          commentsStatus: BoardCommentsStatus.ready,
          comments: comments,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          commentsStatus: BoardCommentsStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onAddComment(
    BoardCommentAddRequested event,
    Emitter<BoardState> emit,
  ) async {
    final trimmed = event.body.trim();
    if (trimmed.isEmpty) {
      emit(state.copyWith(errorMessage: 'Comment cannot be empty.'));
      return;
    }
    emit(state.copyWith(busy: true, clearError: true));
    final mutationId = _uuid.v4();
    try {
      final comment = await _workflow.addTaskComment(
        taskId: event.taskId,
        body: trimmed,
        clientMutationId: mutationId,
      );
      final comments = [...state.comments, comment];
      // Dedupe by id
      final seen = <String>{};
      final deduped = <TaskComment>[];
      for (final c in comments) {
        if (seen.add(c.id)) deduped.add(c);
      }
      deduped.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final tasks = [
        for (final t in state.tasks)
          if (t.id == event.taskId)
            t.copyWith(commentCount: deduped.length)
          else
            t,
      ];
      emit(
        state.copyWith(
          busy: false,
          comments: deduped,
          commentsStatus: BoardCommentsStatus.ready,
          tasks: tasks,
          selectedTask: state.selectedTask?.id == event.taskId
              ? state.selectedTask!.copyWith(commentCount: deduped.length)
              : state.selectedTask,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          busy: false,
          errorMessage: e.toString().replaceFirst(RegExp(r'^[^:]+:\s*'), ''),
        ),
      );
    }
  }
}
