import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../models/enums.dart';
import '../models/wedding_task.dart';
import '../state/providers.dart';
import '../widgets/common.dart';
import 'dashboard_screen.dart' show priorityColor;

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  Ceremony? _ceremonyFilter;
  bool _hidePending = false;

  @override
  Widget build(BuildContext context) {
    final roadmapAsync = ref.watch(roadmapProvider);
    final theme = Theme.of(context);

    return roadmapAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (roadmap) {
        var items = roadmap.scheduled;
        if (_ceremonyFilter != null) {
          items = items.where((s) => s.task.ceremony == _ceremonyFilter).toList();
        }
        if (_hidePending) {
          items = items.where((s) => s.task.isDone).toList();
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Roadmap',
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  Text('${roadmap.done}/${roadmap.total} done',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      label: const Text('All'),
                      selected: _ceremonyFilter == null,
                      onSelected: (_) => setState(() => _ceremonyFilter = null),
                    ),
                  ),
                  for (final c in Ceremony.values)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FilterChip(
                        label: Text(c.label),
                        selected: _ceremonyFilter == c,
                        onSelected: (_) => setState(() => _ceremonyFilter = c),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? const EmptyState(
                      icon: Icons.task_alt, message: 'No tasks match this filter.')
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      itemCount: items.length,
                      itemBuilder: (_, i) => _TaskCard(items[i]),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _TaskCard extends ConsumerWidget {
  final ScheduledTask scheduled;
  const _TaskCard(this.scheduled);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = scheduled.task;
    final theme = Theme.of(context);
    final now = DateTime.now();
    final overdue = scheduled.isOverdue(now);
    return Card(
      child: ListTile(
        leading: Checkbox(
          value: t.isDone,
          onChanged: (_) => ref.read(taskStatusProvider.notifier).toggleDone(t.id),
        ),
        title: Text(
          t.title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: t.isDone ? TextDecoration.lineThrough : null,
            color: t.isDone ? theme.colorScheme.outline : null,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TintPill(t.priority.label, color: priorityColor(t.priority)),
              TintPill(t.ceremony.label, color: Colors.deepPurple),
              if (t.costEstimate > 0)
                TintPill(Fmt.inr(t.costEstimate),
                    color: Colors.teal, icon: Icons.payments),
              Text('due ${Fmt.date(scheduled.due)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: overdue
                          ? Colors.redAccent
                          : theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        isThreeLine: true,
        onTap: () => showTaskDetail(context, ref, scheduled),
      ),
    );
  }
}

void showTaskDetail(BuildContext context, WidgetRef ref, ScheduledTask s) {
  final t = s.task;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      final theme = Theme.of(context);
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text(t.title,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                TintPill(t.priority.label, color: priorityColor(t.priority)),
                TintPill(t.ceremony.label, color: Colors.deepPurple),
                TintPill(t.category, color: Colors.blueGrey),
                if (t.mandatory)
                  const TintPill('Mandatory', color: Colors.redAccent),
              ],
            ),
            const SizedBox(height: 16),
            Text(t.description, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 20),
            _detailRow(theme, 'Scheduled start', Fmt.date(s.start)),
            _detailRow(theme, 'Due date', Fmt.date(s.due)),
            _detailRow(theme, 'Estimated cost',
                t.costEstimate > 0 ? Fmt.inrExact(t.costEstimate) : '—'),
            _detailRow(theme, 'Budget category', t.budgetCategory),
            if (t.requiredVendors.isNotEmpty)
              _detailRow(theme, 'Vendors', t.requiredVendors.join(', ')),
            if (t.shoppingItems.isNotEmpty)
              _detailRow(theme, 'Shopping', t.shoppingItems.join(', ')),
            if (t.dependencies.isNotEmpty)
              _detailRow(theme, 'Depends on', t.dependencies.join(', ')),
            if (t.tags.isNotEmpty)
              _detailRow(theme, 'Tags', t.tags.join(', ')),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {
                ref.read(taskStatusProvider.notifier).toggleDone(t.id);
                Navigator.pop(context);
              },
              icon: Icon(t.isDone ? Icons.undo : Icons.check),
              label: Text(t.isDone ? 'Mark as not done' : 'Mark as done'),
            ),
          ],
        ),
      );
    },
  );
}

Widget _detailRow(ThemeData theme, String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(
              child: Text(value,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w500))),
        ],
      ),
    );
