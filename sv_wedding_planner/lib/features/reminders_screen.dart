import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/format.dart';
import '../models/reminder.dart';
import '../state/providers.dart';
import '../widgets/common.dart';

/// In-app reminder agenda: every open task with the date you should be nudged,
/// grouped by month, overdue first.
class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminders = ref.watch(remindersProvider);
    final overdue = reminders.where((r) => r.overdue).toList();
    final upcoming = reminders.where((r) => !r.overdue).toList();

    // Group upcoming by "MMMM yyyy".
    final groups = <String, List<Reminder>>{};
    final monthFmt = DateFormat('MMMM yyyy');
    for (final r in upcoming) {
      groups.putIfAbsent(monthFmt.format(r.dueOn), () => []).add(r);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      body: reminders.isEmpty
          ? const EmptyState(
              icon: Icons.notifications_none,
              message: 'No reminders — every task is done!')
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (overdue.isNotEmpty) ...[
                  const SectionHeader('Overdue', subtitle: 'Needs attention now'),
                  for (final r in overdue) _ReminderTile(r),
                  const SizedBox(height: 8),
                ],
                for (final entry in groups.entries) ...[
                  SectionHeader(entry.key,
                      subtitle: '${entry.value.length} reminder(s)'),
                  for (final r in entry.value) _ReminderTile(r),
                ],
              ],
            ),
    );
  }
}

class _ReminderTile extends ConsumerWidget {
  final Reminder reminder;
  const _ReminderTile(this.reminder);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color = reminder.overdue ? Colors.redAccent : theme.colorScheme.primary;
    return Card(
      child: ListTile(
        leading: Checkbox(
          value: false,
          onChanged: (_) =>
              ref.read(taskStatusProvider.notifier).toggleDone(reminder.taskId),
        ),
        title: Text(reminder.title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${reminder.ceremony} • due ${Fmt.date(reminder.dueOn)}',
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant)),
        trailing: TintPill(
          reminder.overdue ? 'Overdue' : 'Remind ${Fmt.shortDate(reminder.remindOn)}',
          color: color,
          icon: Icons.notifications_active_outlined,
        ),
      ),
    );
  }
}
