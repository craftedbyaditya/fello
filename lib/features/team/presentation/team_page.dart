import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/config/app_config.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/theme/fello_colors.dart';
import '../../../domain/entities/org_invite.dart';
import '../../../domain/entities/profile.dart';
import '../../../domain/repositories/team_repository.dart';
import '../../../shared/widgets/fello_text_field.dart';
import '../../../shared/widgets/kaydo_search_field.dart';
import '../../../shared/widgets/kaydo_toast.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../bloc/team_bloc.dart';

class TeamPage extends StatelessWidget {
  const TeamPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthBloc>().state.session;
    if (session == null || !session.profile.isAdmin) {
      return const _AdminOnlyGate();
    }

    return BlocProvider(
      create: (_) => TeamBloc(getIt<TeamRepository>())
        ..add(TeamLoadRequested(session.organization.id)),
      child: const _TeamView(),
    );
  }
}

class _AdminOnlyGate extends StatelessWidget {
  const _AdminOnlyGate();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Only admins can manage the team.',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('Back to dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamView extends StatefulWidget {
  const _TeamView();

  @override
  State<_TeamView> createState() => _TeamViewState();
}

class _TeamViewState extends State<_TeamView> {
  final _emailController = TextEditingController();
  final _searchController = TextEditingController();
  final _emails = <String>{};
  String _query = '';

