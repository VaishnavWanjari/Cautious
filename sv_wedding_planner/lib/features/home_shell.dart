import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import 'connect_account_screen.dart';
import 'dashboard_screen.dart';
import 'tasks_screen.dart';
import 'budget_screen.dart';
import 'more_screen.dart';
import 'copilot_screen.dart';

/// Root scaffold with a bottom navigation bar and a floating Copilot button.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  static const _pages = [
    DashboardScreen(),
    TasksScreen(),
    BudgetScreen(),
    MoreScreen(),
  ];

  void _openCopilot() {
    void openCopilot() => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CopilotScreen()),
        );
    if (ref.read(accountProvider).connected) {
      openCopilot();
    } else {
      // Gate the Copilot: ask the user to connect Gmail first, then open it.
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ConnectAccountScreen(onConnected: openCopilot),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _pages[_index]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCopilot,
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Copilot'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.checklist_outlined),
              selectedIcon: Icon(Icons.checklist),
              label: 'Roadmap'),
          NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'Budget'),
          NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view),
              label: 'More'),
        ],
      ),
    );
  }
}
