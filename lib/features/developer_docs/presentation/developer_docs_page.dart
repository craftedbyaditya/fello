import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/config/app_config.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/theme/fello_colors.dart';
import '../../../core/theme/fello_metrics.dart';
import '../../../domain/entities/org_api_key.dart';
import '../../../domain/repositories/developer_api_repository.dart';
import '../../../shared/widgets/fello_text_field.dart';
import '../../../shared/widgets/kaydo_toast.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../bloc/developer_docs_bloc.dart';

class DeveloperDocsPage extends StatelessWidget {
  const DeveloperDocsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthBloc>().state.session;
    if (session == null) {
      return const Center(child: Text('Sign in required.'));
    }

    final paid = session.organization.plan.allowsReviewsApi;

    return BlocProvider(
      create: (_) {
        final bloc = DeveloperDocsBloc(getIt<DeveloperApiRepository>());
        if (paid) {
          bloc.add(const DeveloperDocsLoadRequested());
        }
        return bloc;
      },
      child: _DeveloperDocsView(
        isAdmin: session.profile.isAdmin,
        paid: paid,
        orgName: session.organization.name,
      ),
    );
  }
}

class _DeveloperDocsView extends StatefulWidget {
  const _DeveloperDocsView({
    required this.isAdmin,
    required this.paid,
    required this.orgName,
  });

  final bool isAdmin;
  final bool paid;
  final String orgName;

  @override
  State<_DeveloperDocsView> createState() => _DeveloperDocsViewState();
}

