import 'package:uuid/uuid.dart';

import '../../domain/auth_permission_failure.dart';
import '../../domain/entities/dashboard_stats.dart';
import '../../domain/entities/question.dart';
import '../../domain/entities/response.dart';
import '../../domain/plan_limit_failure.dart';
import '../../domain/public_answer_validator.dart';
import '../../domain/repositories/response_repository.dart';
import '../../domain/submit_guard_failure.dart';
import 'mock_store.dart';
import 'mock_workflow_repository.dart';

class MockResponseRepository implements ResponseRepository {
  MockResponseRepository(this._store);

  final MockStore _store;
  static const _uuid = Uuid();

  @override
  Future<List<FeedbackResponse>> listResponses({
    required String orgId,
    ResponseFilters filters = const ResponseFilters(),
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    _assertOrgAccess(orgId);
    return _filtered(orgId, filters);
  }

  @override
  Future<DashboardStats> getStats({
    required String orgId,
    ResponseFilters filters = const ResponseFilters(),
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    _assertOrgAccess(orgId);
    final responses = _filtered(orgId, filters);
    return _computeStats(responses);
  }

  void _assertOrgAccess(String orgId) {
    final session = _store.currentSession;
    if (session != null && session.organization.id != orgId) {
      throw const AuthPermissionFailure(
        'You cannot access another organisation’s data.',
      );
    }
  }

  @override
  Future<FeedbackResponse> submitResponse({
    required String formId,
    required Map<String, dynamic> answersByQuestionId,
    Map<String, dynamic> metadata = const {},
    String? clientKey,
    String? submissionId,
    String? turnstileToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final form = _store.forms.firstWhere(
      (f) => f.id == formId,
      orElse: () => throw StateError('Form not found'),
    );
    if (!form.isPublished) {
      throw StateError('This form is not accepting responses.');
    }

    final sid = submissionId ?? _uuid.v4();
    if (_store.submitDedupeIds.contains(sid)) {
      throw const SubmitGuardFailure(
        'This response was already submitted.',
      );
    }

    final key = (clientKey == null || clientKey.isEmpty) ? 'anonymous' : clientKey;
    final rateKey = '$key|$formId';
    final now = DateTime.now().toUtc();
    final window = _store.submitRateWindows[rateKey];
    if (window == null || now.difference(window.$1) > const Duration(minutes: 10)) {
      _store.submitRateWindows[rateKey] = (now, 1);
    } else {
      final next = window.$2 + 1;
      _store.submitRateWindows[rateKey] = (window.$1, next);
      if (next > 20) {
        throw const SubmitGuardFailure(
          'Too many submissions. Please try again later.',
        );
      }
    }

    final invalid = PublicAnswerValidator.validate(
      questions: form.questions,
      answers: answersByQuestionId,
    );
    if (invalid != null) {
      throw SubmitGuardFailure(invalid);
    }

    final org = _store.organizations.firstWhere((o) => o.id == form.orgId);
    final periodStart = DateTime.utc(now.year, now.month);
    final formIds =
        _store.forms.where((f) => f.orgId == org.id).map((f) => f.id).toSet();
    final monthCount = _store.responses
        .where(
          (r) =>
              formIds.contains(r.formId) &&
              !r.submittedAt.toUtc().isBefore(periodStart),
        )
        .length;
    if (!org.plan.allowsAnotherResponse(monthCount)) {
      throw const PlanLimitFailure(
        'This workspace has reached its monthly response limit.',
        upgradeHint: false,
      );
    }

    final responseId = _uuid.v4();
    final answers = answersByQuestionId.entries.map((e) {
      return Answer(
        id: _uuid.v4(),
        responseId: responseId,
        questionId: e.key,
        value: e.value,
      );
    }).toList();

    final response = FeedbackResponse(
      id: responseId,
      formId: formId,
      submittedAt: DateTime.now(),
      metadata: metadata,
      answers: answers,
    );
    _store.responses.add(response);
    _store.submitDedupeIds.add(sid);
    // Background AI in mock: never fail the submit path.
    try {
      await MockWorkflowRepository(_store).processResponseLocally(responseId);
    } catch (_) {}
    return response;
  }

  @override
  Future<FeedbackResponse> setResponsePublic({
    required String responseId,
    required bool isPublic,
  }) async {
    final session = _store.currentSession;
    if (session == null || !session.profile.isAdmin) {
      throw const AuthPermissionFailure(
        'Only admins can change review visibility.',
      );
    }
    final index = _store.responses.indexWhere((r) => r.id == responseId);
    if (index < 0) throw StateError('Response not found');
    final response = _store.responses[index];
    final form = _store.forms.firstWhere((f) => f.id == response.formId);
    if (form.orgId != session.organization.id) {
      throw const AuthPermissionFailure(
        'You cannot access another organisation’s data.',
      );
    }
    final updated = response.copyWith(isPublic: isPublic);
    _store.responses[index] = updated;
    return updated;
  }

  List<FeedbackResponse> _filtered(String orgId, ResponseFilters filters) {
    final formIds = _store.forms
        .where((f) => f.orgId == orgId)
        .map((f) => f.id)
        .toSet();

    var list = _store.responses
        .where((r) => formIds.contains(r.formId))
        .toList();

    if (filters.formId != null) {
      list = list.where((r) => r.formId == filters.formId).toList();
    }
    if (filters.from != null) {
      list = list
          .where(
            (r) => !r.submittedAt.isBefore(
              DateTime(
                filters.from!.year,
                filters.from!.month,
                filters.from!.day,
              ),
            ),
          )
          .toList();
    }
    if (filters.to != null) {
      final end = DateTime(
        filters.to!.year,
        filters.to!.month,
        filters.to!.day,
        23,
        59,
        59,
      );
      list = list.where((r) => !r.submittedAt.isAfter(end)).toList();
    }

    if (filters.minRating != null || filters.maxRating != null) {
      list = list.where((r) {
        final rating = _ratingFor(r);
        if (rating == null) return false;
        if (filters.minRating != null && rating < filters.minRating!) {
          return false;
        }
        if (filters.maxRating != null && rating > filters.maxRating!) {
          return false;
        }
        return true;
      }).toList();
    }

    if (filters.npsBand != null) {
      list = list.where((r) {
        final nps = _npsFor(r);
        if (nps == null) return false;
        return switch (filters.npsBand) {
          'detractor' => nps <= 6,
          'passive' => nps >= 7 && nps <= 8,
          'promoter' => nps >= 9,
          _ => true,
        };
      }).toList();
    }

    list.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return list;
  }

  DashboardStats _computeStats(List<FeedbackResponse> responses) {
    final ratings = <int>[];
    final npsScores = <int>[];
    final npsDist = {for (var i = 0; i <= 10; i++) i: 0};
    final volume = <DateTime, int>{};

    for (final r in responses) {
      final day = DateTime(
        r.submittedAt.year,
        r.submittedAt.month,
        r.submittedAt.day,
      );
      volume[day] = (volume[day] ?? 0) + 1;

      final rating = _ratingFor(r);
      if (rating != null) ratings.add(rating);

      final nps = _npsFor(r);
      if (nps != null) {
        npsScores.add(nps);
        npsDist[nps] = (npsDist[nps] ?? 0) + 1;
      }
    }

    double? avgRating;
    if (ratings.isNotEmpty) {
      avgRating = ratings.reduce((a, b) => a + b) / ratings.length;
    }

    double? npsScore;
    if (npsScores.isNotEmpty) {
      final promoters = npsScores.where((s) => s >= 9).length;
      final detractors = npsScores.where((s) => s <= 6).length;
      npsScore = ((promoters - detractors) / npsScores.length) * 100;
    }

    return DashboardStats(
      totalResponses: responses.length,
      averageRating: avgRating,
      npsScore: npsScore,
      npsDistribution: npsDist,
      volumeByDay: volume,
      responseRateLabel: responses.isEmpty ? 'No responses yet' : 'Live',
    );
  }

  int? _ratingFor(FeedbackResponse r) {
    for (final a in r.answers) {
      final q = _question(a.questionId);
      if (q?.type == QuestionType.starRating && a.value is num) {
        return (a.value as num).toInt();
      }
    }
    return null;
  }

  int? _npsFor(FeedbackResponse r) {
    for (final a in r.answers) {
      final q = _question(a.questionId);
      if (q?.type == QuestionType.nps && a.value is num) {
        return (a.value as num).toInt();
      }
    }
    return null;
  }

  Question? _question(String id) {
    for (final f in _store.forms) {
      for (final q in f.questions) {
        if (q.id == id) return q;
      }
    }
    return null;
  }
}
