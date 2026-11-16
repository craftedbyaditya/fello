part of 'board_bloc.dart';

enum BoardStatus { initial, loading, ready, failure }

enum BoardCommentsStatus { initial, loading, ready, failure }

class BoardState extends Equatable {
  const BoardState({
    this.status = BoardStatus.initial,
    this.orgId,
    this.tasks = const [],
    this.selectedTask,
    this.comments = const [],
    this.commentsStatus = BoardCommentsStatus.initial,
    this.busy = false,
    this.errorMessage,
    this.infoMessage,
  });

  final BoardStatus status;
  final String? orgId;
  final List<ComplaintTask> tasks;
  final ComplaintTask? selectedTask;
  final List<TaskComment> comments;
  final BoardCommentsStatus commentsStatus;
  final bool busy;
  final String? errorMessage;
  final String? infoMessage;

  List<ComplaintTask> tasksFor(BoardColumn column) =>
      tasks.where((t) => t.boardColumn == column).toList();

  BoardState copyWith({
    BoardStatus? status,
    String? orgId,
    List<ComplaintTask>? tasks,
    ComplaintTask? selectedTask,
    List<TaskComment>? comments,
    BoardCommentsStatus? commentsStatus,
    bool? busy,
    String? errorMessage,
    String? infoMessage,
    bool clearSelected = false,
    bool clearComments = false,
    bool clearError = false,
    bool clearInfo = false,
  }) {
    return BoardState(
      status: status ?? this.status,
      orgId: orgId ?? this.orgId,
      tasks: tasks ?? this.tasks,
      selectedTask:
          clearSelected ? null : (selectedTask ?? this.selectedTask),
      comments: clearComments ? const [] : (comments ?? this.comments),
      commentsStatus: commentsStatus ?? this.commentsStatus,
      busy: busy ?? this.busy,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      infoMessage: clearInfo ? null : (infoMessage ?? this.infoMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        orgId,
        tasks,
        selectedTask,
        comments,
        commentsStatus,
        busy,
        errorMessage,
        infoMessage,
      ];
}