class _DeveloperDocsViewState extends State<_DeveloperDocsView> {
  final _scrollController = ScrollController();
  final _overviewKey = GlobalKey();
  final _keysKey = GlobalKey();
  final _reviewsKey = GlobalKey();
  final _examplesKey = GlobalKey();
  final _errorsKey = GlobalKey();
  final _limitsKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _scrollTo(GlobalKey key) async {
    final ctx = key.currentContext;
    if (ctx == null) return;
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      alignment: 0.05,
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = getIt<AppConfig>();
    final apiBase = config.supabaseUrl.isEmpty
        ? 'https://YOUR_PROJECT.supabase.co/functions/v1'
        : '${config.supabaseUrl.replaceAll(RegExp(r'/+$'), '')}/functions/v1';
    final endpoint = '$apiBase/reviews-api';
    final width = MediaQuery.sizeOf(context).width;

    return BlocListener<DeveloperDocsBloc, DeveloperDocsState>(
      listenWhen: (p, c) =>
          p.errorMessage != c.errorMessage ||
          p.infoMessage != c.infoMessage ||
          p.newlyCreatedSecret != c.newlyCreatedSecret,
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
        }
      },
      child: ColoredBox(
        color: FelloColors.paper,
        child: ListView(
          controller: _scrollController,
          padding: EdgeInsets.fromLTRB(
            width >= 960 ? 28 : 20,
            28,
            width >= 960 ? 28 : 20,
            64,
          ),
          children: [
            Text(
              'Getting Started with Kaydo',
              style: GoogleFonts.poppins(
                fontSize: width >= 960 ? 40 : 32,
                fontWeight: FontWeight.w700,
                height: 1.15,
                color: FelloColors.ink,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'This guide helps you connect the Kaydo Reviews API to your own '
              'website or product — fetch approved public reviews as JSON and '
              'render them however you like.',
              style: GoogleFonts.poppins(
                fontSize: 16,
                height: 1.55,
                fontWeight: FontWeight.w400,
                color: FelloColors.inkSoft,
              ),
            ),
            const SizedBox(height: 36),
            Text(
              'Start here',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: FelloColors.ink,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Mark reviews Public in Reviews, generate an API key on Pro, '
              'then call GET reviews from your backend with the X-API-Key header.',
              style: _bodyStyle,
            ),
            const SizedBox(height: 10),
            Text(
              'Only customer-submitted feedback that an admin has approved for '
              'public use is returned. Private reviews never leave Kaydo.',
              style: _bodyStyle,
            ),
            if (!widget.paid) ...[
              const SizedBox(height: 24),
              _UpgradeGate(orgName: widget.orgName),
            ],
            const SizedBox(height: 36),
            _DocLinkRow(
              title: 'What is the Reviews API?',
              onTap: () => _scrollTo(_overviewKey),
            ),
            _DocLinkRow(
              title: 'How it works',
              onTap: () => _scrollTo(_reviewsKey),
            ),
            _DocLinkRow(
              title: 'Quick start',
              onTap: () => _scrollTo(_keysKey),
              showDivider: false,
            ),
            const SizedBox(height: 40),
            Text(
              'Categories',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: FelloColors.ink,
              ),
            ),
            const SizedBox(height: 16),
            _CategoryGrid(
              wide: width >= 700,
              items: [
                _CategoryItem(
                  icon: Icons.home_rounded,
                  title: 'Getting Started',
                  body: 'Overview of the API, consent rules, and what approved public reviews include.',
                  onTap: () => _scrollTo(_overviewKey),
                ),
                _CategoryItem(
                  icon: Icons.menu_book_rounded,
                  title: 'API Keys',
                  body: 'Generate, copy once, and revoke keys. Keep secrets on your server only.',
                  onTap: () => _scrollTo(_keysKey),
                ),
                _CategoryItem(
                  icon: Icons.grid_view_rounded,
                  title: 'Reviews endpoint',
                  body: 'GET parameters, response fields, pagination cursors, and example JSON.',
                  onTap: () => _scrollTo(_reviewsKey),
                ),
                _CategoryItem(
                  icon: Icons.people_alt_rounded,
                  title: 'Examples & limits',
                  body: 'cURL, JavaScript, and Python samples plus rate limits and error codes.',
                  onTap: () => _scrollTo(_examplesKey),
                ),
              ],
            ),
            const SizedBox(height: 48),
            const Divider(color: FelloColors.border, height: 1),
            const SizedBox(height: 40),

            // —— Detail sections ——
            _DocHeading('Overview', key: _overviewKey),
            const SizedBox(height: 12),
            Text(
              'The Reviews API returns customer feedback submitted on your public '
              'survey forms (customer consent) and marked Public by an admin '
              '(admin approval).',
              style: _bodyStyle,
            ),
            const SizedBox(height: 16),
            _CopyRow(label: 'Base URL', value: apiBase),
            const SizedBox(height: 8),
            _CopyRow(label: 'Endpoint', value: 'GET $endpoint'),
            const SizedBox(height: 12),
            Text(
              'Authenticate every request with the X-API-Key header. '
              'Do not expose keys in browsers — call from your own backend.',
              style: _bodyStyle,
            ),

            const SizedBox(height: 40),
            _DocHeading('API Keys', key: _keysKey),
            const SizedBox(height: 12),
            if (widget.paid)
              _ApiKeysPanel(isAdmin: widget.isAdmin)
            else
              Text('Upgrade to Pro to generate API keys.', style: _bodyStyle),

            const SizedBox(height: 40),
            _DocHeading('GET Reviews', key: _reviewsKey),
            const SizedBox(height: 12),
            Text('HTTP method: GET', style: _bodyStyle),
            const SizedBox(height: 8),
            _CopyRow(label: 'URL', value: endpoint),
            const SizedBox(height: 10),
            Text(
              'Required header: X-API-Key: <your_api_key>',
              style: _bodyStyle,
            ),
            const SizedBox(height: 6),
            Text(
              'Optional query: limit (1–100, default 20), cursor (opaque pagination token).',
              style: _bodyStyle,
            ),
            const SizedBox(height: 16),
            Text(
              'Example response',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: FelloColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            _CodeBlock(_exampleJson),
            const SizedBox(height: 10),
            Text(
              'Fields: id, form_id, form_title, form_slug, published_at, '
              'rating, comment, pagination. Only explicitly published review '
              'text is returned; submitted answers are never exposed.',
              style: _bodyStyle,
            ),

            const SizedBox(height: 40),
            _DocHeading('Code Examples', key: _examplesKey),
            const SizedBox(height: 14),
            Text(
              'cURL',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: FelloColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            _CodeBlock(
              "curl -sS '$endpoint?limit=20' \\\n"
              "  -H 'X-API-Key: YOUR_API_KEY'",
            ),
            const SizedBox(height: 16),
            Text(
              'JavaScript (server-side fetch)',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: FelloColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            _CodeBlock(
              "const res = await fetch('$endpoint?limit=20', {\n"
              "  headers: { 'X-API-Key': process.env.KAYDO_API_KEY },\n"
              "});\n"
              'const body = await res.json();\n'
              'console.log(body.data);',
            ),
            const SizedBox(height: 16),
            Text(
              'Python (requests)',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: FelloColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            _CodeBlock(
              'import os, requests\n\n'
              "r = requests.get(\n"
              "    '$endpoint',\n"
              "    headers={'X-API-Key': os.environ['KAYDO_API_KEY']},\n"
              '    params={"limit": 20},\n'
              ')\nr.raise_for_status()\nprint(r.json()["data"])',
            ),

            const SizedBox(height: 40),
            _DocHeading('Errors', key: _errorsKey),
            const SizedBox(height: 12),
            Text(
              '401 — Missing or invalid API key (including revoked keys).',
              style: _bodyStyle,
            ),
            const SizedBox(height: 8),
            Text(
              '403 — Pro plan required or access denied.',
              style: _bodyStyle,
            ),
            const SizedBox(height: 8),
            Text(
              '429 — Rate limit exceeded (60 requests / minute / key).',
              style: _bodyStyle,
            ),
            const SizedBox(height: 8),
            Text(
              '500 — Internal server error. Retry with backoff.',
              style: _bodyStyle,
            ),

            const SizedBox(height: 40),
            _DocHeading('Usage and Limits', key: _limitsKey),
            const SizedBox(height: 12),
            Text(
              'Rate limit: 60 requests per minute per API key. '
              'Pagination: pass pagination.next_cursor as cursor until has_more is false.',
              style: _bodyStyle,
            ),
            const SizedBox(height: 10),
            Text(
              'Rotate keys by creating a new key, updating your backend, then revoking '
              'the old key. Revocation takes effect immediately. Downgrading from Pro '
              'disables API access even if keys still exist.',
              style: _bodyStyle,
            ),
            const SizedBox(height: 10),
            Text(
              'Provide explicit public review text and mark a review Public before it appears in the API.',
              style: _bodyStyle,
            ),

            const SizedBox(height: 48),
            const Divider(color: FelloColors.border, height: 1),
            const SizedBox(height: 28),
            Wrap(
              spacing: 20,
              runSpacing: 10,
              children: [
                _FooterLink('Overview', () => _scrollTo(_overviewKey)),
                _FooterLink('API Keys', () => _scrollTo(_keysKey)),
                _FooterLink('GET Reviews', () => _scrollTo(_reviewsKey)),
                _FooterLink('Examples', () => _scrollTo(_examplesKey)),
                _FooterLink('Errors', () => _scrollTo(_errorsKey)),
                _FooterLink('Limits', () => _scrollTo(_limitsKey)),
                _FooterLink('Billing', () => context.go('/settings/billing')),
                _FooterLink('Dashboard', () => context.go('/dashboard')),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              '© ${DateTime.now().year} Kaydo. Build your own frontend with approved review JSON.',
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                color: FelloColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static final _bodyStyle = GoogleFonts.poppins(
    fontSize: 15,
    height: 1.6,
    fontWeight: FontWeight.w400,
    color: FelloColors.inkSoft,
  );
}

class _DocHeading extends StatelessWidget {
  const _DocHeading(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: FelloColors.ink,
      ),
    );
  }
}

class _DocLinkRow extends StatefulWidget {
  const _DocLinkRow({
    required this.title,
    required this.onTap,
    this.showDivider = true,
  });

  final String title;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  State<_DocLinkRow> createState() => _DocLinkRowState();
}

class _DocLinkRowState extends State<_DocLinkRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Column(
        children: [
          Material(
            color: _hovered
                ? FelloColors.accentSoft.withValues(alpha: 0.55)
                : Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _hovered
                              ? FelloColors.accentDeep
                              : FelloColors.ink,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.north_east_rounded,
                      size: 18,
                      color: _hovered
                          ? FelloColors.accent
                          : FelloColors.accentDeep.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (widget.showDivider)
            const Divider(height: 1, color: FelloColors.border),
        ],
      ),
    );
  }
}

class _CategoryItem {
  const _CategoryItem({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.wide, required this.items});

  final bool wide;
  final List<_CategoryItem> items;

  @override
  Widget build(BuildContext context) {
    if (!wide) {
      return Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _CategoryCard(item: items[i]),
          ],
        ],
      );
    }
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _CategoryCard(item: items[0])),
            const SizedBox(width: 12),
            Expanded(child: _CategoryCard(item: items[1])),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _CategoryCard(item: items[2])),
            const SizedBox(width: 12),
            Expanded(child: _CategoryCard(item: items[3])),
          ],
        ),
      ],
    );
  }
}

