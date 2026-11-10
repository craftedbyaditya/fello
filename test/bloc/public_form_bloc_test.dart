import 'package:bloc_test/bloc_test.dart';
import 'package:fello/data/mock/mock_form_repository.dart';
import 'package:fello/data/mock/mock_response_repository.dart';
import 'package:fello/data/mock/mock_store.dart';
import 'package:fello/features/public_form/bloc/public_form_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockStore store;
  late PublicFormBloc bloc;

  setUp(() {
    store = MockStore();
    bloc = PublicFormBloc(
      formRepository: MockFormRepository(store),
      responseRepository: MockResponseRepository(store),
    );
  });

  tearDown(() async {
    await bloc.close();
  });

  blocTest<PublicFormBloc, PublicFormState>(
    'loads published form by slug',
    build: () => bloc,
    act: (b) => b.add(const PublicFormLoadRequested('harbor-visit')),
    wait: const Duration(milliseconds: 400),
    expect: () => [
      isA<PublicFormState>()
          .having((s) => s.status, 'status', PublicFormStatus.loading),
      isA<PublicFormState>()
          .having((s) => s.status, 'status', PublicFormStatus.ready)
          .having((s) => s.form?.slug, 'slug', 'harbor-visit'),
    ],
  );

  blocTest<PublicFormBloc, PublicFormState>(
    'unknown slug is notFound',
    build: () => PublicFormBloc(
      formRepository: MockFormRepository(store),
      responseRepository: MockResponseRepository(store),
    ),
    act: (b) => b.add(const PublicFormLoadRequested('missing')),
    wait: const Duration(milliseconds: 400),
    expect: () => [
      isA<PublicFormState>()
          .having((s) => s.status, 'status', PublicFormStatus.loading),
      isA<PublicFormState>()
          .having((s) => s.status, 'status', PublicFormStatus.notFound),
    ],
  );
}
