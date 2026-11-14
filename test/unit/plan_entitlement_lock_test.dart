import 'package:fello/data/mock/mock_billing_repository.dart';
import 'package:fello/data/mock/mock_store.dart';
import 'package:fello/domain/auth_failure.dart';
import 'package:fello/domain/entities/subscription_plan.dart';
import 'package:fello/domain/repositories/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selectPlan fails closed until billing exists', () async {
    final store = MockStore();
    final org = store.organizations.first;
    final profile = store.profiles.first;
    store.setSession(AuthSession(profile: profile, organization: org));

    final billing = MockBillingRepository(store);
    await expectLater(
      billing.selectPlan(orgId: org.id, planId: PlanId.growth),
      throwsA(
        isA<AuthFailure>().having(
          (e) => e.message,
          'message',
          contains('billing'),
        ),
      ),
    );
    expect(store.organizations.first.planId, org.planId);
  });
}
