import 'package:uuid/uuid.dart';

import '../../domain/entities/dashboard_stats.dart';
import '../../domain/entities/question.dart';
import '../../domain/entities/response.dart';
import '../../domain/repositories/response_repository.dart';
import 'mock_store.dart';

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
    return _filtered(orgId, filters);
  }

  @override
  Future<DashboardStats> getStats({
    required String orgId,
    ResponseFilters filters = const ResponseFilters(),
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final responses = _filtered(orgId, filters);
    return _computeStats(responses);
  }

  @override
  Future<FeedbackResponse> submitResponse({
    required String formId,
    required Map<String, dynamic> answersByQuestionId,
    Map<String, dynamic> metadata = const {},
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final form = _store.forms.firstWhere(
      (f) => f.id == formId,
      orElse: () => throw StateError('Form not found'),
    );
    if (!form.isPublished) {
      throw StateError('This form is not accepting responses.');
    }

    for (final q in form.questions.where((q) => q.required)) {
      final value = answersByQuestionId[q.id];
      if (value == null ||
          (value is String && value.trim().isEmpty) ||
          (value is List && value.isEmpty)) {
        throw StateError('Please answer: ${q.label}');
      }
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
    return response;
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
