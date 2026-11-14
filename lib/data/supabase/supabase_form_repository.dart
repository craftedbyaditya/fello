import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/feedback_form.dart';
import '../../domain/entities/question.dart';
import '../../domain/repositories/form_repository.dart';
import '../plan_limit_messages.dart';

class SupabaseFormRepository implements FormRepository {
  SupabaseFormRepository(this._client);

  final SupabaseClient _client;
  static const _uuid = Uuid();

  @override
  Future<List<FeedbackForm>> listForms(String orgId) async {
    final rows = await _client
        .from('forms')
        .select('*, questions(*)')
        .eq('org_id', orgId)
        .order('created_at', ascending: false);
    return (rows as List).map((r) => _mapForm(r as Map<String, dynamic>)).toList();
  }

  @override
  Future<FeedbackForm?> getForm(String formId) async {
    final row = await _client
        .from('forms')
        .select('*, questions(*)')
        .eq('id', formId)
        .maybeSingle();
    if (row == null) return null;
    return _mapForm(row);
  }

  @override
  Future<FeedbackForm?> getPublishedBySlug(String slug) async {
    final row = await _client
        .from('forms')
        .select(
          '*, questions(*), organizations(logo_url, show_logo_on_forms, plan_id)',
        )
        .eq('slug', slug)
        .eq('status', 'published')
        .maybeSingle();
    if (row == null) return null;
    return _mapForm(row);
  }

  @override
  Future<FeedbackForm> createForm({
    required String orgId,
    required String title,
    required String description,
  }) async {
    final slug = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    try {
      final row = await _client
          .from('forms')
          .insert({
            'org_id': orgId,
            'title': title,
            'description': description,
            'slug': slug.isEmpty ? _uuid.v4().substring(0, 8) : slug,
            'status': 'draft',
          })
          .select('*, questions(*)')
          .single();
      return _mapForm(row);
    } on PostgrestException catch (e) {
      final limit = planLimitFromError(e.message);
      if (limit != null) throw limit;
      rethrow;
    }
  }

  @override
  Future<FeedbackForm> updateForm(FeedbackForm form) async {
    // Never write status here — publishForm owns draft → published.
    final row = await _client
        .from('forms')
        .update({
          'title': form.title,
          'description': form.description,
          'slug': form.slug,
        })
        .eq('id', form.id)
        .select('*, questions(*)')
        .single();
    return _mapForm(row);
  }

  @override
  Future<FeedbackForm> publishForm(String formId) async {
    final row = await _client
        .from('forms')
        .update({'status': 'published'})
        .eq('id', formId)
        .select('*, questions(*)')
        .single();
    return _mapForm(row);
  }

  @override
  Future<void> deleteForm(String formId) async {
    await _client.from('forms').delete().eq('id', formId);
  }

  @override
  Future<Question> upsertQuestion(Question question) async {
    final id = question.id.isEmpty ? _uuid.v4() : question.id;
    final row = await _client
        .from('questions')
        .upsert({
          'id': id,
          'form_id': question.formId,
          'type': question.type.name,
          'label': question.label,
          'required': question.required,
          'options': question.options,
          'sort_order': question.sortOrder,
        })
        .select()
        .single();
    return _mapQuestion(row);
  }

  @override
  Future<void> deleteQuestion(String questionId) async {
    await _client.from('questions').delete().eq('id', questionId);
  }

  @override
  Future<void> reorderQuestions(
    String formId,
    List<String> questionIds,
  ) async {
    for (var i = 0; i < questionIds.length; i++) {
      await _client
          .from('questions')
          .update({'sort_order': i})
          .eq('id', questionIds[i]);
    }
  }

  FeedbackForm _mapForm(Map<String, dynamic> row) {
    final questions = (row['questions'] as List? ?? [])
        .map((q) => _mapQuestion(q as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final org = row['organizations'];
    String? logoUrl;
    var showLogo = false;
    var allowsLogo = false;
    if (org is Map) {
      final raw = (org['logo_url'] as String?)?.trim();
      logoUrl = (raw == null || raw.isEmpty) ? null : raw;
      showLogo = org['show_logo_on_forms'] as bool? ?? false;
      final planId = org['plan_id'] as String?;
      allowsLogo = planId != null && planId != 'free';
    }
    return FeedbackForm(
      id: row['id'] as String,
      orgId: row['org_id'] as String,
      title: row['title'] as String,
      description: row['description'] as String? ?? '',
      slug: row['slug'] as String,
      status: row['status'] == 'published'
          ? FormStatus.published
          : FormStatus.draft,
      createdAt: DateTime.parse(row['created_at'] as String),
      questions: questions,
      orgLogoUrl: logoUrl,
      showOrgLogo: showLogo,
      orgAllowsLogo: allowsLogo,
    );
  }

  Question _mapQuestion(Map<String, dynamic> row) {
    final options = (row['options'] as List? ?? [])
        .map((e) => '$e')
        .toList(growable: false);
    return Question(
      id: row['id'] as String,
      formId: row['form_id'] as String,
      type: QuestionType.values.firstWhere(
        (t) => t.name == row['type'],
        orElse: () => QuestionType.shortText,
      ),
      label: row['label'] as String,
      required: row['required'] as bool? ?? false,
      options: options,
      sortOrder: row['sort_order'] as int? ?? 0,
    );
  }
}
