import '../models/enums.dart';
import '../models/reminder.dart';
import '../models/wedding_task.dart';

/// Derives a reminder agenda from the scheduled roadmap. Each open task earns
/// a nudge a couple of days before it is due (its "reminder date"), and
/// anything already past due is flagged as overdue and surfaced first.
class ReminderEngine {
  const ReminderEngine();

  List<Reminder> build(
    List<ScheduledTask> scheduled, {
    int leadDays = 2,
    DateTime? now,
  }) {
    final today = _dateOnly(now ?? DateTime.now());
    final reminders = <Reminder>[];

    for (final s in scheduled) {
      if (s.task.isDone) continue;
      final remindOn = s.due.subtract(Duration(days: leadDays));
      final overdue = s.due.isBefore(today);
      reminders.add(Reminder(
        taskId: s.task.id,
        title: s.task.title,
        remindOn: remindOn.isBefore(today) ? today : remindOn,
        dueOn: s.due,
        ceremony: s.task.ceremony.label,
        overdue: overdue,
      ));
    }

    reminders.sort((a, b) {
      if (a.overdue != b.overdue) return a.overdue ? -1 : 1;
      return a.dueOn.compareTo(b.dueOn);
    });
    return reminders;
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