class _CategoryCard extends StatefulWidget {
  const _CategoryCard({required this.item});
  final _CategoryItem item;

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: _hovered
            ? FelloColors.accentSoft.withValues(alpha: 0.4)
            : FelloColors.paper,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: widget.item.onTap,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: _hovered
                    ? FelloColors.accent.withValues(alpha: 0.35)
                    : FelloColors.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(widget.item.icon, size: 22, color: FelloColors.accentDeep),
                const SizedBox(height: 14),
                Text(
                  widget.item.title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: FelloColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.item.body,
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    height: 1.5,
                    color: FelloColors.inkSoft,
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

class _FooterLink extends StatelessWidget {
  const _FooterLink(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: FelloColors.accentDeep,
        ),
      ),
    );
  }
}

class _UpgradeGate extends StatelessWidget {
  const _UpgradeGate({required this.orgName});

  final String orgName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FelloColors.accentSoft.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: FelloColors.accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline, color: FelloColors.accentDeep),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'API access requires Pro',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: FelloColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$orgName is on Free. Upgrade to Starter, Growth, or Custom '
                  'to generate API keys and fetch approved public reviews.',
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    height: 1.45,
                    color: FelloColors.inkSoft,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.go('/settings/billing'),
                  child: const Text('View plans'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ApiKeysPanel extends StatefulWidget {
  const _ApiKeysPanel({required this.isAdmin});

  final bool isAdmin;

  @override
  State<_ApiKeysPanel> createState() => _ApiKeysPanelState();
}

class _ApiKeysPanelState extends State<_ApiKeysPanel> {
  final _nameController = TextEditingController(text: 'Production');

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DeveloperDocsBloc, DeveloperDocsState>(
      builder: (context, state) {
        if (state.status == DeveloperDocsStatus.loading && state.keys.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Store API keys securely on your server. Kaydo only shows the full '
              'secret once at creation. Later you can see the name, prefix, and date.',
              style: GoogleFonts.poppins(
                fontSize: 15,
                height: 1.55,
                color: FelloColors.inkSoft,
              ),
            ),
            const SizedBox(height: 14),
            if (state.newlyCreatedSecret != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: FelloColors.accentSoft.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: FelloColors.accent.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'New API key (copy now)',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      state.newlyCreatedSecret!,
                      style: GoogleFonts.robotoMono(fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        FilledButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: state.newlyCreatedSecret!),
                            );
                            if (context.mounted) {
                              showKaydoToast(
                                context,
                                message: 'API key copied',
                                tone: KaydoToastTone.success,
                              );
                            }
                          },
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Copy key'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => context
                              .read<DeveloperDocsBloc>()
                              .add(const DeveloperApiKeySecretCleared()),
                          child: const Text('Dismiss'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (widget.isAdmin) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: FelloTextField(
                      controller: _nameController,
                      label: 'Key name',
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: FelloMetrics.controlHeight,
                    child: FilledButton(
                      onPressed: state.busy
                          ? null
                          : () {
                              context.read<DeveloperDocsBloc>().add(
                                DeveloperApiKeyCreateRequested(
                                  _nameController.text,
                                ),
                              );
                            },
                      child: state.busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Generate'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ] else
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Only organization admins can generate or revoke API keys.',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: FelloColors.inkSoft,
                  ),
                ),
              ),
            if (state.keys.isEmpty)
              Text(
                'No API keys yet.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: FelloColors.inkSoft,
                ),
              )
            else
              ...state.keys.map(
                (k) => _KeyRow(keyMeta: k, isAdmin: widget.isAdmin),
              ),
          ],
        );
      },
    );
  }
}

