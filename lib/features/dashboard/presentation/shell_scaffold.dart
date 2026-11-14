import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/fello_colors.dart';
import '../../../shared/widgets/fello_logo.dart';
import '../../auth/bloc/auth_bloc.dart';

class ShellScaffold extends StatelessWidget {
  const ShellScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sign out?'),
          content: const Text('Are you sure you want to sign out of Kaydo?'),
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
              child: const Text('Sign out'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) return;
    context.read<AuthBloc>().add(const AuthSignOutRequested());
    context.go('/sign-in');
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 960;
    final session = context.watch<AuthBloc>().state.session;

    void onSelect(int index) {
      navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      );
    }

    final isAdmin = session?.profile.isAdmin ?? false;
    final shellIndex = navigationShell.currentIndex;
    // Mobile bottom nav only covers Dashboard + Survey.
    final bottomIndex = shellIndex <= 1 ? shellIndex : 0;

    if (isWide) {
      return Scaffold(
        backgroundColor: FelloColors.paper,
        body: Row(
          children: [
            _SideNav(
              selectedIndex: shellIndex,
              onSelect: onSelect,
              isAdmin: isAdmin,
              userName: session?.profile.displayName ?? 'User',
              onSignOut: () => _confirmSignOut(context),
            ),
            Expanded(
              child: ColoredBox(
                color: FelloColors.paper,
                child: Column(
                  children: [
                    const _TopAppBar(),
                    Expanded(child: navigationShell),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: FelloColors.paper,
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: bottomIndex,
        onDestinationSelected: onSelect,
        backgroundColor: FelloColors.paper,
        indicatorColor: FelloColors.accentSoft,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.dynamic_form_outlined),
            selectedIcon: Icon(Icons.dynamic_form),
            label: 'Survey',
          ),
        ],
      ),
      appBar: AppBar(
        backgroundColor: FelloColors.paper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Padding(
          padding: EdgeInsets.only(left: 4),
          child: FelloLogo(size: 26),
        ),
        actions: [
          if (isAdmin)
            PopupMenuButton<String>(
              tooltip: 'Workspace',
              onSelected: (value) {
                switch (value) {
                  case 'team':
                    context.go('/team');
                  case 'billing':
                    context.go('/settings/billing');
                  case 'logo':
                    context.go('/settings/logo');
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'team', child: Text('Team')),
                PopupMenuItem(
                    value: 'billing', child: Text('Subscription')),
                PopupMenuItem(value: 'logo', child: Text('Logo')),
              ],
              icon: const Icon(Icons.more_horiz, color: FelloColors.ink),
            ),
          const _HelpAndVersionActions(),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => _confirmSignOut(context),
            icon: const Icon(Icons.logout, color: FelloColors.danger),
          ),
        ],
      ),
    );
  }
}

/// White top bar shared across desktop shell pages.
class _TopAppBar extends StatelessWidget {
  const _TopAppBar();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FelloColors.paper,
      elevation: 0,
      child: Container(
        height: kToolbarHeight,
        width: double.infinity,
        decoration: const BoxDecoration(
          color: FelloColors.paper,
          border: Border(
            bottom: BorderSide(color: FelloColors.border),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerRight,
        child: const _HelpAndVersionActions(),
      ),
    );
  }
}

class _HelpAndVersionActions extends StatelessWidget {
  const _HelpAndVersionActions();

  @override
  Widget build(BuildContext context) {
    final isAdmin =
        context.watch<AuthBloc>().state.session?.profile.isAdmin ?? false;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isAdmin) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: FelloColors.accentSoft,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: FelloColors.border),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 13,
                  color: FelloColors.accentDeep,
                ),
                SizedBox(width: 4),
                Text(
                  'Admin',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: FelloColors.accentDeep,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
        ],
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Text(
            'v${AppConfig.appVersion}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: FelloColors.inkSoft,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Help',
          onPressed: () => _showHelp(context),
          iconSize: 18,
          visualDensity: VisualDensity.compact,
          icon: const Icon(
            Icons.help_outline_rounded,
            size: 18,
            color: FelloColors.accent,
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  void _showHelp(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: FelloColors.paper,
          title: const Text('Help'),
          content: const Text(
            'Build forms, publish them, then share a link or QR code. '
            'Responses show up on your Dashboard.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it'),
            ),
          ],
        );
      },
    );
  }
}

class _SideNav extends StatelessWidget {
  const _SideNav({
    required this.selectedIndex,
    required this.onSelect,
    required this.isAdmin,
    required this.userName,
    required this.onSignOut,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final bool isAdmin;
  final String userName;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 248,
      decoration: const BoxDecoration(
        color: FelloColors.paper,
        border: Border(right: BorderSide(color: FelloColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: kToolbarHeight,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            alignment: Alignment.centerLeft,
            decoration: const BoxDecoration(
              color: FelloColors.paper,
              border: Border(
                bottom: BorderSide(color: FelloColors.border),
              ),
            ),
            child: const FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
              child: FelloLogo(size: 18),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _NavItem(
                    icon: Icons.grid_view_rounded,
                    label: 'Dashboard',
                    selected: selectedIndex == 0,
                    onTap: () => onSelect(0),
                  ),
                  _NavItem(
                    icon: Icons.dynamic_form_outlined,
                    label: 'Survey',
                    selected: selectedIndex == 1,
                    onTap: () => onSelect(1),
                  ),
                  if (isAdmin) ...[
                    const SizedBox(height: 8),
                    _NavItem(
                      icon: Icons.group_outlined,
                      label: 'Team',
                      selected: selectedIndex == 2,
                      onTap: () => onSelect(2),
                    ),
                    _NavItem(
                      icon: Icons.image_outlined,
                      label: 'Logo',
                      selected: selectedIndex == 3,
                      onTap: () => onSelect(3),
                    ),
                    _NavItem(
                      icon: Icons.credit_card_outlined,
                      label: 'Subscription',
                      selected: selectedIndex == 4,
                      onTap: () => onSelect(4),
                    ),
                  ],
                  const Spacer(),
                  const Divider(height: 1, color: FelloColors.border),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: FelloColors.accentSoft,
                        child: Text(
                          _initials(userName),
                          style: const TextStyle(
                            color: FelloColors.accentDeep,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: FelloColors.ink,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Sign out',
                        onPressed: onSignOut,
                        icon: const Icon(
                          Icons.logout,
                          size: 18,
                          color: FelloColors.danger,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'K';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? FelloColors.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? FelloColors.accentDeep : FelloColors.inkSoft,
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? FelloColors.accentDeep : FelloColors.ink,
                    fontSize: 14,
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
