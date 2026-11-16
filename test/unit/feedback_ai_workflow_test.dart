import 'package:fello/data/mock/mock_store.dart';
import 'package:fello/data/mock/mock_workflow_repository.dart';
import 'package:fello/domain/ai/feedback_ai_heuristic.dart';
import 'package:fello/domain/auth_permission_failure.dart';
import 'package:fello/domain/entities/complaint_task.dart';
import 'package:fello/domain/entities/feedback_analysis.dart';
import 'package:fello/domain/entities/feedback_form.dart';
import 'package:fello/domain/entities/organization.dart';
import 'package:fello/domain/entities/profile.dart';
import 'package:fello/domain/entities/question.dart';
import 'package:fello/domain/entities/response.dart';
import 'package:fello/domain/repositories/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FeedbackAiHeuristic', () {
    const ai = FeedbackAiHeuristic();

    test('positive feedback', () {
      final r = ai.analyze(
        responseId: 'r1',
        orgId: 'o1',
        text: 'Great service, friendly staff!',
        rating: 5,
      );
      expect(r.analysis.sentiment, FeedbackSentiment.positive);
      expect(r.shouldCreateTask, isFalse);
    });

    test('negative waiting time feedback', () {
      final r = ai.analyze(
        responseId: 'r2',
        orgId: 'o1',
        text: 'The staff was helpful, but I waited 40 minutes.',
        rating: 2,
      );
      expect(r.analysis.sentiment, FeedbackSentiment.mixed);
      expect(r.analysis.categories, contains('Waiting Time'));
      expect(r.shouldCreateTask, isTrue);
      expect(r.analysis.primaryCategory, 'Waiting Time');
    });

    test('mixed sentiment with multiple categories', () {
      final r = ai.analyze(
        responseId: 'r3',
        orgId: 'o1',
        text: 'Food quality was good but staff was rude and slow.',
        rating: 3,
      );
      expect(r.analysis.sentiment, FeedbackSentiment.mixed);
      expect(r.analysis.categories.length, greaterThanOrEqualTo(2));
      expect(r.shouldCreateTask, isTrue);
    });
  });

  group('MockWorkflowRepository', () {
    late MockStore store;
    late MockWorkflowRepository workflow;
    late Organization org;
    late Profile admin;
    late FeedbackForm form;

    setUp(() {
      store = MockStore();
      org = store.organizations.first;
      admin = store.profiles.firstWhere((p) => p.orgId == org.id && p.isAdmin);
      store.setSession(AuthSession(profile: admin, organization: org));
      form = FeedbackForm(
        id: 'form-ai-1',
        orgId: org.id,
        title: 'AI test',
        description: '',
        slug: 'ai-test',
        status: FormStatus.published,
        createdAt: DateTime.now().toUtc(),
        questions: [
          Question(
            id: 'q-stars',
            formId: 'form-ai-1',
            type: QuestionType.starRating,
            label: 'Rating',
            required: true,
            sortOrder: 0,
          ),
          Question(
            id: 'q-text',
            formId: 'form-ai-1',
            type: QuestionType.longText,
            label: 'Comments',
            required: false,
            sortOrder: 1,
          ),
        ],
      );
      store.forms.add(form);
      workflow = MockWorkflowRepository(store);
    });

    Future<String> addResponse({
      required double stars,
      required String text,
      String id = 'resp-1',
    }) async {
      store.responses.add(
        FeedbackResponse(
          id: id,
          formId: form.id,
          submittedAt: DateTime.now().toUtc(),
          answers: [
            Answer(
              id: 'a1',
              responseId: id,
              questionId: 'q-stars',
              value: stars,
            ),
            Answer(
              id: 'a2',
              responseId: id,
              questionId: 'q-text',
              value: text,
            ),
          ],
        ),
      );
      await workflow.processResponseLocally(id);
      return id;
    }

    test('creates task and notification for negative feedback', () async {
      await addResponse(
        stars: 2,
        text: 'The staff was helpful, but I waited 40 minutes.',
      );
      final analysis = await workflow.getAnalysisForResponse('resp-1');
      expect(analysis, isNotNull);
      expect(analysis!.primaryCategory, 'Waiting Time');

      final task = await workflow.getTaskForResponse('resp-1');
      expect(task, isNotNull);
      expect(task!.assignedTo, admin.id);
      expect(task.status, ComplaintTaskStatus.open);

      final notifications = await workflow.listNotifications();
      expect(notifications, isNotEmpty);
      expect(notifications.first.taskId, task.id);
    });

    test('duplicate processing does not create second task', () async {
      await addResponse(
        stars: 1,
        text: 'Terrible wait time and dirty floors.',
      );
      await workflow.processResponseLocally('resp-1');
      expect(
        store.complaintTasks.where((t) => t.responseId == 'resp-1').length,
        1,
      );
      expect(
        store.analyses.where((a) => a.responseId == 'resp-1').length,
        1,
      );
    });

    test('manager assignment and status update', () async {
      await addResponse(stars: 2, text: 'Slow service and long wait.');
      final task = await workflow.getTaskForResponse('resp-1');
      final updated = await workflow.updateTask(
        taskId: task!.id,
        status: ComplaintTaskStatus.inProgress,
        resolutionNotes: 'Spoke with floor manager.',
      );
      expect(updated.status, ComplaintTaskStatus.inProgress);
      expect(updated.resolutionNotes, contains('floor manager'));
    });

    test('cross-org isolation', () async {
      await addResponse(stars: 1, text: 'Waited forever.');
      final otherOrg = Organization(
        id: 'other-org',
        name: 'Other',
        slug: 'other',
        createdAt: DateTime.now().toUtc(),
      );
      final otherProfile = Profile(
        id: 'other-user',
        orgId: otherOrg.id,
        displayName: 'Other Admin',
        email: 'other@example.com',
        role: ProfileRole.admin,
      );
      store.organizations.add(otherOrg);
      store.profiles.add(otherProfile);
      store.setSession(
        AuthSession(profile: otherProfile, organization: otherOrg),
      );

      expect(
        () => workflow.listTasks(orgId: org.id),
        throwsA(isA<AuthPermissionFailure>()),
      );
    });

    test('positive feedback skips task creation', () async {
      await addResponse(
        id: 'resp-pos',
        stars: 5,
        text: 'Excellent experience, great staff!',
      );
      expect(await workflow.getAnalysisForResponse('resp-pos'), isNotNull);
      expect(await workflow.getTaskForResponse('resp-pos'), isNull);
    });

    test('public survey submission path remains independent of AI key', () async {
      // Heuristic mock never requires AI_API_KEY; processing is best-effort.
      await addResponse(stars: 4, text: 'Okay visit.');
      expect(store.responses.any((r) => r.id == 'resp-1'), isTrue);
    });
  });
}
