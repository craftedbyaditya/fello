import 'package:fello/data/mock/mock_store.dart';
import 'package:fello/data/mock/mock_workflow_repository.dart';
import 'package:fello/domain/auth_permission_failure.dart';
import 'package:fello/domain/entities/complaint_task.dart';
import 'package:fello/domain/entities/feedback_form.dart';
import 'package:fello/domain/entities/organization.dart';
import 'package:fello/domain/entities/profile.dart';
import 'package:fello/domain/entities/question.dart';
import 'package:fello/domain/entities/response.dart';
import 'package:fello/domain/entities/subscription_plan.dart';
import 'package:fello/domain/repositories/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockStore store;
  late MockWorkflowRepository workflow;
  late Organization org;
  late Profile admin;

  setUp(() {
    store = MockStore();
    workflow = MockWorkflowRepository(store);
    org = store.organizations.first;
    admin = store.profiles.firstWhere((p) => p.orgId == org.id && p.isAdmin);
    store.setSession(AuthSession(profile: admin, organization: org));
  });

  test('manual task creates in Backlog with creator attribution', () async {
    final task = await workflow.createManualTask(
      title: 'Call kitchen about wait times',
      description: 'Follow up with shift lead.',
    );
    expect(task.status, ComplaintTaskStatus.open);
    expect(task.boardColumn, BoardColumn.backlog);
    expect(task.source, ComplaintTaskSource.manual);
    expect(task.createdBy, admin.id);
    expect(task.displayCreator, admin.displayName);
    expect(task.responseId, isNull);
  });

  test('AI complaint task appears in Backlog as Kaydo AI', () async {
    final form = FeedbackForm(
      id: 'form-board-ai',
      orgId: org.id,
      title: 'Board AI',
      description: '',
      slug: 'board-ai',
      status: FormStatus.published,
      createdAt: DateTime.now().toUtc(),
      questions: [
        Question(
          id: 'q-s',
          formId: 'form-board-ai',
          type: QuestionType.starRating,
          label: 'Rating',
          required: true,
          sortOrder: 0,
        ),
        Question(
          id: 'q-t',
          formId: 'form-board-ai',
          type: QuestionType.longText,
          label: 'Comments',
          required: false,
          sortOrder: 1,
        ),
      ],
    );
    store.forms.add(form);
    const responseId = 'resp-board-ai';
    store.responses.add(
      FeedbackResponse(
        id: responseId,
        formId: form.id,
        submittedAt: DateTime.now().toUtc(),
        answers: const [
          Answer(
            id: 'a1',
            responseId: responseId,
            questionId: 'q-s',
            value: 2.0,
          ),
          Answer(
            id: 'a2',
            responseId: responseId,
            questionId: 'q-t',
            value: 'The staff was helpful, but I waited 40 minutes.',
          ),
        ],
      ),
    );

    await workflow.processResponseLocally(responseId);
    final task = await workflow.getTaskForResponse(responseId);
    expect(task, isNotNull);
    expect(task!.boardColumn, BoardColumn.backlog);
    expect(task.displayCreator, 'Kaydo AI');
    expect(task.source, ComplaintTaskSource.ai);

    // Idempotent reprocess does not duplicate
    await workflow.processResponseLocally(responseId);
    expect(
      store.complaintTasks.where((t) => t.responseId == responseId).length,
      1,
    );
  });

  test('existing complaint tasks appear on board columns', () async {
    final now = DateTime.now().toUtc();
    store.complaintTasks.addAll([
      ComplaintTask(
        id: 't-open',
        orgId: org.id,
        title: 'Open',
        description: '',
        category: 'General',
        priority: ComplaintPriority.medium,
        status: ComplaintTaskStatus.open,
        createdAt: now,
        updatedAt: now,
        source: ComplaintTaskSource.manual,
        createdBy: admin.id,
        creatorName: admin.displayName,
      ),
      ComplaintTask(
        id: 't-prog',
        orgId: org.id,
        title: 'Prog',
        description: '',
        category: 'General',
        priority: ComplaintPriority.medium,
        status: ComplaintTaskStatus.inProgress,
        createdAt: now,
        updatedAt: now,
        source: ComplaintTaskSource.manual,
        createdBy: admin.id,
        creatorName: admin.displayName,
      ),
      ComplaintTask(
        id: 't-done',
        orgId: org.id,
        title: 'Done',
        description: '',
        category: 'General',
        priority: ComplaintPriority.medium,
        status: ComplaintTaskStatus.resolved,
        createdAt: now,
        updatedAt: now,
        source: ComplaintTaskSource.manual,
        createdBy: admin.id,
        creatorName: admin.displayName,
      ),
      ComplaintTask(
        id: 't-closed',
        orgId: org.id,
        title: 'Closed',
        description: '',
        category: 'General',
        priority: ComplaintPriority.medium,
        status: ComplaintTaskStatus.closed,
        createdAt: now,
        updatedAt: now,
        source: ComplaintTaskSource.ai,
      ),
    ]);

    final tasks = await workflow.listTasks(orgId: org.id);
    expect(
      tasks.where((t) => t.boardColumn == BoardColumn.backlog).length,
      greaterThanOrEqualTo(1),
    );
    expect(
      tasks.where((t) => t.boardColumn == BoardColumn.inProgress).length,
      greaterThanOrEqualTo(1),
    );
    expect(
      tasks.where((t) => t.boardColumn == BoardColumn.done).length,
      greaterThanOrEqualTo(2),
    );
  });

  test('status moves backlog → in progress → done → backlog', () async {
    final created = await workflow.createManualTask(
      title: 'Move me',
      description: 'x',
    );
    var t = await workflow.updateTask(
      taskId: created.id,
      status: ComplaintTaskStatus.inProgress,
    );
    expect(t.boardColumn, BoardColumn.inProgress);
    t = await workflow.updateTask(
      taskId: created.id,
      status: ComplaintTaskStatus.resolved,
    );
    expect(t.boardColumn, BoardColumn.done);
    t = await workflow.updateTask(
      taskId: created.id,
      status: ComplaintTaskStatus.open,
    );
    expect(t.boardColumn, BoardColumn.backlog);
  });

  test('task detail load and edit title', () async {
    final created = await workflow.createManualTask(
      title: 'Detail',
      description: 'Full text here',
    );
    final loaded = await workflow.getTask(created.id);
    expect(loaded, isNotNull);
    expect(loaded!.description, 'Full text here');
    final updated = await workflow.updateTask(
      taskId: created.id,
      title: 'Detail updated',
      description: 'Changed',
    );
    expect(updated.title, 'Detail updated');
    expect(updated.description, 'Changed');
  });

  test('comments create, order, reject empty, dedupe mutation', () async {
    final task = await workflow.createManualTask(title: 'C', description: '');
    expect(
      () => workflow.addTaskComment(taskId: task.id, body: '   '),
      throwsA(isA<StateError>()),
    );

    final a = await workflow.addTaskComment(
      taskId: task.id,
      body: 'First',
      clientMutationId: 'm1',
    );
    await Future<void>.delayed(const Duration(milliseconds: 2));
    final b = await workflow.addTaskComment(taskId: task.id, body: 'Second');
    final again = await workflow.addTaskComment(
      taskId: task.id,
      body: 'First again ignored',
      clientMutationId: 'm1',
    );
    expect(again.id, a.id);

    final list = await workflow.listTaskComments(task.id);
    expect(list.length, 2);
    expect(list.first.body, 'First');
    expect(list.last.body, 'Second');
    expect(b.authorId, admin.id);
  });

  test('cross-org task and comment isolation', () async {
    final task = await workflow.createManualTask(
      title: 'Mine',
      description: '',
    );
    await workflow.addTaskComment(taskId: task.id, body: 'Secret');

    final otherOrg = Organization(
      id: 'other-board-org',
      name: 'Other',
      slug: 'other-board',
      createdAt: DateTime.now().toUtc(),
      planId: PlanId.growth,
    );
    final other = Profile(
      id: 'other-board-user',
      orgId: otherOrg.id,
      displayName: 'Other',
      email: 'other-board@example.com',
      role: ProfileRole.admin,
    );
    store.organizations.add(otherOrg);
    store.profiles.add(other);
    store.setSession(AuthSession(profile: other, organization: otherOrg));

    expect(
      () => workflow.listTasks(orgId: org.id),
      throwsA(isA<AuthPermissionFailure>()),
    );
    expect(await workflow.getTask(task.id), isNull);
  });

  test('unauthorized cross-org update blocked', () async {
    final task = await workflow.createManualTask(title: 'X', description: '');
    final otherOrg = Organization(
      id: 'other2',
      name: 'Other2',
      slug: 'other2',
      createdAt: DateTime.now().toUtc(),
    );
    final other = Profile(
      id: 'u2',
      orgId: otherOrg.id,
      displayName: 'U2',
      email: 'u2@example.com',
      role: ProfileRole.admin,
    );
    store.organizations.add(otherOrg);
    store.profiles.add(other);
    store.setSession(AuthSession(profile: other, organization: otherOrg));

    expect(
      () => workflow.updateTask(
        taskId: task.id,
        status: ComplaintTaskStatus.inProgress,
      ),
      throwsA(isA<AuthPermissionFailure>()),
    );
  });
}
