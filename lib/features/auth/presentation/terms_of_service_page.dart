import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/fello_colors.dart';
import '../../../shared/widgets/fello_back_button.dart';
import '../../../shared/widgets/fello_logo.dart';

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    final bodyStyle = GoogleFonts.poppins(
      fontSize: 14,
      height: 1.65,
      color: FelloColors.inkSoft,
      fontWeight: FontWeight.w400,
    );
    final headingStyle = GoogleFonts.poppins(
      fontSize: 15,
      height: 1.4,
      color: FelloColors.ink,
      fontWeight: FontWeight.w600,
    );

    return Scaffold(
      backgroundColor: FelloColors.paper,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 24, 0),
                  child: Row(
                    children: [
                      FelloBackButton(
                        onPressed: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/sign-in');
                          }
                        },
                      ),
                      const SizedBox(width: 4),
                      const FelloLogo(size: 28),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(32, 28, 32, 48),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Terms of Service',
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            color: FelloColors.ink,
                            height: 1.2,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Last updated: 12 November 2026',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: FelloColors.inkSoft,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'These Terms of Service govern your use of Kaydo. '
                          'By creating an account or using the product, you agree '
                          'to these terms.',
                          style: bodyStyle,
                        ),
                        const SizedBox(height: 28),
                        _Section(
                          title: '1. The service',
                          headingStyle: headingStyle,
                          bodyStyle: bodyStyle,
                          body:
                              'Kaydo provides tools to create feedback forms, '
                              'collect responses, and review analytics for your '
                              'organisation. Features may change as we improve '
                              'the product.',
                        ),
                        _Section(
                          title: '2. Accounts',
                          headingStyle: headingStyle,
                          bodyStyle: bodyStyle,
                          body:
                              'You are responsible for maintaining the '
                              'confidentiality of your login credentials and for '
                              'activity under your organisation workspace. Provide '
                              'accurate account information and keep it up to date.',
                        ),
                        _Section(
                          title: '3. Acceptable use',
                          headingStyle: headingStyle,
                          bodyStyle: bodyStyle,
                          body:
                              'Do not misuse Kaydo, attempt unauthorised access, '
                              'interfere with the service, or use it to collect '
                              'unlawful or harmful content. We may suspend access '
                              'for violations of these terms.',
                        ),
                        _Section(
                          title: '4. Your content',
                          headingStyle: headingStyle,
                          bodyStyle: bodyStyle,
                          body:
                              'You retain ownership of forms and response data '
                              'you submit. You grant Kaydo a limited licence to '
                              'host and process that content solely to operate '
                              'and improve the service.',
                        ),
                        _Section(
                          title: '5. Contact',
                          headingStyle: headingStyle,
                          bodyStyle: bodyStyle,
                          body: 'For questions about these terms, contact legal@kaydo.app.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.body,
    required this.headingStyle,
    required this.bodyStyle,
  });

  final String title;
  final String body;
  final TextStyle headingStyle;
  final TextStyle bodyStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: headingStyle),
          const SizedBox(height: 8),
          Text(body, style: bodyStyle),
        ],
      ),
    );
  }
}
