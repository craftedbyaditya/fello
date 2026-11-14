import 'package:uuid/uuid.dart';

import '../../domain/entities/business_type.dart';
import '../../domain/entities/feedback_form.dart';
import '../../domain/entities/organization.dart';
import '../../domain/entities/profile.dart';
import '../../domain/entities/question.dart';
import '../../domain/entities/response.dart';
import '../../domain/entities/subscription_plan.dart';

const _uuid = Uuid();

/// In-memory seed that mirrors `supabase/seed.sql`.
class MockSeedData {
  MockSeedData() {
    final now = DateTime.now();

    org = Organization(
      id: 'org_demo',
      name: 'Harbor Coffee',
      slug: 'harbor-coffee',
      createdAt: now.subtract(const Duration(days: 40)),
      businessType: BusinessType.restaurantCafe,
      onboardingCompletedAt: now.subtract(const Duration(days: 40)),
      planId: PlanId.starter,
    );

    profile = Profile(
      id: 'user_demo',
      orgId: org.id,
      displayName: 'Ada Chen',
      email: 'ada@harbor.coffee',
      role: ProfileRole.admin,
      createdAt: now.subtract(const Duration(days: 40)),
    );

    // Demo credentials for mock sign-in
    credentials = {'ada@harbor.coffee': 'fello123'};

    final formId = 'form_visit';
    final qRating = Question(
      id: 'q_rating',
      formId: formId,
      type: QuestionType.starRating,
      label: 'How was your visit?',
      required: true,
      sortOrder: 0,
    );
    final qNps = Question(
      id: 'q_nps',
      formId: formId,
      type: QuestionType.nps,
      label: 'How likely are you to recommend us?',
      required: true,
      sortOrder: 1,
    );
    final qChoice = Question(
      id: 'q_choice',
      formId: formId,
      type: QuestionType.singleChoice,
      label: 'What brought you in today?',
      required: false,
      options: const ['Coffee', 'Pastries', 'Meeting', 'Other'],
      sortOrder: 2,
    );
    final qText = Question(
      id: 'q_text',
      formId: formId,
      type: QuestionType.longText,
      label: 'Anything else we should know?',
      required: false,
      sortOrder: 3,
    );

    forms = [
      FeedbackForm(
        id: formId,
        orgId: org.id,
        title: 'Post-visit feedback',
        description: 'A quick pulse check after your café visit.',
        slug: 'harbor-visit',
        status: FormStatus.published,
        createdAt: now.subtract(const Duration(days: 20)),
        questions: [qRating, qNps, qChoice, qText],
      ),
      FeedbackForm(
        id: 'form_draft',
        orgId: org.id,
        title: 'New menu tasting',
        description: 'Collect reactions to seasonal drinks.',
        slug: 'menu-tasting',
        status: FormStatus.draft,
        createdAt: now.subtract(const Duration(days: 2)),
        questions: [
          Question(
            id: 'q_draft_1',
            formId: 'form_draft',
            type: QuestionType.yesNo,
            label: 'Would you order this again?',
            required: true,
            sortOrder: 0,
          ),
        ],
      ),
    ];

    responses = [];
    final samples = <(int, int, String, String)>[
      (5, 10, 'Coffee', 'Loved the pour-over.'),
      (4, 9, 'Pastries', 'Croissant was perfect.'),
      (5, 10, 'Meeting', ''),
      (3, 6, 'Coffee', 'Waited a bit long.'),
      (2, 4, 'Other', 'Music was loud.'),
      (4, 8, 'Coffee', 'Friendly barista.'),
      (5, 9, 'Pastries', ''),
      (4, 8, 'Meeting', 'Great seating.'),
      (1, 2, 'Coffee', 'Wrong order.'),
      (5, 10, 'Coffee', 'Best flat white in town.'),
      (4, 7, 'Pastries', 'Need more vegan options.'),
      (3, 5, 'Other', ''),
    ];

    for (var i = 0; i < samples.length; i++) {
      final (rating, nps, choice, text) = samples[i];
      final responseId = 'resp_$i';
      final submitted = now.subtract(Duration(days: samples.length - i));
      responses.add(
        FeedbackResponse(
          id: responseId,
          formId: formId,
          submittedAt: submitted,
          metadata: const {'source': 'mock'},
          answers: [
            Answer(
              id: _uuid.v4(),
              responseId: responseId,
              questionId: qRating.id,
              value: rating,
            ),
            Answer(
              id: _uuid.v4(),
              responseId: responseId,
              questionId: qNps.id,
              value: nps,
            ),
            Answer(
              id: _uuid.v4(),
              responseId: responseId,
              questionId: qChoice.id,
              value: choice,
            ),
            if (text.isNotEmpty)
              Answer(
                id: _uuid.v4(),
                responseId: responseId,
                questionId: qText.id,
                value: text,
              ),
          ],
        ),
      );
    }
  }

  late Organization org;
  late Profile profile;
  late Map<String, String> credentials;
  late List<FeedbackForm> forms;
  late List<FeedbackResponse> responses;

  final Map<String, Organization> orgsById = {};
  final Map<String, Profile> profilesById = {};
  final Map<String, String> passwordsByEmail = {};

  void registerSeed() {
    orgsById[org.id] = org;
    profilesById[profile.id] = profile;
    passwordsByEmail.addAll(credentials);
  }
}
