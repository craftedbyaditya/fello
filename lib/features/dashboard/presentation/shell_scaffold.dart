import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/fello_colors.dart';
import '../../../shared/widgets/fello_logo.dart';
import '../../auth/bloc/auth_bloc.dart';

class ShellScaffold extends StatelessWidget {
  const ShellScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

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

    if (isWide) {
      return Scaffold(
        backgroundColor: FelloColors.mist,
        body: Row(
          children: [
            _SideNav(
              selectedIndex: navigationShell.currentIndex,
              onSelect: onSelect,
              orgName: session?.organization.name ?? 'Organisation',
              userName: session?.profile.displayName ?? 'User',
              onSignOut: () {
                context.read<AuthBloc>().add(const AuthSignOutRequested());
                context.go('/sign-in');
              },
            ),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: FelloColors.mist,
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
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
            label: 'Forms',
          ),
        ],
      ),
      appBar: AppBar(
        backgroundColor: FelloColors.paper,
        title: const FelloLogo(size: 26),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () {
              context.read<AuthBloc>().add(const AuthSignOutRequested());
              context.go('/sign-in');
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
    );
  }
}

class _SideNav extends StatelessWidget {
  const _SideNav({
    required this.selectedIndex,
    required this.onSelect,
    required this.orgName,
    required this.userName,
    required this.onSignOut,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final String orgName;
  final String userName;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 248,
      decoration: const BoxDecoration(
        color: FelloColors.sidebar,
        border: Border(right: BorderSide(color: FelloColors.border)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FelloLogo(size: 30),
              const SizedBox(height: 6),
              Text(
                'Customer feedback',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: FelloColors.inkSoft,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 28),
              _SectionLabel('Workspace'),
              const SizedBox(height: 8),
              _NavItem(
                icon: Icons.grid_view_rounded,
                label: 'Dashboard',
                selected: selectedIndex == 0,
                onTap: () => onSelect(0),
              ),
              _NavItem(
                icon: Icons.dynamic_form_outlined,
                label: 'Forms',
                selected: selectedIndex == 1,
                onTap: () => onSelect(1),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: FelloColors.paper,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: FelloColors.border),
                ),
                child: Row(
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: FelloColors.ink,
                            ),
                          ),
                          Text(
                            orgName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: FelloColors.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Sign out',
                      onPressed: onSignOut,
                      icon: const Icon(Icons.logout, size: 18),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'F';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.dmSans(
        fontSize: 11,
        letterSpacing: 0.6,
        fontWeight: FontWeight.w600,
        color: FelloColors.inkSoft,
      ),
    );
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