class _KeyRow extends StatelessWidget {
  const _KeyRow({required this.keyMeta, required this.isAdmin});

  final OrgApiKey keyMeta;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat.yMMMd().format(keyMeta.createdAt.toLocal());
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: FelloColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  keyMeta.name,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${keyMeta.maskedPreview} · created $date'
                  '${keyMeta.isRevoked ? ' · revoked' : ''}',
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    color: FelloColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          if (isAdmin && !keyMeta.isRevoked)
            TextButton(
              onPressed: () {
                context.read<DeveloperDocsBloc>().add(
                  DeveloperApiKeyRevokeRequested(keyMeta.id),
                );
              },
              style: TextButton.styleFrom(foregroundColor: FelloColors.danger),
              child: const Text('Revoke'),
            ),
        ],
      ),
    );
  }
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: FelloColors.accentDeep,
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: GoogleFonts.robotoMono(fontSize: 12.5),
          ),
        ),
        IconButton(
          tooltip: 'Copy',
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: value));
            if (context.mounted) {
              showKaydoToast(
                context,
                message: 'Copied',
                tone: KaydoToastTone.success,
              );
            }
          },
          icon: Icon(
            Icons.copy,
            size: 16,
            color: FelloColors.accentDeep.withValues(alpha: 0.85),
          ),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock(this.code);

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      decoration: BoxDecoration(
        color: FelloColors.accentSoft.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: FelloColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SelectableText(
              code,
              style: GoogleFonts.robotoMono(fontSize: 12, height: 1.45),
            ),
          ),
          IconButton(
            tooltip: 'Copy',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (context.mounted) {
                showKaydoToast(
                  context,
                  message: 'Copied',
                  tone: KaydoToastTone.success,
                );
              }
            },
            icon: Icon(
              Icons.copy,
              size: 16,
              color: FelloColors.accentDeep.withValues(alpha: 0.85),
            ),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

const _exampleJson = '''{
  "data": [
    {
      "id": "…",
      "form_id": "…",
      "form_title": "Customer experience",
      "form_slug": "customer-experience",
      "published_at": "2026-11-14T08:00:00Z",
      "rating": 5,
      "comment": "Friendly staff and quick service."
    }
  ],
  "pagination": { "limit": 20, "next_cursor": null, "has_more": false }
}''';
