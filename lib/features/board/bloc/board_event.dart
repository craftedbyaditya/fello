part of 'board_bloc.dart';

abstract class BoardEvent extends Equatable {
  const BoardEvent();

  @override
  List<Object?> get props => [];
}

class BoardLoadRequested extends BoardEvent {
  const BoardLoadRequested(this.orgId);
  final String orgId;

  @override
  List<Object?> get props => [orgId];
}

class BoardTaskSelected extends BoardEvent {
  const BoardTaskSelected(this.taskId);
  final String taskId;

  @override
  List<Object?> get props => [taskId];
}

class BoardTaskDeselected extends BoardEvent {
  const BoardTaskDeselected();
}

class BoardStatusChanged extends BoardEvent {
  const BoardStatusChanged({required this.taskId, required this.status});
  final String taskId;
  final ComplaintTaskStatus status;

  @override
  List<Object?> get props => [taskId, status];
}

class BoardTaskCreateRequested extends BoardEvent {
  const BoardTaskCreateRequested({
    required this.title,
    required this.description,
  });
  final String title;
  final String description;

  @override
  List<Object?> get props => [title, description];
}

class BoardTaskEditRequested extends BoardEvent {
  const BoardTaskEditRequested({
    required this.taskId,
    this.title,
    this.description,
    this.status,
  });
  final String taskId;
  final String? title;
  final String? description;
  final ComplaintTaskStatus? status;

  @override
  List<Object?> get props => [taskId, title, description, status];
}

class BoardCommentsLoadRequested extends BoardEvent {
  const BoardCommentsLoadRequested(this.taskId);
  final String taskId;

  @override
  List<Object?> get props => [taskId];
}

class BoardCommentAddRequested extends BoardEvent {
  const BoardCommentAddRequested({required this.taskId, required this.body});
  final String taskId;
  final String body;

  @override
  List<Object?> get props => [taskId, body];
}
