part of 'developer_docs_bloc.dart';

enum DeveloperDocsStatus { initial, loading, ready, planLocked, failure }

class DeveloperDocsState extends Equatable {
  const DeveloperDocsState({
    this.status = DeveloperDocsStatus.initial,
    this.keys = const [],
    this.busy = false,
    this.newlyCreatedSecret,
    this.errorMessage,
    this.infoMessage,
  });

  final DeveloperDocsStatus status;
  final List<OrgApiKey> keys;
  final bool busy;
  final String? newlyCreatedSecret;
  final String? errorMessage;
  final String? infoMessage;

  DeveloperDocsState copyWith({
    DeveloperDocsStatus? status,
    List<OrgApiKey>? keys,
    bool? busy,
    String? newlyCreatedSecret,
    String? errorMessage,
    String? infoMessage,
    bool clearSecret = false,
    bool clearError = false,
    bool clearInfo = false,
  }) {
    return DeveloperDocsState(
      status: status ?? this.status,
      keys: keys ?? this.keys,
      busy: busy ?? this.busy,
      newlyCreatedSecret: clearSecret
          ? null
          : (newlyCreatedSecret ?? this.newlyCreatedSecret),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      infoMessage: clearInfo ? null : (infoMessage ?? this.infoMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        keys,
        busy,
        newlyCreatedSecret,
        errorMessage,
        infoMessage,
      ];
}
