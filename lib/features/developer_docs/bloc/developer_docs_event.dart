part of 'developer_docs_bloc.dart';

abstract class DeveloperDocsEvent extends Equatable {
  const DeveloperDocsEvent();

  @override
  List<Object?> get props => [];
}

class DeveloperDocsLoadRequested extends DeveloperDocsEvent {
  const DeveloperDocsLoadRequested();
}

class DeveloperApiKeyCreateRequested extends DeveloperDocsEvent {
  const DeveloperApiKeyCreateRequested(this.name);

  final String name;

  @override
  List<Object?> get props => [name];
}

class DeveloperApiKeyRevokeRequested extends DeveloperDocsEvent {
  const DeveloperApiKeyRevokeRequested(this.keyId);

  final String keyId;

  @override
  List<Object?> get props => [keyId];
}

class DeveloperApiKeySecretCleared extends DeveloperDocsEvent {
  const DeveloperApiKeySecretCleared();
}
