import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/dashboard_stats.dart';
import '../../domain/entities/question.dart';
import '../../domain/entities/response.dart';
import '../../domain/plan_limit_failure.dart';
import '../../domain/repositories/response_repository.dart';
import '../../domain/submit_guard_failure.dart';
import '../plan_limit_messages.dart';

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
        .select('*, answers(*), forms!inner(org_id, id)')
        .eq('forms.org_id', orgId);

    if (filters.formId != null) {
      query = query.eq('form_id', filters.formId!);
    }
    if (filters.from != null) {
      query = query.gte(
        'submitted_at',
        filters.from!.toUtc().toIso8601String(),
      );
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
      query = query.lte('submitted_at', end.toUtc().toIso8601String());
    }

    final rows = await query.order('submitted_at', ascending: false);
    final questions = await _questionsForOrg(orgId);
    var list = (rows as List)
        .map((r) => _mapResponse(r as Map<String, dynamic>))
        .toList();

    list = list
        .where((r) => _passesRatingFilter(r, questions, filters))
        .where((r) => _passesNpsFilter(r, questions, filters))
        .toList();
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
    String? clientKey,
    String? submissionId,
    String? turnstileToken,
  }) async {
    final sid = submissionId ?? _uuid.v4();
    final key = (clientKey == null || clientKey.isEmpty)
        ? 'anonymous'
        : clientKey;

    // Direct RPC is revoked for anon/authenticated — Edge Function only.
    if (turnstileToken == null || turnstileToken.isEmpty) {
      throw const SubmitGuardFailure(
        'Please complete the captcha before submitting.',
      );
    }

    try {
      final res = await _client.functions.invoke(
        'submit-feedback',
        body: {
          'form_id': formId,
          'answers': answersByQuestionId,
          'metadata': metadata,
          'client_key': key,
          'submission_id': sid,
          'turnstile_token': turnstileToken,
        },
      );
      if (res.status >= 400) {
        final data = res.data;
        final msg = data is Map && data['error'] != null
            ? '${data['error']}'
            : 'Submission failed.';
        throw _mapSubmitError(msg);
      }
      final data = res.data;
      final id = data is Map ? data['response_id'] as String? : null;
      if (id == null) {
        throw const SubmitGuardFailure('Submission failed.');
      }
      return FeedbackResponse(
        id: id,
        formId: formId,
        submittedAt: DateTime.now().toUtc(),
        metadata: metadata,
        answers: answersByQuestionId.entries
            .map(
              (e) => Answer(
                id: _uuid.v4(),
                responseId: id,
                questionId: e.key,
                value: e.value,
              ),
            )
            .toList(),
      );
    } on FunctionException catch (e) {
      throw _mapSubmitError(e.details?.toString() ?? e.toString());
    } on SubmitGuardFailure {
      rethrow;
    } on PlanLimitFailure {
      rethrow;
    } catch (e) {
      if (e is Exception) throw _mapSubmitError(e.toString());
      throw _mapSubmitError('$e');
    }
  }

  Exception _mapSubmitError(String message) {
    final limit = planLimitFromError(message);
    if (limit != null) return limit;
    final lower = message.toLowerCase();
    if (lower.contains('rate_limited') || lower.contains('too many')) {
      return const SubmitGuardFailure(
        'Too many submissions. Please try again later.',
      );
    }
    if (lower.contains('duplicate')) {
      return const SubmitGuardFailure('This response was already submitted.');
    }
    if (lower.contains('invalid_answers') || lower.contains('please answer')) {
      return SubmitGuardFailure(
        message.replaceFirst(RegExp(r'^.*INVALID_ANSWERS:\s*'), ''),
      );
    }
    if (lower.contains('turnstile') || lower.contains('captcha')) {
      return const SubmitGuardFailure(
        'Captcha verification failed. Please try again.',
      );
    }
    if (message.contains('PLAN_LIMIT')) {
      return PlanLimitFailure(message);
    }
    return SubmitGuardFailure(
      message.isNotEmpty ? message : 'Submission failed.',
    );
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
      if ((a.questionType == type.name || questions[a.questionId] == type) &&
          a.value is num) {
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

  @override
  Future<FeedbackResponse> setResponsePublic({
    required String responseId,
    required bool isPublic,
  }) async {
    final row = await _client
        .from('responses')
        .update({'is_public': isPublic})
        .eq('id', responseId)
        .select('*, answers(*)')
        .single();
    return _mapResponse(Map<String, dynamic>.from(row));
  }

  FeedbackResponse _mapResponse(Map<String, dynamic> row) {
    final answers = (row['answers'] as List? ?? []).map((a) {
      final m = a as Map<String, dynamic>;
      return Answer(
        id: m['id'] as String,
        responseId: m['response_id'] as String,
        questionId:
            m['question_id'] as String? ??
            ((m['question_snapshot'] as Map?)?['id'] as String? ?? ''),
        value: m['value'],
        questionLabel: (m['question_snapshot'] as Map?)?['label'] as String?,
        questionType: (m['question_snapshot'] as Map?)?['type'] as String?,
      );
    }).toList();
    return FeedbackResponse(
      id: row['id'] as String,
      formId: row['form_id'] as String,
      submittedAt: DateTime.parse(row['submitted_at'] as String),
      metadata: Map<String, dynamic>.from(
        (row['metadata'] as Map?) ?? const {},
      ),
      answers: answers,
      isPublic: row['is_public'] as bool? ?? false,
    );
  }
}
