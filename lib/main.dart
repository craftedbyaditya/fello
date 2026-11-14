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
import 'shared/widgets/web_desktop_only_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    // Clean paths for kaydo.sayge.in share links (/f/:slug). Hosting must
    // rewrite unknown routes to index.html (see deploy/ and web/_redirects).
    usePathUrlStrategy();
  }

  final config = AppConfig.fromEnvironment();
  try {
    config.validate();
    await configureDependencies(config);
  } catch (e) {
    runApp(_BootErrorApp(message: '$e'));
    return;
  }

  final authBloc = AuthBloc(getIt<AuthRepository>())
    ..add(const AuthSubscriptionRequested());

  runApp(FelloApp(authBloc: authBloc));
}

class _BootErrorApp extends StatelessWidget {
  const _BootErrorApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, height: 1.45),
              ),
            ),
          ),
        ),
      ),
    );
  }
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
        title: 'Kaydo',
        debugShowCheckedModeBanner: false,
        theme: FelloTheme.light(),
        routerConfig: router,
        builder: (context, child) => WebDesktopOnlyGate(child: child),
      ),
    );
  }
}
