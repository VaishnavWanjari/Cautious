import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/insight.dart';
import '../state/providers.dart';
import '../widgets/common.dart';
import 'reminders_screen.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insights = ref.watch(insightsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Insights'),
        actions: [
          IconButton(
            tooltip: 'Reminders',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RemindersScreen()),
            ),
            icon: const Icon(Icons.notifications_active_outlined),
          ),
        ],
      ),
      body: insights.isEmpty
          ? const EmptyState(
              icon: Icons.verified,
              message: 'No risks detected — your plan looks healthy!')
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Card(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.auto_awesome),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Your AI planner reviewed the roadmap, budget and vendors '
                            'and flagged what needs attention.',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                for (final i in insights) _InsightCard(i),
              ],
            ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final Insight insight;
  const _InsightCard(this.insight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (color, icon) = _styleFor(insight.severity);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(insight.title,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                      ),
                      TintPill(_label(insight.severity), color: color),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(insight.detail,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  (Color, IconData) _styleFor(InsightSeverity s) {
    switch (s) {
      case InsightSeverity.critical:
        return (Colors.redAccent, Icons.error_outline);
      case InsightSeverity.warning:
        return (Colors.orange, Icons.warning_amber_rounded);
      case InsightSeverity.info:
        return (Colors.blue, Icons.info_outline);
      case InsightSeverity.positive:
        return (Colors.green, Icons.check_circle_outline);
    }
  }

  String _label(InsightSeverity s) {
    switch (s) {
      case InsightSeverity.critical:
        return 'Critical';
      case InsightSeverity.warning:
        return 'Warning';
      case InsightSeverity.info:
        return 'Info';
      case InsightSeverity.positive:
        return 'On track';
    }
  }
}
