import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/config/app_config.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/theme/fello_colors.dart';
import '../../../core/theme/fello_metrics.dart';
import '../../../domain/entities/org_invite.dart';
import '../../../domain/entities/profile.dart';
import '../../../domain/repositories/team_repository.dart';
import '../../../shared/widgets/fello_text_field.dart';
import '../../../shared/widgets/kaydo_search_field.dart';
import '../../../shared/widgets/kaydo_toast.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../bloc/team_bloc.dart';

class TeamPage extends StatelessWidget {
  const TeamPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthBloc>().state.session;
    if (session == null || !session.profile.isAdmin) {
      return const _AdminOnlyGate();
    }

    return BlocProvider(
      create: (_) =>
          TeamBloc(getIt<TeamRepository>())
            ..add(TeamLoadRequested(session.organization.id)),
      child: _TeamView(embedded: embedded),
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
  const _TeamView({required this.embedded});

  final bool embedded;

  @override
  State<_TeamView> createState() => _TeamViewState();
}

class _TeamViewState extends State<_TeamView> {
  final _emailController = TextEditingController();
  final _searchController = TextEditingController();
  final _emails = <String>{};
  String _query = '';
  int _page = 0;
  static const _pageSize = 8;

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
      for (final m in state.members) _TeamRow.member(m),
      for (final i in state.pendingInvites) _TeamRow.invite(i),
    ];
    rows.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return rows;
    return rows
        .where(
          (r) =>
              r.title.toLowerCase().contains(q) ||
              r.subtitle.toLowerCase().contains(q) ||
              r.role.toLowerCase().contains(q) ||
              r.status.toLowerCase().contains(q),
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
        final busy =
            state.status == TeamStatus.loading ||
            state.status == TeamStatus.saving;
        final rows = _rows(state);

        return Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.embedded) ...[
                Text('Team', style: theme.textTheme.headlineLarge),
                const SizedBox(height: 24),
              ],

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
                    SizedBox(
                      height: FelloMetrics.controlHeight,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                            style: FilledButton.styleFrom(
                              minimumSize: Size.zero,
                              maximumSize: FelloMetrics.controlMaxSize,
                              padding: FelloMetrics.controlPaddingH,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.standard,
                            ),
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
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Row 2 — people fills remaining viewport height
              Expanded(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  decoration: BoxDecoration(
                    color: FelloColors.paper,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: FelloColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'People',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 260,
                            child: KaydoSearchField(
                              controller: _searchController,
                              hintText: 'Search',
                              width: null,
                              onChanged: (v) => setState(() {
                                _query = v;
                                _page = 0;
                              }),
                              onClear: () {
                                _searchController.clear();
                                setState(() {
                                  _query = '';
                                  _page = 0;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (state.status == TeamStatus.loading &&
                          state.members.isEmpty &&
                          state.pendingInvites.isEmpty)
                        const Expanded(
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (rows.isEmpty)
                        Expanded(
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: Text(
                              _query.isEmpty ? 'No people yet.' : 'No matches.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: FelloColors.inkSoft,
                              ),
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: _PeopleTable(
                            rows: rows,
                            page: _page,
                            pageSize: _pageSize,
                            dateFormat: dateFormat,
                            busy: busy,
                            onPageChanged: (p) => setState(() => _page = p),
                            onCopyInvite: (invite) async {
                              final link = '$baseUrl/invite/${invite.token}';
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
                            onRevokeInvite: (invite) => context
                                .read<TeamBloc>()
                                .add(TeamInviteRevokeRequested(invite.id)),
                            onView: (row) =>
                                _showPersonSheet(context, row, dateFormat),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPersonSheet(
    BuildContext context,
    _TeamRow row,
    DateFormat dateFormat,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                row.subtitle,
                style: const TextStyle(color: FelloColors.inkSoft),
              ),
              const SizedBox(height: 12),
              Text('Role: ${row.role}'),
              Text('Status: ${row.status}'),
              Text('Added: ${dateFormat.format(row.addedAt.toLocal())}'),
            ],
          ),
        );
      },
    );
  }
}

class _TeamRow {
  const _TeamRow._({
    required this.title,
    required this.subtitle,
    required this.role,
    required this.status,
    required this.addedAt,
    this.invite,
  });

  factory _TeamRow.member(Profile member) {
    return _TeamRow._(
      title: member.displayName.isEmpty ? member.email : member.displayName,
      subtitle: member.email,
      role: member.roleLabel,
      status: 'Active',
      addedAt: member.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  factory _TeamRow.invite(OrgInvite invite) {
    return _TeamRow._(
      title: invite.email,
      subtitle: 'Invitation sent',
      role: invite.role == ProfileRole.admin ? 'Admin' : 'Employee',
      status: 'Pending',
      addedAt: invite.createdAt,
      invite: invite,
    );
  }

  final String title;
  final String subtitle;
  final String role;
  final String status;
  final DateTime addedAt;
  final OrgInvite? invite;

  bool get isPending => invite != null;
}

class _PeopleTable extends StatelessWidget {
  const _PeopleTable({
    required this.rows,
    required this.page,
    required this.pageSize,
    required this.dateFormat,
    required this.busy,
    required this.onPageChanged,
    required this.onCopyInvite,
    required this.onRevokeInvite,
    required this.onView,
  });

  final List<_TeamRow> rows;
  final int page;
  final int pageSize;
  final DateFormat dateFormat;
  final bool busy;
  final ValueChanged<int> onPageChanged;
  final Future<void> Function(OrgInvite invite) onCopyInvite;
  final ValueChanged<OrgInvite> onRevokeInvite;
  final ValueChanged<_TeamRow> onView;

  @override
  Widget build(BuildContext context) {
    final totalPages = (rows.length / pageSize).ceil().clamp(1, 9999);
    final safePage = page.clamp(0, totalPages - 1);
    final start = safePage * pageSize;
    final pageRows = rows.skip(start).take(pageSize).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _TableHeader(),
        const Divider(height: 1, color: FelloColors.border),
        Expanded(
          child: ListView.builder(
            itemCount: pageRows.length,
            itemBuilder: (context, index) {
              final row = pageRows[index];
              return _TableRow(
                row: row,
                dateLabel: dateFormat.format(row.addedAt.toLocal()),
                busy: busy,
                onView: () => onView(row),
                onCopyInvite: row.invite == null
                    ? null
                    : () => onCopyInvite(row.invite!),
                onRevokeInvite: row.invite == null
                    ? null
                    : () => onRevokeInvite(row.invite!),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        _TablePagination(
          page: safePage,
          totalPages: totalPages,
          onPageChanged: onPageChanged,
        ),
      ],
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: Color(0xFF8FA39A),
      letterSpacing: 0.2,
    );
    return const Padding(
      padding: EdgeInsets.fromLTRB(8, 4, 8, 12),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text('Name / Email', style: style)),
          Expanded(flex: 2, child: Text('Role', style: style)),
          Expanded(flex: 2, child: Text('Joined', style: style)),
          Expanded(flex: 2, child: Text('Status', style: style)),
          SizedBox(width: 96),
        ],
      ),
    );
  }
}

class _TableRow extends StatefulWidget {
  const _TableRow({
    required this.row,
    required this.dateLabel,
    required this.busy,
    required this.onView,
    this.onCopyInvite,
    this.onRevokeInvite,
  });

  final _TeamRow row;
  final String dateLabel;
  final bool busy;
  final VoidCallback onView;
  final VoidCallback? onCopyInvite;
  final VoidCallback? onRevokeInvite;

  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final pending = row.isPending;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _hovered ? FelloColors.accentSoft.withValues(alpha: 0.55) : null,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          children: [
            Expanded(
              flex: 4,
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
                        fontSize: 13,
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: FelloColors.ink,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          row.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: FelloColors.accentDeep,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                row.role,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: FelloColors.ink,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                widget.dateLabel,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: FelloColors.ink,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                row.status,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: pending
                      ? const Color(0xFFC2410C)
                      : FelloColors.inkSoft,
                ),
              ),
            ),
            SizedBox(
              width: 96,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AnimatedOpacity(
                    opacity: _hovered ? 1 : 0,
                    duration: const Duration(milliseconds: 120),
                    child: IgnorePointer(
                      ignoring: !_hovered,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilledButton(
                          onPressed: widget.onView,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(52, 32),
                            maximumSize: const Size(64, 32),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            shape: const StadiumBorder(),
                          ),
                          child: const Text(
                            'View',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'More',
                    onSelected: (value) {
                      switch (value) {
                        case 'view':
                          widget.onView();
                        case 'copy':
                          widget.onCopyInvite?.call();
                        case 'revoke':
                          widget.onRevokeInvite?.call();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'view', child: Text('View')),
                      if (pending) ...[
                        const PopupMenuItem(
                          value: 'copy',
                          child: Text('Copy invite link'),
                        ),
                        PopupMenuItem(
                          value: 'revoke',
                          enabled: !widget.busy,
                          child: const Text('Revoke invite'),
                        ),
                      ],
                    ],
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        shape: BoxShape.circle,
                        border: Border.all(color: FelloColors.border),
                      ),
                      child: const Icon(
                        Icons.more_horiz,
                        size: 18,
                        color: FelloColors.inkSoft,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TablePagination extends StatelessWidget {
  const _TablePagination({
    required this.page,
    required this.totalPages,
    required this.onPageChanged,
  });

  final int page;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          'Page 1 of 1',
          style: TextStyle(fontSize: 12.5, color: FelloColors.inkSoft),
        ),
      );
    }

    final pages = <int>[];
    for (var i = 0; i < totalPages && i < 5; i++) {
      pages.add(i);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Text(
            'Page ${page + 1} of $totalPages',
            style: const TextStyle(fontSize: 12.5, color: FelloColors.inkSoft),
          ),
          const Spacer(),
          _PageIcon(
            icon: Icons.keyboard_double_arrow_left,
            onTap: page > 0 ? () => onPageChanged(0) : null,
          ),
          _PageIcon(
            icon: Icons.chevron_left,
            onTap: page > 0 ? () => onPageChanged(page - 1) : null,
          ),
          for (final p in pages)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                onTap: () => onPageChanged(p),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p == page ? FelloColors.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${p + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: p == page ? Colors.white : FelloColors.inkSoft,
                    ),
                  ),
                ),
              ),
            ),
          _PageIcon(
            icon: Icons.chevron_right,
            onTap: page < totalPages - 1 ? () => onPageChanged(page + 1) : null,
          ),
          _PageIcon(
            icon: Icons.keyboard_double_arrow_right,
            onTap: page < totalPages - 1
                ? () => onPageChanged(totalPages - 1)
                : null,
          ),
        ],
      ),
    );
  }
}

class _PageIcon extends StatelessWidget {
  const _PageIcon({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      color: onTap == null ? FelloColors.chartMuted : FelloColors.inkSoft,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      padding: EdgeInsets.zero,
    );
  }
}
