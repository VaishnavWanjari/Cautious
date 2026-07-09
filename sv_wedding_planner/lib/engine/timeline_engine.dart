import '../models/enums.dart';
import '../models/wedding_profile.dart';
import '../models/wedding_task.dart';

/// Turns a flat list of personalized tasks into a dependency-aware schedule.
///
/// Each task has a natural start offset relative to the wedding date. The
/// engine then enforces dependencies: a task can never be due before every
/// task it depends on has finished (plus its buffer). If one task slips, the
/// tasks that depend on it cascade automatically.
class TimelineEngine {
  const TimelineEngine();

  List<ScheduledTask> schedule(List<WeddingTask> tasks, WeddingProfile p) {
    final anchor = p.weddingDate;
    if (anchor == null) return const [];
    final wedding = DateTime(anchor.year, anchor.month, anchor.day);

    final byId = {for (final t in tasks) t.id: t};
    final startCache = <String, DateTime>{};
    final dueCache = <String, DateTime>{};
    final visiting = <String>{};

    DateTime dueOf(WeddingTask t) {
      if (dueCache.containsKey(t.id)) return dueCache[t.id]!;
      // Guard against cyclic dependencies.
      if (visiting.contains(t.id)) {
        return wedding.add(Duration(days: t.startOffsetDays));
      }
      visiting.add(t.id);

      var start = wedding.add(Duration(days: t.startOffsetDays));

      // Respect dependencies: cannot start before all prerequisites are due.
      for (final depId in t.dependencies) {
        final dep = byId[depId];
        if (dep == null) continue;
        final depDue = dueOf(dep).add(Duration(days: dep.bufferDays));
        if (depDue.isAfter(start)) start = depDue;
      }

      final due = start.add(Duration(days: t.estimatedDurationDays));
      startCache[t.id] = start;
      dueCache[t.id] = due;
      visiting.remove(t.id);
      return due;
    }

    final scheduled = <ScheduledTask>[];
    for (final t in tasks) {
      final due = dueOf(t);
      scheduled.add(
        ScheduledTask(task: t, start: startCache[t.id] ?? due, due: due),
      );
    }

    scheduled.sort((a, b) => a.due.compareTo(b.due));
    return scheduled;
  }

  /// Tasks that should be worked on right now: not done, already startable,
  /// and due within [horizonDays].
  List<ScheduledTask> todaysFocus(
    List<ScheduledTask> scheduled,
    DateTime now, {
    int horizonDays = 21,
    int limit = 6,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final focus = scheduled
        .where((s) => !s.task.isDone)
        .where((s) => s.start.isBefore(today.add(const Duration(days: 1))) ||
            s.daysUntilDue(now) <= horizonDays)
        .toList();
    focus.sort((a, b) {
      final byDue = a.due.compareTo(b.due);
      if (byDue != 0) return byDue;
      return b.task.priority.weight.compareTo(a.task.priority.weight);
    });
    return focus.take(limit).toList();
  }
}
