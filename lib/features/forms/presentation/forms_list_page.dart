import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/fello_colors.dart';
import '../../../core/theme/fello_metrics.dart';
import '../../../core/theme/fello_typography.dart';
import '../../../domain/entities/feedback_form.dart';
import '../../../shared/animations/fade_slide_in.dart';
import '../../../shared/widgets/kaydo_search_field.dart';
import '../../../shared/widgets/pressable_scale.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../bloc/forms_bloc.dart';

class FormsListPage extends StatefulWidget {
  const FormsListPage({super.key});

  @override
  State<FormsListPage> createState() => _FormsListPageState();
}

class _FormsListPageState extends State<FormsListPage> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final orgId = context.read<AuthBloc>().state.session?.organization.id;
    if (orgId == null) return;
    final formsState = context.read<FormsBloc>().state;
    if (formsState.orgId == orgId &&
        (formsState.status == FormsStatus.loading ||
            formsState.status == FormsStatus.ready)) {
      return;
    }
    context.read<FormsBloc>().add(FormsLoadRequested(orgId));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<FeedbackForm> _filtered(List<FeedbackForm> forms) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return forms;
    return forms.where((form) {
      final status = form.isPublished ? 'published' : 'draft';
      return form.title.toLowerCase().contains(q) ||
          form.description.toLowerCase().contains(q) ||
          form.slug.toLowerCase().contains(q) ||
          status.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pad = FelloTypography.pagePadding(context);

    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          previous.session?.organization.id !=
          current.session?.organization.id,
      listener: (context, state) {
        if (state.session != null) _load();
      },
      child: BlocBuilder<FormsBloc, FormsState>(
        builder: (context, state) {
          final filtered = _filtered(state.forms);

        return Scaffold(
          backgroundColor: FelloColors.paper,
          body: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(pad, pad, pad, 8),
                sliver: SliverToBoxAdapter(
                  child: FadeSlideIn(
                    child: FelloPageHeader(
                      title: 'Survey',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: FelloMetrics.controlHeight,
                            child: FilledButton.icon(
                              onPressed: () => context.go('/forms/new'),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('New survey'),
                            ),
                          ),
                          if (state.forms.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            KaydoSearchField(
                              controller: _search,
                              hintText: 'Search surveys',
                              onChanged: (value) =>
                                  setState(() => _query = value),
                              onClear: () {
                                _search.clear();
                                setState(() => _query = '');
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (state.status == FormsStatus.loading && state.forms.isEmpty)
                const SoftFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (state.forms.isEmpty)
                SoftFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: FadeSlideIn(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.dynamic_form_outlined,
                            size: 40,
                            color: FelloColors.chartMuted,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'No surveys yet',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Create your first feedback survey.',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 14),
                          FilledButton(
                            onPressed: () => context.go('/forms/new'),
                            child: const Text('Create survey'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (filtered.isEmpty)
                SoftFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: FadeSlideIn(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.search_off_rounded,
                            size: 40,
                            color: FelloColors.chartMuted,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'No surveys match your search',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Try a different title, description, or status.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(pad, 4, pad, 100),
                  sliver: SliverList.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final form = filtered[index];
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
      ),
    );
  }
}

class SoftFillRemaining extends StatelessWidget {
  const SoftFillRemaining({
    super.key,
    required this.child,
    this.hasScrollBody = true,
  });

  final Widget child;
  final bool hasScrollBody;

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: hasScrollBody,
      child: child,
    );
  }
}

class _FormTile extends StatelessWidget {
  const _FormTile({required this.form});

  final FeedbackForm form;

  @override
  Widget build(BuildContext context) {
    final published = form.isPublished;
    final compact = FelloTypography.isCompact(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 14 : 16,
        vertical: compact ? 12 : 14,
      ),
      decoration: BoxDecoration(
        color: FelloColors.paper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FelloColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  form.title,
                  style: FelloTypography.listTitle(context),
                ),
                const SizedBox(height: 2),
                Text(
                  form.description.isEmpty
                      ? '${form.questions.length} questions'
                      : form.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: FelloTypography.listBody(context),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: published ? FelloColors.accentSoft : FelloColors.paper,
              borderRadius: BorderRadius.circular(6),
              border: published
                  ? null
                  : Border.all(color: FelloColors.border),
            ),
            child: Text(
              published ? 'Published' : 'Draft',
              style: FelloTypography.chip(context).copyWith(
                color: published ? FelloColors.accentDeep : FelloColors.inkSoft,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            Icons.chevron_right,
            size: compact ? 18 : 20,
            color: FelloColors.chartMuted,
          ),
        ],
      ),
    );
  }
}
