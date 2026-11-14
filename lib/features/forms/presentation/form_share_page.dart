import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/theme/fello_colors.dart';
import '../../../core/theme/fello_typography.dart';
import '../../../shared/animations/fade_slide_in.dart';
import '../../../shared/widgets/fello_back_button.dart';
import '../../../shared/widgets/kaydo_toast.dart';
import '../bloc/forms_bloc.dart';

class FormSharePage extends StatefulWidget {
  const FormSharePage({super.key, required this.formId});

  final String formId;

  @override
  State<FormSharePage> createState() => _FormSharePageState();
}

class _FormSharePageState extends State<FormSharePage> {
  @override
  void initState() {
    super.initState();
    context.read<FormsBloc>().add(FormSelected(widget.formId));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseUrl = getIt<AppConfig>().publicBaseUrl;

    return BlocBuilder<FormsBloc, FormsState>(
      builder: (context, state) {
        final form = state.selected;
        if (form == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final link = '$baseUrl/f/${form.slug}';

        return Scaffold(
          backgroundColor: FelloColors.paper,
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: FadeSlideIn(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FelloBackButton(
                          onPressed: () => context.go('/forms/${form.id}'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Share form',
                        style: FelloTypography.pageTitle(context),
                      ),
                      const SizedBox(height: 20),
                      Text(form.title, style: theme.textTheme.headlineMedium),
                      const SizedBox(height: 8),
                      Text(
                        'Print this QR or share the link. Customers submit without an account.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 28),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: FelloColors.paper,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: FelloColors.border),
                        ),
                        child: Column(
                          children: [
                            QrImageView(
                              data: link,
                              size: 220,
                              backgroundColor: Colors.white,
                              eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: FelloColors.ink,
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: FelloColors.ink,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SelectableText(
                              link,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: FelloColors.accentDeep,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      await Clipboard.setData(
                                        ClipboardData(text: link),
                                      );
                                      if (context.mounted) {
                                        showKaydoToast(
                                          context,
                                          message: 'Link copied',
                                          tone: KaydoToastTone.success,
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.copy),
                                    label: const Text('Copy link'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () => context.go('/f/${form.slug}'),
                                    icon: const Icon(Icons.open_in_new),
                                    label: const Text('Preview'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tip: use your browser print dialog on this page for a printable QR.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