  @override
  void dispose() {
    _emailController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _addEmailsFromField() {
    final raw = _emailController.text;
    final parts = raw.split(RegExp(r'[,;\s]+'));
    var added = false;
    for (final part in parts) {
      final email = part.trim().toLowerCase();
      if (email.contains('@') && email.contains('.')) {
        _emails.add(email);
        added = true;
      }
    }
    if (added) {
      setState(() => _emailController.clear());
    }
  }

  void _submitInvites() {
    _addEmailsFromField();
    if (_emails.isEmpty) {
      showKaydoToast(
        context,
        message: 'Add at least one email address.',
        tone: KaydoToastTone.error,
      );
      return;
    }
    context.read<TeamBloc>().add(TeamInvitesSubmitted(_emails.toList()));
  }

  List<_TeamRow> _rows(TeamState state) {
    final rows = <_TeamRow>[
      for (final m in state.members)
        _TeamRow.member(m),
      for (final i in state.pendingInvites)
        _TeamRow.invite(i),
    ];
    rows.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return rows;
    return rows
        .where(
          (r) =>
              r.title.toLowerCase().contains(q) ||
              r.subtitle.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseUrl = getIt<AppConfig>().publicBaseUrl;
    final dateFormat = DateFormat.yMMMd();

    return BlocConsumer<TeamBloc, TeamState>(
      listenWhen: (p, c) =>
          p.errorMessage != c.errorMessage ||
          p.infoMessage != c.infoMessage ||
          p.lastCreatedInvites != c.lastCreatedInvites,
      listener: (context, state) {
        if (state.errorMessage != null) {
          showKaydoToast(
            context,
            message: state.errorMessage!,
            tone: KaydoToastTone.error,
          );
        } else if (state.infoMessage != null) {
          showKaydoToast(
            context,
            message: state.infoMessage!,
            tone: KaydoToastTone.success,
          );
          if (state.lastCreatedInvites.isNotEmpty) {
            setState(() => _emails.clear());
          }
        }
      },
      builder: (context, state) {
        final busy = state.status == TeamStatus.loading ||
            state.status == TeamStatus.saving;
        final rows = _rows(state);

        return ListView(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 48),
          children: [
            Text('Team', style: theme.textTheme.headlineLarge),
            const SizedBox(height: 24),

            // Row 1 — invite
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: FelloColors.paper,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: FelloColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Invite',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_emails.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final email in _emails)
                          InputChip(
                            label: Text(email),
                            onDeleted: busy
                                ? null
                                : () => setState(() => _emails.remove(email)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: FelloTextField(
                          controller: _emailController,
                          enabled: !busy,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          onChanged: (value) {
                            if (value.contains(',') ||
                                value.contains(';') ||
                                value.contains(' ')) {
                              _addEmailsFromField();
                            }
                          },
                          onFieldSubmitted: (_) {
                            _addEmailsFromField();
                            _submitInvites();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: busy ? null : _submitInvites,
                        child: busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Send'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Row 2 — search + people
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: FelloColors.paper,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: FelloColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'People',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  KaydoSearchField(
                    controller: _searchController,
                    hintText: 'Search',
                    width: null,
                    onChanged: (v) => setState(() => _query = v),
                    onClear: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                  ),
                  const SizedBox(height: 16),
                  if (state.status == TeamStatus.loading &&
                      state.members.isEmpty &&
                      state.pendingInvites.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (rows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        _query.isEmpty
                            ? 'No people yet.'
                            : 'No matches.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: FelloColors.inkSoft,
                        ),
                      ),
                    )
                  else
                    ...rows.map(
                      (row) => _PersonTile(
                        row: row,
                        dateLabel: dateFormat.format(row.addedAt.toLocal()),
                        busy: busy,
                        onCopyInvite: row.invite == null
                            ? null
                            : () async {
                                final link =
                                    '$baseUrl/invite/${row.invite!.token}';
                                await Clipboard.setData(
                                  ClipboardData(text: link),
                                );
                                if (context.mounted) {
                                  showKaydoToast(
                                    context,
                                    message: 'Invite link copied',
                                    tone: KaydoToastTone.success,
                                  );
                                }
                              },
                        onRevokeInvite: row.invite == null
                            ? null
                            : () => context.read<TeamBloc>().add(
                                  TeamInviteRevokeRequested(row.invite!.id),
                                ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TeamRow {
  const _TeamRow._({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.addedAt,
    this.invite,
  });

  factory _TeamRow.member(Profile member) {
    return _TeamRow._(
      title: member.displayName.isEmpty ? member.email : member.displayName,
      subtitle: member.email,
      status: member.isAdmin ? 'Admin' : 'Active',
      addedAt: member.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  factory _TeamRow.invite(OrgInvite invite) {
    return _TeamRow._(
      title: invite.email,
      subtitle: 'Invite pending',
      status: 'Pending',
      addedAt: invite.createdAt,
      invite: invite,
    );
  }

  final String title;
  final String subtitle;
  final String status;
  final DateTime addedAt;
  final OrgInvite? invite;
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({
    required this.row,
    required this.dateLabel,
    required this.busy,
    this.onCopyInvite,
    this.onRevokeInvite,
  });

  final _TeamRow row;
  final String dateLabel;
  final bool busy;
  final VoidCallback? onCopyInvite;
  final VoidCallback? onRevokeInvite;

  @override
  Widget build(BuildContext context) {
    final pending = row.invite != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: FelloColors.paper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FelloColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: FelloColors.accentSoft,
            child: Text(
              row.title.isEmpty ? '?' : row.title[0].toUpperCase(),
              style: const TextStyle(
                color: FelloColors.accentDeep,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: FelloColors.ink,
                  ),
                ),
                if (row.subtitle.isNotEmpty)
                  Text(
                    row.subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: FelloColors.inkSoft,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  'Added $dateLabel',
                  style: const TextStyle(
                    fontSize: 12,
                    color: FelloColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: pending
                  ? const Color(0xFFFFF1E8)
                  : FelloColors.accentSoft,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: FelloColors.border),
            ),
            child: Text(
              row.status,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: pending
                    ? FelloColors.danger
                    : FelloColors.accentDeep,
              ),
            ),
          ),
          if (pending) ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Copy invite link',
              onPressed: busy ? null : onCopyInvite,
              icon: const Icon(Icons.link, size: 18),
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              tooltip: 'Revoke',
              onPressed: busy ? null : onRevokeInvite,
              icon: const Icon(
                Icons.close,
                size: 18,
                color: FelloColors.danger,
              ),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
    );
  }
}
