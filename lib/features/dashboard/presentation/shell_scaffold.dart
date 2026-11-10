import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/fello_colors.dart';
import '../../../shared/widgets/fello_logo.dart';
import '../../auth/bloc/auth_bloc.dart';

class ShellScaffold extends StatelessWidget {
  const ShellScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 900;
    final session = context.watch<AuthBloc>().state.session;

    final destinations = const [
      NavigationDestination(
        icon: Icon(Icons.insights_outlined),
        selectedIcon: Icon(Icons.insights),
        label: 'Dashboard',
      ),
      NavigationDestination(
        icon: Icon(Icons.dynamic_form_outlined),
        selectedIcon: Icon(Icons.dynamic_form),
        label: 'Forms',
      ),
    ];

    void onSelect(int index) {
      navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      );
    }

    final body = navigationShell;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: onSelect,
              extended: width >= 1100,
              backgroundColor: FelloColors.paper,
              indicatorColor: FelloColors.accentSoft,
              selectedIconTheme:
                  const IconThemeData(color: FelloColors.accentDeep),
              unselectedIconTheme:
                  const IconThemeData(color: FelloColors.inkSoft),
              labelType: width >= 1100
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.fromLTRB(12, 24, 12, 32),
                child: FelloLogo(size: 28, showWordmark: width >= 1100),
              ),
              destinations: destinations
                  .map(
                    (d) => NavigationRailDestination(
                      icon: d.icon,
                      selectedIcon: d.selectedIcon,
                      label: Text(d.label),
                    ),
                  )
                  .toList(),
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (session != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              session.organization.name,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ),
                        IconButton(
                          tooltip: 'Sign out',
                          onPressed: () {
                            context
                                .read<AuthBloc>()
                                .add(const AuthSignOutRequested());
                            context.go('/sign-in');
                          },
                          icon: const Icon(Icons.logout),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: onSelect,
        destinations: destinations,
      ),
      appBar: AppBar(
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
