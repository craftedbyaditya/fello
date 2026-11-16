import 'package:fello/data/mock/mock_form_repository.dart';
import 'package:fello/data/mock/mock_response_repository.dart';
import 'package:fello/data/mock/mock_store.dart';
import 'package:fello/domain/auth_permission_failure.dart';
import 'package:fello/domain/entities/organization.dart';
import 'package:fello/domain/entities/profile.dart';
import 'package:fello/domain/entities/question.dart';
import 'package:fello/domain/entities/subscription_plan.dart';
import 'package:fello/domain/public_answer_validator.dart';
import 'package:fello/domain/repositories/auth_repository.dart';
import 'package:fello/domain/submit_guard_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockStore store;
  late MockFormRepository forms;
  late MockResponseRepository responses;

  setUp(() {
    store = MockStore();
    forms = MockFormRepository(store);
    responses = MockResponseRepository(store);
  });

  AuthSession adminSession() {
    final org = store.organizations.firstWhere((o) => o.id == 'org_demo');
    final profile = store.profiles.firstWhere((p) => p.id == 'user_demo');
    return AuthSession(profile: profile, organization: org);
  }

  AuthSession employeeSession() {
    final org = store.organizations.firstWhere((o) => o.id == 'org_demo');
    final employee = Profile(
      id: 'user_employee',
      orgId: org.id,
      displayName: 'Em Employee',
      email: 'em@harbor.coffee',
      role: ProfileRole.employee,
    );
    store.profiles.add(employee);
    return AuthSession(profile: employee, organization: org);
  }

  AuthSession otherOrgSession() {
    final other = Organization(
      id: 'org_other',
      name: 'Other Co',
      slug: 'other-co',
      createdAt: DateTime.now(),
      planId: PlanId.free,
    );
    store.organizations.add(other);
    final profile = Profile(
      id: 'user_other',
      orgId: other.id,
      displayName: 'Other Admin',
      email: 'admin@other.co',
      role: ProfileRole.admin,
    );
    store.profiles.add(profile);
    return AuthSession(profile: profile, organization: other);
  }

  group('role permissions', () {
    test('employee cannot delete forms', () async {
      store.setSession(employeeSession());
      await expectLater(
        forms.deleteForm('form_visit'),
        throwsA(isA<AuthPermissionFailure>()),
      );
      expect(store.forms.any((f) => f.id == 'form_visit'), isTrue);
    });

    test('admin can soft-delete forms in their org', () async {
      store.setSession(adminSession());
      final deleted = await forms.deleteForm('form_draft');
      expect(deleted.isDeleted, isTrue);
      expect(store.forms.any((f) => f.id == 'form_draft' && f.isDeleted), isTrue);
    });

    test('employee cannot delete questions', () async {
      store.setSession(employeeSession());
      await expectLater(
        forms.deleteQuestion('q_rating'),
        throwsA(isA<AuthPermissionFailure>()),
      );
    });
  });

  group('cross-org isolation', () {
    test('other org cannot list demo responses', () async {
      store.setSession(otherOrgSession());
      await expectLater(
        responses.listResponses(orgId: 'org_demo'),
        throwsA(isA<AuthPermissionFailure>()),
      );
    });

    test('other org cannot get demo form', () async {
      store.setSession(otherOrgSession());
      final form = await forms.getForm('form_visit');
      expect(form, isNull);
    });

    test('other org cannot delete demo form', () async {
      store.setSession(otherOrgSession());
      await expectLater(
        forms.deleteForm('form_visit'),
        throwsA(isA<AuthPermissionFailure>()),
      );
    });
  });

  group('public submit guards', () {
    Map<String, dynamic> validAnswers() => {
          'q_rating': 5,
          'q_nps': 9,
          'q_choice': 'Coffee',
          'q_text': 'Great',
        };

    test('rejects missing required answers', () {
      final form = store.forms.firstWhere((f) => f.id == 'form_visit');
      final error = PublicAnswerValidator.validate(
        questions: form.questions,
        answers: {'q_choice': 'Coffee'},
      );
      expect(error, isNotNull);
    });

    test('rejects unknown question ids', () {
      final form = store.forms.firstWhere((f) => f.id == 'form_visit');
      final error = PublicAnswerValidator.validate(
        questions: form.questions,
        answers: {
          ...validAnswers(),
          'q_fake': 'nope',
        },
      );
      expect(error, contains('Unknown'));
    });

    test('rejects invalid star rating', () {
      final form = store.forms.firstWhere((f) => f.id == 'form_visit');
      final error = PublicAnswerValidator.validate(
        questions: form.questions,
        answers: {
          ...validAnswers(),
          'q_rating': 99,
        },
      );
      expect(error, contains('Star rating'));
    });

    test('dedupes identical submission ids', () async {
      final form = store.forms.firstWhere((f) => f.id == 'form_visit');
      const sid = '11111111-1111-1111-1111-111111111111';
      await responses.submitResponse(
        formId: form.id,
        answersByQuestionId: validAnswers(),
        clientKey: 'client-a',
        submissionId: sid,
      );
      await expectLater(
        responses.submitResponse(
          formId: form.id,
          answersByQuestionId: validAnswers(),
          clientKey: 'client-a',
          submissionId: sid,
        ),
        throwsA(isA<SubmitGuardFailure>()),
      );
    });

    test('rate limits repeated submissions from same client', () async {
      final form = store.forms.firstWhere((f) => f.id == 'form_visit');
      for (var i = 0; i < 20; i++) {
        await responses.submitResponse(
          formId: form.id,
          answersByQuestionId: validAnswers(),
          clientKey: 'rate-client',
          submissionId: 'sid-$i',
        );
      }
      await expectLater(
        responses.submitResponse(
          formId: form.id,
          answersByQuestionId: validAnswers(),
          clientKey: 'rate-client',
          submissionId: 'sid-overflow',
        ),
        throwsA(
          isA<SubmitGuardFailure>().having(
            (e) => e.message,
            'message',
            contains('Too many'),
          ),
        ),
      );
    });

    test('accepts valid answers', () async {
      final form = store.forms.firstWhere((f) => f.id == 'form_visit');
      final saved = await responses.submitResponse(
        formId: form.id,
        answersByQuestionId: validAnswers(),
        clientKey: 'ok-client',
        submissionId: 'ok-sid-1',
      );
      expect(saved.answers, isNotEmpty);
      expect(
        saved.answers
            .any((a) => a.questionId == 'q_rating' && a.value == 5),
        isTrue,
      );
    });
  });

  group('answer type coverage', () {
    test('yesNo and choice option checks', () {
      final questions = [
        const Question(
          id: 'q1',
          formId: 'f',
          type: QuestionType.yesNo,
          label: 'Ok?',
          required: true,
          sortOrder: 0,
        ),
        const Question(
          id: 'q2',
          formId: 'f',
          type: QuestionType.singleChoice,
          label: 'Pick',
          required: true,
          options: ['A', 'B'],
          sortOrder: 1,
        ),
      ];
      expect(
        PublicAnswerValidator.validate(
          questions: questions,
          answers: {'q1': true, 'q2': 'C'},
        ),
        contains('valid option'),
      );
      expect(
        PublicAnswerValidator.validate(
          questions: questions,
          answers: {'q1': true, 'q2': 'A'},
        ),
        isNull,
      );
    });
  });
}
