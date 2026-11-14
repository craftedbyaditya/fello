import 'package:uuid/uuid.dart';

import '../../domain/auth_permission_failure.dart';
import '../../domain/entities/feedback_form.dart';
import '../../domain/entities/organization.dart';
import '../../domain/entities/question.dart';
import '../../domain/plan_limit_failure.dart';
import '../../domain/repositories/form_repository.dart';
import 'mock_store.dart';

class MockFormRepository implements FormRepository {
  MockFormRepository(this._store);

  final MockStore _store;
  static const _uuid = Uuid();

  @override
  Future<List<FeedbackForm>> listForms(String orgId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final list =
        _store.forms.where((f) => f.orgId == orgId).toList(growable: false);
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<FeedbackForm?> getForm(String formId) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    try {
      final form = _store.forms.firstWhere((f) => f.id == formId);
      final session = _store.currentSession;
      if (session != null && session.organization.id != form.orgId) {
        return null;
      }
      return form;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<FeedbackForm?> getPublishedBySlug(String slug) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    try {
      final form = _store.forms.firstWhere(
        (f) => f.slug == slug && f.status == FormStatus.published,
      );
      Organization? org;
      for (final o in _store.organizations) {
        if (o.id == form.orgId) {
          org = o;
          break;
        }
      }
      if (org == null) return form;
      return form.copyWith(
        orgLogoUrl: org.logoUrl,
        showOrgLogo: org.showLogoOnForms,
        orgAllowsLogo: org.plan.allowsWorkspaceLogo,
        clearOrgLogoUrl: !org.hasLogo,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<FeedbackForm> createForm({
    required String orgId,
    required String title,
    required String description,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    _assertSameOrg(orgId);
    _assertCanCreateSurvey(orgId);
    final id = _uuid.v4();
    final form = FeedbackForm(
      id: id,
      orgId: orgId,
      title: title.trim(),
      description: description.trim(),
      slug: _uniqueSlug(title),
      status: FormStatus.draft,
      createdAt: DateTime.now(),
      questions: const [],
    );
    _store.forms.add(form);
    return form;
  }

  @override
  Future<FeedbackForm> updateForm(FeedbackForm form) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final index = _store.forms.indexWhere((f) => f.id == form.id);
    if (index < 0) throw StateError('Form not found');
    final existing = _store.forms[index];
    _assertSameOrg(existing.orgId);
    // Preserve status — only publishForm may change it.
    final updated = existing.copyWith(
      title: form.title,
      description: form.description,
      slug: form.slug.isEmpty ? existing.slug : _slugify(form.slug),
      questions: form.questions,
    );
    _store.forms[index] = updated;
    return updated;
  }

  @override
  Future<FeedbackForm> publishForm(String formId) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final index = _store.forms.indexWhere((f) => f.id == formId);
    if (index < 0) throw StateError('Form not found');
    final form = _store.forms[index];
    _assertSameOrg(form.orgId);
    if (form.questions.isEmpty) {
      throw StateError('Add at least one question before publishing.');
    }
    final published = form.copyWith(status: FormStatus.published);
    _store.forms[index] = published;
    return published;
  }

  void _assertCanCreateSurvey(String orgId) {
    final org = _store.organizations.firstWhere((o) => o.id == orgId);
    final count = _store.forms.where((f) => f.orgId == orgId).length;
    if (!org.plan.allowsAnotherSurvey(count)) {
      throw PlanLimitFailure(
        'Your ${org.plan.name} plan allows ${org.plan.maxSurveys} surveys. '
        'Upgrade on Billing to add more.',
      );
    }
  }

  @override
  Future<void> deleteForm(String formId) async {
    _assertAdmin();
    final index = _store.forms.indexWhere((f) => f.id == formId);
    if (index >= 0) {
      _assertSameOrg(_store.forms[index].orgId);
    }
    _store.forms.removeWhere((f) => f.id == formId);
    _store.responses.removeWhere((r) => r.formId == formId);
  }

  void _assertAdmin() {
    final session = _store.currentSession;
    if (session == null || !session.profile.isAdmin) {
      throw const AuthPermissionFailure(
        'Only admins can delete surveys.',
      );
    }
  }

  void _assertSameOrg(String orgId) {
    final session = _store.currentSession;
    if (session == null || session.organization.id != orgId) {
      throw const AuthPermissionFailure(
        'You cannot access another organisation’s data.',
      );
    }
  }

  @override
  Future<Question> upsertQuestion(Question question) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final formIndex = _store.forms.indexWhere((f) => f.id == question.formId);
    if (formIndex < 0) throw StateError('Form not found');
    final form = _store.forms[formIndex];
    _assertSameOrg(form.orgId);
    final questions = [...form.questions];
    final qIndex = questions.indexWhere((q) => q.id == question.id);
    final saved = question.id.isEmpty
        ? question.copyWith(id: _uuid.v4())
        : question;
    if (qIndex >= 0) {
      questions[qIndex] = saved;
    } else {
      questions.add(saved.copyWith(sortOrder: questions.length));
    }
    questions.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    _store.forms[formIndex] = form.copyWith(questions: questions);
    return saved;
  }

  @override
  Future<void> deleteQuestion(String questionId) async {
    _assertAdmin();
    for (var i = 0; i < _store.forms.length; i++) {
      final form = _store.forms[i];
      if (form.questions.any((q) => q.id == questionId)) {
        _assertSameOrg(form.orgId);
        final questions =
            form.questions.where((q) => q.id != questionId).toList();
        for (var j = 0; j < questions.length; j++) {
          questions[j] = questions[j].copyWith(sortOrder: j);
        }
        _store.forms[i] = form.copyWith(questions: questions);
        return;
      }
    }
  }

  @override
  Future<void> reorderQuestions(
    String formId,
    List<String> questionIds,
  ) async {
    final formIndex = _store.forms.indexWhere((f) => f.id == formId);
    if (formIndex < 0) return;
    final form = _store.forms[formIndex];
    final byId = {for (final q in form.questions) q.id: q};
    final reordered = <Question>[];
    for (var i = 0; i < questionIds.length; i++) {
      final q = byId[questionIds[i]];
      if (q != null) reordered.add(q.copyWith(sortOrder: i));
    }
    _store.forms[formIndex] = form.copyWith(questions: reordered);
  }

  String _uniqueSlug(String title) {
    var base = _slugify(title);
    if (base.isEmpty) base = 'form';
    var slug = base;
    var n = 1;
    while (_store.forms.any((f) => f.slug == slug)) {
      slug = '$base-$n';
      n++;
    }
    return slug;
  }

  String _slugify(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }
}
