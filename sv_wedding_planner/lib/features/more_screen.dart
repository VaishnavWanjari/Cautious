import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import 'insights_screen.dart';
import 'modules.dart';
import 'onboarding_screen.dart';
import 'reminders_screen.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final vendors = ref.watch(vendorsProvider);
    final shopping = ref.watch(shoppingProvider);
    final guests = ref.watch(guestsProvider);

    final insights = ref.watch(insightsProvider);
    final reminders = ref.watch(remindersProvider);
    final overdue = reminders.where((r) => r.overdue).length;

    final tiles = <_MoreTile>[
      _MoreTile(Icons.auto_awesome, 'AI Insights',
          insights.isEmpty ? 'All healthy' : '${insights.length} to review', Colors.deepPurple,
          () => const InsightsScreen()),
      _MoreTile(Icons.notifications_active, 'Reminders',
          overdue > 0 ? '$overdue overdue' : '${reminders.length} scheduled', Colors.redAccent,
          () => const RemindersScreen()),
      _MoreTile(Icons.handshake, 'Vendors', '${vendors.length} tracked', Colors.teal,
          () => const VendorsScreen()),
      _MoreTile(Icons.shopping_bag, 'Shopping', '${shopping.length} items', Colors.orange,
          () => const ShoppingScreen()),
      _MoreTile(Icons.groups, 'Guests & Family', '${guests.length} groups', Colors.indigo,
          () => const GuestsScreen()),
      _MoreTile(Icons.flight_takeoff, 'Honeymoon', 'Plan the getaway', Colors.pink,
          () => const HoneymoonScreen()),
      _MoreTile(Icons.tune, 'Wedding profile', 'Re-run personalization', Colors.blueGrey,
          () => const OnboardingScreen(editing: true)),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        Text('More',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        for (final t in tiles)
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: t.color.withOpacity(0.15),
                child: Icon(t.icon, color: t.color),
              ),
              title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(t.subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => t.builder()),
              ),
            ),
          ),
        const SizedBox(height: 24),
        Center(
          child: Text('SV Wedding Planner • v0.1.0\nThe AI Wedding Operating System',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline)),
        ),
      ],
    );
  }
}

class _MoreTile {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Widget Function() builder;
  _MoreTile(this.icon, this.title, this.subtitle, this.color, this.builder);
}
