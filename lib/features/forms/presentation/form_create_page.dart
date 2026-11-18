import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/fello_colors.dart';
import '../../../core/theme/fello_metrics.dart';
import '../../../core/theme/fello_typography.dart';
import '../../../shared/animations/fade_slide_in.dart';
import '../../../shared/widgets/fello_back_button.dart';
import '../../../shared/widgets/fello_text_field.dart';
import '../../../shared/widgets/kaydo_toast.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../bloc/forms_bloc.dart';

/// Full-screen create flow (replaces the old dialog).
class FormCreatePage extends StatefulWidget {
  const FormCreatePage({super.key});

  @override
  State<FormCreatePage> createState() => _FormCreatePageState();
}

class _FormCreatePageState extends State<FormCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  bool _submitted = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  void _create() {
    if (!_formKey.currentState!.validate()) return;
    final orgId = context.read<AuthBloc>().state.session?.organization.id;
    if (orgId == null) return;
    setState(() => _submitted = true);
    context.read<FormsBloc>().add(
      FormCreateRequested(
        orgId: orgId,
        title: _title.text.trim(),
        description: _description.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pad = FelloTypography.pagePadding(context);

    return BlocConsumer<FormsBloc, FormsState>(
      listenWhen: (p, c) =>
          _submitted &&
          ((p.status == FormsStatus.saving &&
                  c.status == FormsStatus.ready &&
                  c.selected != null) ||
              (c.errorMessage != null && c.errorMessage != p.errorMessage)),
      listener: (context, state) {
        if (state.errorMessage != null) {
          setState(() => _submitted = false);
          showKaydoToast(
            context,
            message: state.errorMessage!,
            tone: KaydoToastTone.error,
          );
          return;
        }
        final selected = state.selected;
        if (selected != null) {
          context.go('/forms/${selected.id}');
        }
      },
      builder: (context, state) {
        final busy = state.status == FormsStatus.saving;

        return Scaffold(
          backgroundColor: FelloColors.paper,
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(pad, 12, pad, 24),
                  child: FadeSlideIn(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: FelloBackButton(
                              tooltip: 'Back to forms',
                              onPressed: busy
                                  ? null
                                  : () => context.go('/forms'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'New feedback form',
                            style: FelloTypography.pageTitle(context),
                          ),
                          const SizedBox(height: 28),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: FelloColors.paper,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: FelloColors.border),
                            ),
                            child: Column(
                              children: [
                                FelloTextField(
                                  label: 'Title',
                                  controller: _title,
                                  autofocus: true,
                                  textInputAction: TextInputAction.next,
                                  validator: (v) =>
                                      v == null || v.trim().isEmpty
                                      ? 'Enter a title'
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                FelloTextField(
                                  label: 'Description (optional)',
                                  controller: _description,
                                  maxLines: 4,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Material(
                color: FelloColors.paper,
                elevation: 8,
                shadowColor: FelloColors.ink.withValues(alpha: 0.08),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(pad, 12, pad, 12),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final buttonWidth = (constraints.maxWidth * 0.22).clamp(
                          FelloMetrics.buttonMinWidth,
                          200.0,
                        );
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            SizedBox(
                              width: buttonWidth,
                              height: FelloMetrics.controlHeight,
                              child: OutlinedButton(
                                onPressed: busy
                                    ? null
                                    : () => context.go('/forms'),
                                child: const Text(
                                  'Cancel',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: buttonWidth,
                              height: FelloMetrics.controlHeight,
                              child: FilledButton(
                                onPressed: busy ? null : _create,
                                child: busy
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Create form',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
