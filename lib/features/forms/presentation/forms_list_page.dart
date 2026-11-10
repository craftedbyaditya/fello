import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/fello_colors.dart';
import '../../../domain/entities/feedback_form.dart';
import '../../../shared/animations/fade_slide_in.dart';
import '../../../shared/widgets/pressable_scale.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../bloc/forms_bloc.dart';

class FormsListPage extends StatefulWidget {
  const FormsListPage({super.key});

  @override
  State<FormsListPage> createState() => _FormsListPageState();
}

class _FormsListPageState extends State<FormsListPage> {
  @override
  void initState() {
    super.initState();
    final orgId = context.read<AuthBloc>().state.session?.organization.id;
    if (orgId != null) {
      context.read<FormsBloc>().add(FormsLoadRequested(orgId));
    }
  }

  Future<void> _createForm() async {
    final orgId = context.read<AuthBloc>().state.session?.organization.id;
    if (orgId == null) return;
    final title = TextEditingController();
    final description = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New feedback form'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'Title'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: description,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (title.text.trim().isEmpty) return;
              Navigator.pop(context, true);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (created == true && mounted) {
      context.read<FormsBloc>().add(
            FormCreateRequested(
              orgId: orgId,
              title: title.text,
              description: description.text,
            ),
          );
    }
    title.dispose();
    description.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocConsumer<FormsBloc, FormsState>(
      listenWhen: (p, c) =>
          p.status == FormsStatus.saving &&
          c.status == FormsStatus.ready &&
          c.selected != null,
      listener: (context, state) {
        final selected = state.selected;
        if (selected != null) {
          context.go('/forms/${selected.id}');
        }
      },
      builder: (context, state) {
        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _createForm,
            icon: const Icon(Icons.add),
            label: const Text('New form'),
          ),
          body: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                sliver: SliverToBoxAdapter(
                  child: FadeSlideIn(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Forms', style: theme.textTheme.headlineLarge),
                        const SizedBox(height: 6),
                        Text(
                          'Build questions, publish, then share a link or QR code.',
                          style: theme.textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (state.status == FormsStatus.loading && state.forms.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (state.forms.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: FadeSlideIn(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.dynamic_form_outlined,
                            size: 48,
                            color: FelloColors.chartMuted,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No forms yet',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          const Text('Create your first feedback form.'),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _createForm,
                            child: const Text('Create form'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
                  sliver: SliverList.separated(
                    itemCount: state.forms.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final form = state.forms[index];
                      return FadeSlideIn(
                        delay: Duration(milliseconds: 40 * index),
                        child: PressableScale(
                          onTap: () => context.go('/forms/${form.id}'),
                          child: _FormTile(form: form),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _FormTile extends StatelessWidget {
  const _FormTile({required this.form});

  final FeedbackForm form;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final published = form.isPublished;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FelloColors.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FelloColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(form.title, style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  form.description.isEmpty
                      ? '${form.questions.length} questions'
                      : form.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: published
                  ? FelloColors.accentSoft
                  : FelloColors.mist,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              published ? 'Published' : 'Draft',
              style: theme.textTheme.labelLarge?.copyWith(
                color: published
                    ? FelloColors.accentDeep
                    : FelloColors.inkSoft,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: FelloColors.chartMuted),
        ],
      ),
    );
  }
}
