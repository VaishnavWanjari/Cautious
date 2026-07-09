import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../models/enums.dart';
import '../models/wedding_task.dart';
import '../models/insight.dart';
import '../state/providers.dart';
import '../widgets/common.dart';
import 'insights_screen.dart';
import 'tasks_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final roadmapAsync = ref.watch(roadmapProvider);
    final focus = ref.watch(todaysFocusProvider);
    final budget = ref.watch(budgetProvider);
    final vendors = ref.watch(vendorsProvider);
    final theme = Theme.of(context);
    final now = DateTime.now();

    final plannedSpend = budget.fold<int>(0, (s, b) => s + b.actual);
    final bookedVendors = vendors.where((v) => v.booked).length;
    final insights = ref.watch(insightsProvider);

    return roadmapAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Failed to load roadmap: $e')),
      data: (roadmap) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          _Greeting(profile.coupleGroom, profile.coupleBride),
          const SizedBox(height: 16),
          _CountdownRow(profile: profile),
          const SizedBox(height: 20),

          // Progress ring + funnel.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: roadmap.progress,
                          strokeWidth: 7,
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        ),
                        Text('${(roadmap.progress * 100).round()}%',
                            style: theme.textTheme.labelLarge
                                ?.copyWith(fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your personalized roadmap',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(
                          'AI narrowed ${roadmap.masterCount} knowledge-base tasks '
                          'to ${roadmap.total} for you — ${roadmap.done} done.',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _FunnelStrip(roadmap.funnel),

          const SizedBox(height: 12),
          if (insights.isNotEmpty) _InsightsBanner(insights),

          // Stat grid.
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              StatTile(
                  label: 'Spent of ${Fmt.inr(profile.budget)}',
                  value: Fmt.inr(plannedSpend),
                  icon: Icons.account_balance_wallet,
                  color: AppTheme.gold),
              StatTile(
                  label: 'Vendors booked',
                  value: '$bookedVendors/${vendors.length}',
                  icon: Icons.handshake,
                  color: Colors.teal),
              StatTile(
                  label: 'Tasks remaining',
                  value: '${roadmap.total - roadmap.done}',
                  icon: Icons.checklist,
                  color: theme.colorScheme.primary),
              StatTile(
                  label: 'Overdue',
                  value: '${roadmap.scheduled.where((s) => s.isOverdue(now)).length}',
                  icon: Icons.warning_amber_rounded,
                  color: Colors.redAccent),
            ],
          ),

          const SizedBox(height: 12),
          SectionHeader(
            "Today's priorities",
            subtitle: 'What your AI planner recommends now',
          ),
          if (focus.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: EmptyState(
                    icon: Icons.celebration,
                    message: 'Nothing urgent right now. Enjoy the moment! 🎉'),
              ),
            )
          else
            ...focus.map((s) => _FocusTile(s, now)),
        ],
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  final String groom;
  final String bride;
  const _Greeting(this.groom, this.bride);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final couple = [groom, bride].where((s) => s.isNotEmpty).join(' & ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SV Wedding Planner',
            style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2)),
        const SizedBox(height: 2),
        Text(couple.isEmpty ? 'Your Wedding' : couple,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _CountdownRow extends StatelessWidget {
  final dynamic profile;
  const _CountdownRow({required this.profile});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    int? days(DateTime? d) =>
        d == null ? null : DateTime(d.year, d.month, d.day).difference(DateTime(now.year, now.month, now.day)).inDays;

    final items = <(String, DateTime?, IconData)>[
      ('Wedding', profile.weddingDate, Icons.favorite),
      ('Reception', profile.receptionDate, Icons.celebration),
      ('Honeymoon', profile.honeymoonDate, Icons.flight_takeoff),
    ].where((it) => it.$2 != null).toList();

    if (items.isEmpty) return const SizedBox.shrink();

    final cards = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      cards.add(Expanded(child: _CountdownCard(it.$1, days(it.$2)!, it.$2!, it.$3)));
      if (i != items.length - 1) cards.add(const SizedBox(width: 10));
    }
    return Row(children: cards);
  }
}

class _CountdownCard extends StatelessWidget {
  final String label;
  final int days;
  final DateTime date;
  final IconData icon;
  const _CountdownCard(this.label, this.days, this.date, this.icon);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.onPrimaryContainer),
            const SizedBox(height: 10),
            Text(days >= 0 ? '$days' : '—',
                style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.onPrimaryContainer)),
            Text(days >= 0 ? 'days to $label' : label,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer)),
            Text(Fmt.shortDate(date),
                style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer.withOpacity(0.7))),
          ],
        ),
      ),
    );
  }
}

class _FunnelStrip extends StatelessWidget {
  final List funnel;
  const _FunnelStrip(this.funnel);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: funnel.length,
        separatorBuilder: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(Icons.chevron_right,
              size: 16, color: theme.colorScheme.outline),
        ),
        itemBuilder: (_, i) {
          final stage = funnel[i];
          return Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${stage.count}',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  Text(stage.label,
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FocusTile extends ConsumerWidget {
  final ScheduledTask scheduled;
  final DateTime now;
  const _FocusTile(this.scheduled, this.now);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = scheduled.task;
    final theme = Theme.of(context);
    final overdue = scheduled.isOverdue(now);
    return Card(
      child: ListTile(
        leading: Checkbox(
          value: t.isDone,
          onChanged: (_) => ref.read(taskStatusProvider.notifier).toggleDone(t.id),
        ),
        title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Row(
          children: [
            Icon(Icons.event, size: 13, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              '${Fmt.date(scheduled.due)} • ${t.ceremony.label}',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: overdue ? Colors.redAccent : theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        trailing: TintPill(t.priority.label, color: priorityColor(t.priority)),
        onTap: () => showTaskDetail(context, ref, scheduled),
      ),
    );
  }
}

class _InsightsBanner extends StatelessWidget {
  final List<Insight> insights;
  const _InsightsBanner(this.insights);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final top = insights.first;
    final critical = insights.where((i) => i.severity == InsightSeverity.critical).length;
    final warnings = insights.where((i) => i.severity == InsightSeverity.warning).length;
    final (color, icon) = switch (top.severity) {
      InsightSeverity.critical => (Colors.redAccent, Icons.error_outline),
      InsightSeverity.warning => (Colors.orange, Icons.warning_amber_rounded),
      InsightSeverity.info => (Colors.blue, Icons.info_outline),
      InsightSeverity.positive => (Colors.green, Icons.check_circle_outline),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const InsightsScreen()),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('AI Insights',
                              style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w700)),
                          const Spacer(),
                          if (critical > 0)
                            TintPill('$critical critical', color: Colors.redAccent)
                          else if (warnings > 0)
                            TintPill('$warnings warnings', color: Colors.orange),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(top.title,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      Text(top.detail,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Color priorityColor(Priority p) {
  switch (p) {
    case Priority.critical:
      return Colors.redAccent;
    case Priority.high:
      return Colors.orange;
    case Priority.medium:
      return Colors.blue;
    case Priority.low:
      return Colors.green;
  }
}
