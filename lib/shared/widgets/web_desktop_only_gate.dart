import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/fello_colors.dart';
import '../../core/theme/fello_typography.dart';
import 'fello_logo.dart';

/// On Flutter web, blocks narrow viewports until the product is mobile-ready.
/// Public customer forms (`/f/...`) stay available on any size.
class WebDesktopOnlyGate extends StatelessWidget {
  const WebDesktopOnlyGate({super.key, required this.child});

  final Widget? child;

  static const double desktopMinWidth = 960;

  @override
  Widget build(BuildContext context) {
    final content = child ?? const SizedBox.shrink();
    if (!kIsWeb) return content;

    final width = MediaQuery.sizeOf(context).width;
    if (width >= desktopMinWidth) return content;

    // MaterialApp.builder sits above route widgets, so use GoRouter.state.
    final path = GoRouter.of(context).state.uri.path;
    if (_isMobileAllowed(path)) {
      return content;
    }

    return const _UnsupportedScreenSize();
  }

  /// Auth, invites, public forms, and essential admin paths work on mobile.
  static bool _isMobileAllowed(String path) {
    if (path.startsWith('/f/')) return true;
    if (path.startsWith('/invite/')) return true;
    const always = {
      '/privacy',
      '/terms',
      '/sign-in',
      '/sign-up',
      '/forgot-password',
      '/reset-password',
      '/onboarding',
      '/dashboard',
      '/forms',
      '/team',
      '/settings/billing',
      '/settings/logo',
    };
    if (always.contains(path)) return true;
    if (path.startsWith('/dashboard/')) return true;
    if (path.startsWith('/forms/')) return true;
    return false;
  }
}

class _UnsupportedScreenSize extends StatelessWidget {
  const _UnsupportedScreenSize();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FelloColors.paper,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const FelloLogo(size: 36),
                  const SizedBox(height: 28),
                  Text(
                    'Not optimized for this screen size yet',
                    textAlign: TextAlign.center,
                    style: FelloTypography.pageTitle(context),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Kaydo’s workspace is built for larger screens. '
                    'Please open this app on a desktop or widen your browser window.',
                    textAlign: TextAlign.center,
                    style: FelloTypography.pageSubtitle(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
