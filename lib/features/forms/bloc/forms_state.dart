part of 'forms_bloc.dart';

enum FormsStatus { initial, loading, saving, ready, failure }

class FormsState extends Equatable {
  const FormsState({
    this.status = FormsStatus.initial,
    this.forms = const [],
    this.selected,
    this.orgId,
    this.errorMessage,
    this.justPublished = false,
  });

  final FormsStatus status;
  final List<FeedbackForm> forms;
  final FeedbackForm? selected;
  final String? orgId;
  final String? errorMessage;
  final bool justPublished;

  FormsState copyWith({
    FormsStatus? status,
    List<FeedbackForm>? forms,
    FeedbackForm? selected,
    String? orgId,
    String? errorMessage,
    bool? justPublished,
    bool clearError = false,
    bool clearSelected = false,
  }) {
    return FormsState(
      status: status ?? this.status,
      forms: forms ?? this.forms,
      selected: clearSelected ? null : (selected ?? this.selected),
      orgId: orgId ?? this.orgId,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      justPublished: justPublished ?? false,
    );
  }

  @override
  List<Object?> get props =>
      [status, forms, selected, orgId, errorMessage, justPublished];
}
