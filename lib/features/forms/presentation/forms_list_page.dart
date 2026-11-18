import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/theme/fello_colors.dart';
import '../../../core/theme/fello_metrics.dart';
import '../../../core/theme/fello_typography.dart';
import '../../../domain/entities/feedback_form.dart';
import '../../../shared/animations/fade_slide_in.dart';
import '../../../shared/widgets/kaydo_search_field.dart';
import '../../../shared/widgets/kaydo_toast.dart';
import '../../../shared/widgets/pressable_scale.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../bloc/forms_bloc.dart';
import 'widgets/publish_success_dialog.dart';

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
    final visibleForms = forms.where((form) => !form.isDeleted);
    if (q.isEmpty) return visibleForms.toList(growable: false);
    return visibleForms.where((form) {
      final status = form.isPublished ? 'published' : 'draft';
      return form.title.toLowerCase().contains(q) ||
          form.description.toLowerCase().contains(q) ||
          form.slug.toLowerCase().contains(q) ||
          form.statusLabel.toLowerCase().contains(q) ||
          status.contains(q);
    }).toList();
  }

  Future<void> _confirmDelete(FeedbackForm form) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete survey?'),
        content: Text(
          '“${form.title}” will be marked Deleted and turned off. '
          'It stays in this list so you can still see it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: FelloColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    context.read<FormsBloc>().add(FormDeleteRequested(form.id));
  }

  void _toggleSurvey(FeedbackForm form) {
    final bloc = context.read<FormsBloc>();
    if (form.isPublished) {
      bloc.add(FormUnpublishRequested(form.id));
      showKaydoToast(
        context,
        message: 'Survey turned off',
        tone: KaydoToastTone.info,
      );
    } else if (form.isDeleted || form.status == FormStatus.draft) {
      if (form.questions.isEmpty) {
        showKaydoToast(
          context,
          message: 'Add at least one question before turning on.',
          tone: KaydoToastTone.error,
        );
        return;
      }
      bloc.add(FormPublishRequested(form));
      showKaydoToast(
        context,
        message: 'Survey turned on',
        tone: KaydoToastTone.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pad = FelloTypography.pagePadding(context);

    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          previous.session?.organization.id != current.session?.organization.id,
      listener: (context, state) {
        if (state.session != null) _load();
      },
      child: BlocBuilder<FormsBloc, FormsState>(
        builder: (context, state) {
          final visibleForms = state.forms
              .where((form) => !form.isDeleted)
              .toList();
          final filtered = _filtered(visibleForms);

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
                        trailing: SizedBox(
                          height: FelloMetrics.controlHeight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (visibleForms.isNotEmpty) ...[
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
                                const SizedBox(width: 12),
                              ],
                              FilledButton(
                                onPressed: () => context.go('/forms/new'),
                                style: FilledButton.styleFrom(
                                  minimumSize: Size.zero,
                                  maximumSize: FelloMetrics.controlMaxSize,
                                  padding: FelloMetrics.controlPaddingH,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.standard,
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add, size: 18),
                                    SizedBox(width: 8),
                                    Text('New survey'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (state.status == FormsStatus.loading && state.forms.isEmpty)
                  const SoftFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (visibleForms.isEmpty)
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
                        final isAdmin =
                            context
                                .watch<AuthBloc>()
                                .state
                                .session
                                ?.profile
                                .isAdmin ??
                            false;
                        return FadeSlideIn(
                          delay: Duration(milliseconds: 40 * index),
                          child: PressableScale(
                            onTap: () => context.go('/forms/${form.id}'),
                            child: _FormTile(
                              form: form,
                              canDelete: isAdmin && !form.isDeleted,
                              onToggle: () => _toggleSurvey(form),
                              onDelete: isAdmin && !form.isDeleted
                                  ? () => _confirmDelete(form)
                                  : null,
                              onShare: form.isPublished
                                  ? () => showPublishSuccessDialog(
                                      context: context,
                                      formTitle: form.title,
                                      link:
                                          '${getIt<AppConfig>().publicBaseUrl}/f/${form.slug}',
                                      isNewlyPublished: false,
                                    )
                                  : null,
                            ),
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
    return SliverFillRemaining(hasScrollBody: hasScrollBody, child: child);
  }
}

class _FormTile extends StatelessWidget {
  const _FormTile({
    required this.form,
    required this.canDelete,
    required this.onToggle,
    this.onDelete,
    this.onShare,
  });

  final FeedbackForm form;
  final bool canDelete;
  final VoidCallback onToggle;
  final VoidCallback? onDelete;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final compact = FelloTypography.isCompact(context);
    final (chipBg, chipFg, chipBorder) = switch (form.status) {
      FormStatus.published => (
        FelloColors.accentSoft,
        FelloColors.accentDeep,
        false,
      ),
      FormStatus.deleted => (
        const Color(0xFFFEE2E2),
        FelloColors.danger,
        false,
      ),
      FormStatus.draft => (FelloColors.paper, FelloColors.inkSoft, true),
    };

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 14 : 16,
        vertical: compact ? 12 : 14,
      ),
      decoration: BoxDecoration(
        color: form.isDeleted ? const Color(0xFFFAFAFA) : FelloColors.paper,
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
                  style: FelloTypography.listTitle(context).copyWith(
                    color: form.isDeleted
                        ? FelloColors.inkSoft
                        : FelloColors.ink,
                  ),
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
              color: chipBg,
              borderRadius: BorderRadius.circular(6),
              border: chipBorder ? Border.all(color: FelloColors.border) : null,
            ),
            child: Text(
              form.statusLabel,
              style: FelloTypography.chip(context).copyWith(color: chipFg),
            ),
          ),
          const SizedBox(width: 4),
          if (onShare != null)
            IconButton(
              tooltip: 'Share survey',
              onPressed: onShare,
              icon: const Icon(Icons.share_outlined, size: 20),
            ),
          PopupMenuButton<String>(
            tooltip: 'Survey actions',
            onSelected: (value) {
              switch (value) {
                case 'toggle':
                  onToggle();
                case 'delete':
                  onDelete?.call();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'toggle',
                child: Text(form.isPublished ? 'Turn off' : 'Turn on'),
              ),
              if (canDelete)
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
            icon: Icon(
              Icons.more_vert,
              size: compact ? 18 : 20,
              color: FelloColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}
