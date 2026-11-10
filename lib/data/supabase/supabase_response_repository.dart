import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/dashboard_stats.dart';
import '../../domain/entities/question.dart';
import '../../domain/entities/response.dart';
import '../../domain/repositories/response_repository.dart';

class SupabaseResponseRepository implements ResponseRepository {
  SupabaseResponseRepository(this._client);

  final SupabaseClient _client;
  static const _uuid = Uuid();

  @override
  Future<List<FeedbackResponse>> listResponses({
    required String orgId,
    ResponseFilters filters = const ResponseFilters(),
  }) async {
    var query = _client
        .from('responses')
        .select('*, answers(*), forms!inner(org_id)')
        .eq('forms.org_id', orgId);

    if (filters.formId != null) {
      query = query.eq('form_id', filters.formId!);
    }
    if (filters.from != null) {
      query = query.gte('submitted_at', filters.from!.toIso8601String());
    }
    if (filters.to != null) {
      query = query.lte('submitted_at', filters.to!.toIso8601String());
    }

    final rows = await query.order('submitted_at', ascending: false);
    var list = (rows as List)
        .map((r) => _mapResponse(r as Map<String, dynamic>))
        .toList();

    // Client-side filter for rating/NPS bands (needs joined question types)
    if (filters.minRating != null ||
        filters.maxRating != null ||
        filters.npsBand != null) {
      final questions = await _questionsForOrg(orgId);
      list = list.where((r) {
        if (!_passesRatingFilter(r, questions, filters)) return false;
        if (!_passesNpsFilter(r, questions, filters)) return false;
        return true;
      }).toList();
    }
    return list;
  }

  @override
  Future<DashboardStats> getStats({
    required String orgId,
    ResponseFilters filters = const ResponseFilters(),
  }) async {
    final responses = await listResponses(orgId: orgId, filters: filters);
    final questions = await _questionsForOrg(orgId);
    return _computeStats(responses, questions);
  }

  @override
  Future<FeedbackResponse> submitResponse({
    required String formId,
    required Map<String, dynamic> answersByQuestionId,
    Map<String, dynamic> metadata = const {},
  }) async {
    final responseId = _uuid.v4();
    await _client.from('responses').insert({
      'id': responseId,
      'form_id': formId,
      'metadata': metadata,
    });

    if (answersByQuestionId.isNotEmpty) {
      await _client.from('answers').insert(
            answersByQuestionId.entries
                .map(
                  (e) => {
                    'id': _uuid.v4(),
                    'response_id': responseId,
                    'question_id': e.key,
                    'value': e.value,
                  },
                )
                .toList(),
          );
    }

    final row = await _client
        .from('responses')
        .select('*, answers(*)')
        .eq('id', responseId)
        .single();
    return _mapResponse(row);
  }

  Future<Map<String, QuestionType>> _questionsForOrg(String orgId) async {
    final rows = await _client
        .from('questions')
        .select('id, type, forms!inner(org_id)')
        .eq('forms.org_id', orgId);
    final map = <String, QuestionType>{};
    for (final r in rows as List) {
      final row = r as Map<String, dynamic>;
      map[row['id'] as String] = QuestionType.values.firstWhere(
        (t) => t.name == row['type'],
        orElse: () => QuestionType.shortText,
      );
    }
    return map;
  }

  bool _passesRatingFilter(
    FeedbackResponse r,
    Map<String, QuestionType> questions,
    ResponseFilters filters,
  ) {
    if (filters.minRating == null && filters.maxRating == null) return true;
    final rating = _valueForType(r, questions, QuestionType.starRating);
    if (rating == null) return false;
    if (filters.minRating != null && rating < filters.minRating!) return false;
    if (filters.maxRating != null && rating > filters.maxRating!) return false;
    return true;
  }

  bool _passesNpsFilter(
    FeedbackResponse r,
    Map<String, QuestionType> questions,
    ResponseFilters filters,
  ) {
    if (filters.npsBand == null) return true;
    final nps = _valueForType(r, questions, QuestionType.nps);
    if (nps == null) return false;
    return switch (filters.npsBand) {
      'detractor' => nps <= 6,
      'passive' => nps >= 7 && nps <= 8,
      'promoter' => nps >= 9,
      _ => true,
    };
  }

  int? _valueForType(
    FeedbackResponse r,
    Map<String, QuestionType> questions,
    QuestionType type,
  ) {
    for (final a in r.answers) {
      if (questions[a.questionId] == type && a.value is num) {
        return (a.value as num).toInt();
      }
    }
    return null;
  }

  DashboardStats _computeStats(
    List<FeedbackResponse> responses,
    Map<String, QuestionType> questions,
  ) {
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
      final rating = _valueForType(r, questions, QuestionType.starRating);
      if (rating != null) ratings.add(rating);
      final nps = _valueForType(r, questions, QuestionType.nps);
      if (nps != null) {
        npsScores.add(nps);
        npsDist[nps] = (npsDist[nps] ?? 0) + 1;
      }
    }

    return DashboardStats(
      totalResponses: responses.length,
      averageRating: ratings.isEmpty
          ? null
          : ratings.reduce((a, b) => a + b) / ratings.length,
      npsScore: npsScores.isEmpty
          ? null
          : ((npsScores.where((s) => s >= 9).length -
                      npsScores.where((s) => s <= 6).length) /
                  npsScores.length) *
              100,
      npsDistribution: npsDist,
      volumeByDay: volume,
      responseRateLabel: responses.isEmpty ? 'No responses yet' : 'Live',
    );
  }

  FeedbackResponse _mapResponse(Map<String, dynamic> row) {
    final answers = (row['answers'] as List? ?? [])
        .map(
          (a) => Answer(
            id: a['id'] as String,
            responseId: a['response_id'] as String,
            questionId: a['question_id'] as String,
            value: a['value'],
          ),
        )
        .toList();
    return FeedbackResponse(
      id: row['id'] as String,
      formId: row['form_id'] as String,
      submittedAt: DateTime.parse(row['submitted_at'] as String),
      metadata: Map<String, dynamic>.from(row['metadata'] as Map? ?? {}),
      answers: answers,
    );
  }
}
