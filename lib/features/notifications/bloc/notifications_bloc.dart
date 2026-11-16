import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/app_notification.dart';
import '../../../domain/repositories/workflow_repository.dart';

part 'notifications_event.dart';
part 'notifications_state.dart';

class NotificationsBloc extends Bloc<NotificationsEvent, NotificationsState> {
  NotificationsBloc(this._workflow) : super(const NotificationsState()) {
    on<NotificationsLoadRequested>(_onLoad);
    on<NotificationMarkReadRequested>(_onMarkRead);
    on<NotificationsMarkAllReadRequested>(_onMarkAll);
  }

  final WorkflowRepository _workflow;

  Future<void> _onLoad(
    NotificationsLoadRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    try {
      final items = await _workflow.listNotifications();
      final unread = await _workflow.unreadNotificationCount();
      emit(
        state.copyWith(
          status: NotificationsStatus.ready,
          items: items,
          unreadCount: unread,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: NotificationsStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onMarkRead(
    NotificationMarkReadRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    await _workflow.markNotificationRead(event.id);
    add(const NotificationsLoadRequested());
  }

  Future<void> _onMarkAll(
    NotificationsMarkAllReadRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    await _workflow.markAllNotificationsRead();
    add(const NotificationsLoadRequested());
  }
}
