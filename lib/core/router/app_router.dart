import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/auth/presentation/auth_page.dart';
import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/dashboard/presentation/shell_scaffold.dart';
import '../../features/forms/presentation/form_builder_page.dart';
import '../../features/forms/presentation/form_share_page.dart';
import '../../features/forms/presentation/forms_list_page.dart';
import '../../features/onboarding/presentation/onboarding_page.dart';
import '../../features/public_form/presentation/public_form_page.dart';
import '../di/service_locator.dart';
import '../../domain/repositories/form_repository.dart';
import '../../domain/repositories/response_repository.dart';
import '../../features/dashboard/bloc/dashboard_bloc.dart';
import '../../features/forms/bloc/forms_bloc.dart';

GoRouter createRouter(AuthBloc authBloc) {
  return GoRouter(
    initialLocation: '/sign-in',
    refreshListenable: GoRouterRefreshStream(authBloc.stream),
    redirect: (context, state) {
      final authState = authBloc.state;
      final loggingIn = state.matchedLocation == '/sign-in' ||
          state.matchedLocation == '/sign-up';
      final isPublic = state.matchedLocation.startsWith('/f/');
      final onboarding = state.matchedLocation == '/onboarding';

      if (authState.status == AuthStatus.unknown) return null;
      if (isPublic) return null;

      if (!authState.isAuthenticated) {
        return loggingIn ? null : '/sign-in';
      }

      if (loggingIn) {
        return authState.needsOnboarding ? '/onboarding' : '/dashboard';
      }

      if (authState.needsOnboarding && !onboarding) {
        return '/onboarding';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const AuthPage(),
      ),
      GoRoute(
        path: '/sign-up',
        builder: (context, state) => const AuthPage(initialSignUp: true),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(
        path: '/f/:slug',
        builder: (_, state) => PublicFormPage(
          slug: state.pathParameters['slug']!,
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) => FormsBloc(getIt<FormRepository>()),
              ),
              BlocProvider(
                create: (_) => DashboardBloc(
                  responseRepository: getIt<ResponseRepository>(),
                  formRepository: getIt<FormRepository>(),
                ),
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
