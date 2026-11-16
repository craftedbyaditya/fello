import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/auth/presentation/auth_page.dart';
import '../../features/auth/presentation/forgot_password_page.dart';
import '../../features/auth/presentation/privacy_policy_page.dart';
import '../../features/auth/presentation/reset_password_page.dart';
import '../../features/auth/presentation/terms_of_service_page.dart';
import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/dashboard/presentation/all_reviews_page.dart';
import '../../features/dashboard/presentation/form_reviews_page.dart';
import '../../features/dashboard/presentation/shell_scaffold.dart';
import '../../features/forms/presentation/form_builder_page.dart';
import '../../features/forms/presentation/form_create_page.dart';
import '../../features/forms/presentation/form_share_page.dart';
import '../../features/forms/presentation/forms_list_page.dart';
import '../../features/onboarding/presentation/onboarding_page.dart';
import '../../features/public_form/presentation/public_form_page.dart';
import '../../features/settings/presentation/billing_page.dart';
import '../../features/settings/presentation/account_settings_page.dart';
import '../../features/settings/presentation/workspace_logo_page.dart';
import '../../features/board/presentation/board_page.dart';
import '../../features/developer_docs/presentation/developer_docs_page.dart';
import '../../features/team/presentation/accept_invite_page.dart';
import '../../features/team/presentation/team_page.dart';
import '../../features/notifications/bloc/notifications_bloc.dart';
import '../di/service_locator.dart';
import '../feature_flags/feature_flags_controller.dart';
import '../../domain/repositories/form_repository.dart';
import '../../domain/repositories/response_repository.dart';
import '../../domain/repositories/workflow_repository.dart';
import '../../features/dashboard/bloc/dashboard_bloc.dart';
import '../../features/forms/bloc/forms_bloc.dart';
import '../../shared/widgets/feature_unavailable_page.dart';

GoRouter createRouter(AuthBloc authBloc, FeatureFlagsController flags) {
  return GoRouter(
    initialLocation: '/sign-in',
    refreshListenable: Listenable.merge([
      GoRouterRefreshStream(authBloc.stream),
      flags,
    ]),
    redirect: (context, state) {
      final authState = authBloc.state;
      final location = state.matchedLocation;
      final loggingIn = location == '/sign-in' || location == '/sign-up';
      final passwordFlow =
          location == '/forgot-password' || location == '/reset-password';
      final isPublic =
          location.startsWith('/f/') ||
          location.startsWith('/invite/') ||
          location == '/privacy' ||
          location == '/terms';
      final onboarding = location == '/onboarding';
      final adminOnly =
          location == '/team' ||
          location == '/settings' ||
          location == '/settings/logo' ||
          location == '/settings/billing';
      final blockedFeature = switch (location) {
        '/board' when !flags.enabled('task_board_enabled') => 'Task board',
        '/developer-docs' when !flags.enabled('reviews_api_enabled') =>
          'Developer API',
        '/team' when !flags.enabled('team_invites_enabled') =>
          'Team invitations',
        '/settings/billing' when !flags.enabled('billing_enabled') => 'Billing',
        _ => null,
      };

      if (authState.status == AuthStatus.unknown) return null;
      if (isPublic) return null;

      // Recovery links land authenticated on /reset-password.
      if (location == '/reset-password') return null;
      if (location == '/forgot-password') {
        if (authState.isAuthenticated) {
          return authState.needsOnboarding ? '/onboarding' : '/dashboard';
        }
        return null;
      }

      if (!authState.isAuthenticated) {
        return loggingIn || passwordFlow ? null : '/sign-in';
      }

      if (loggingIn) {
        return authState.needsOnboarding ? '/onboarding' : '/dashboard';
      }

      if (authState.needsOnboarding && !onboarding) {
        return '/onboarding';
      }

      if (adminOnly && authState.session?.profile.isAdmin != true) {
        return '/dashboard';
      }
      if (blockedFeature != null && location != '/unavailable') {
        return '/unavailable?feature=${Uri.encodeComponent(blockedFeature)}';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/sign-in', builder: (context, state) => const AuthPage()),
      GoRoute(
        path: '/sign-up',
        builder: (context, state) => const AuthPage(initialSignUp: true),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => const ResetPasswordPage(),
      ),
      GoRoute(
        path: '/privacy',
        builder: (context, state) => const PrivacyPolicyPage(),
      ),
      GoRoute(
        path: '/terms',
        builder: (context, state) => const TermsOfServicePage(),
      ),
      GoRoute(
        path: '/unavailable',
        builder: (_, state) => FeatureUnavailablePage(
          feature: state.uri.queryParameters['feature'] ?? 'This feature',
        ),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(
        path: '/invite/:token',
        builder: (_, state) =>
            AcceptInvitePage(token: state.pathParameters['token']!),
      ),
      GoRoute(
        path: '/f/:slug',
        builder: (_, state) =>
            PublicFormPage(slug: state.pathParameters['slug']!),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => FormsBloc(getIt<FormRepository>())),
              BlocProvider(
                create: (_) => DashboardBloc(
                  responseRepository: getIt<ResponseRepository>(),
                  formRepository: getIt<FormRepository>(),
                ),
              ),
              BlocProvider(
                create: (_) =>
                    NotificationsBloc(getIt<WorkflowRepository>())
                      ..add(const NotificationsLoadRequested()),
              ),
            ],
            child: ShellScaffold(navigationShell: navigationShell),
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardPage(),
                routes: [
                  GoRoute(
                    path: 'reviews/:formId',
                    builder: (context, state) => FormReviewsPage(
                      formId: state.pathParameters['formId']!,
                      taskId: state.uri.queryParameters['task'],
                    ),
                    routes: [
                      GoRoute(
                        path: 'all',
                        builder: (context, state) => AllReviewsPage(
                          formId: state.pathParameters['formId']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/forms',
                builder: (context, state) => const FormsListPage(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => const FormCreatePage(),
                  ),
                  GoRoute(
                    path: ':formId',
                    builder: (context, state) => FormBuilderPage(
                      formId: state.pathParameters['formId']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'share',
                        builder: (context, state) => FormSharePage(
                          formId: state.pathParameters['formId']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/board',
                builder: (context, state) => const BoardPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/team',
                builder: (context, state) => const TeamPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings/logo',
                builder: (context, state) => const WorkspaceLogoPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings/billing',
                builder: (context, state) => const BillingPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/developer-docs',
                builder: (context, state) => const DeveloperDocsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const AccountSettingsPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
