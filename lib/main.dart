import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'core/config/app_config.dart';
import 'core/di/service_locator.dart';
import 'core/router/app_router.dart';
import 'core/theme/fello_theme.dart';
import 'domain/repositories/auth_repository.dart';
import 'features/auth/bloc/auth_bloc.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    // Hash URLs work on static hosts without rewrite rules.
    setUrlStrategy(const HashUrlStrategy());
  }
  final config = AppConfig.fromEnvironment();
  await configureDependencies(config);

  final authBloc = AuthBloc(getIt<AuthRepository>())
    ..add(const AuthSubscriptionRequested());

  runApp(FelloApp(authBloc: authBloc));
}

class FelloApp extends StatelessWidget {
  const FelloApp({super.key, required this.authBloc});

  final AuthBloc authBloc;

  @override
  Widget build(BuildContext context) {
    final router = createRouter(authBloc);

    return BlocProvider.value(
      value: authBloc,
      child: MaterialApp.router(
        title: 'Fello',
        debugShowCheckedModeBanner: false,
        theme: FelloTheme.light(),
        routerConfig: router,
      ),
    );
  }
}
