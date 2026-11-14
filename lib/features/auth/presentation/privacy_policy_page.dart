import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/fello_colors.dart';
import '../../../shared/widgets/fello_back_button.dart';
import '../../../shared/widgets/fello_logo.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

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
                          'Privacy Policy',
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
                          'This Privacy Policy describes how Kaydo (“we”, “us”) '
                          'collects, uses, and protects information when you use '
                          'our feedback platform and related services.',
                          style: bodyStyle,
                        ),
                        const SizedBox(height: 28),
                        _Section(
                          title: '1. Information we collect',
                          headingStyle: headingStyle,
                          bodyStyle: bodyStyle,
                          body:
                              'Account information such as name, work email, and '
                              'organisation details when you create a workspace. '
                              'Form content and response data submitted through '
                              'forms you publish. Technical data such as browser '
                              'type, device, and approximate usage logs needed to '
                              'operate and secure the service.',
                        ),
                        _Section(
                          title: '2. How we use information',
                          headingStyle: headingStyle,
                          bodyStyle: bodyStyle,
                          body:
                              'We use information to provide and improve the '
                              'product, authenticate users, display analytics in '
                              'your dashboard, provide customer support, and '
                              'maintain the security and integrity of Kaydo. We '
                              'do not sell personal information.',
                        ),
                        _Section(
                          title: '3. Sharing',
                          headingStyle: headingStyle,
                          bodyStyle: bodyStyle,
                          body:
                              'We may share data with infrastructure and service '
                              'providers who process it on our behalf under '
                              'contractual confidentiality obligations. We may '
                              'disclose information if required by law or to '
                              'protect the rights, safety, and security of Kaydo '
                              'and our customers.',
                        ),
                        _Section(
                          title: '4. Data retention',
                          headingStyle: headingStyle,
                          bodyStyle: bodyStyle,
                          body:
                              'We retain account and response data for as long as '
                              'your organisation maintains an active workspace, '
                              'or as needed to meet legal and operational '
                              'requirements. You may request deletion of your '
                              'organisation data subject to applicable law.',
                        ),
                        _Section(
                          title: '5. Security',
                          headingStyle: headingStyle,
                          bodyStyle: bodyStyle,
                          body:
                              'We apply administrative, technical, and '
                              'organisational measures designed to protect '
                              'information against unauthorised access, loss, or '
                              'alteration. No method of transmission or storage '
                              'is completely secure.',
                        ),
                        _Section(
                          title: '6. Your choices',
                          headingStyle: headingStyle,
                          bodyStyle: bodyStyle,
                          body:
                              'Workspace administrators control forms and '
                              'response data within their organisation. You may '
                              'update account details from your profile, and '
                              'contact us to exercise access, correction, or '
                              'deletion rights where applicable.',
                        ),
                        _Section(
                          title: '7. Contact',
                          headingStyle: headingStyle,
                          bodyStyle: bodyStyle,
                          body:
                              'For privacy questions or requests, contact '
                              'privacy@kaydo.app.',
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
