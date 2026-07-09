import '../core/format.dart';
import '../models/enums.dart';
import '../models/insight.dart';
import '../models/other_models.dart';
import '../models/wedding_profile.dart';
import '../models/wedding_task.dart';

/// The proactive "AI Wedding Manager" brain. Reads the current plan state and
/// produces a ranked list of risks, reminders and wins — the same things an
/// experienced planner would flag when they glance at your file.
class InsightsEngine {
  const InsightsEngine();

  /// Vendor types considered critical-path — the wedding cannot happen well
  /// without them, so leaving them unbooked is a real risk.
  static const _criticalVendorTypes = {
    'Venue', 'Caterer', 'Photographer', 'Decorator', 'Priest'
  };

  List<Insight> analyze({
    required List<ScheduledTask> scheduled,
    required List<BudgetItem> budget,
    required List<Vendor> vendors,
    required WeddingProfile profile,
    DateTime? now,
  }) {
    final today = _dateOnly(now ?? DateTime.now());
    final insights = <Insight>[];

    // 1. Overdue tasks — the sharpest signal.
    final overdue = scheduled.where((s) => s.isOverdue(today)).toList();
    if (overdue.isNotEmpty) {
      final names = overdue.take(3).map((s) => s.task.title).join(', ');
      insights.add(Insight(
        severity: InsightSeverity.critical,
        category: InsightCategory.overdue,
        title: '${overdue.length} task${overdue.length > 1 ? 's' : ''} overdue',
        detail: overdue.length <= 3
            ? names
            : '$names +${overdue.length - 3} more. Reschedule or delegate today.',
        taskId: overdue.first.task.id,
      ));
    }

    // 2. Critical-path tasks at risk (critical priority, open, due soon).
    for (final s in scheduled) {
      if (s.task.isDone || s.task.priority != Priority.critical) continue;
      final days = s.daysUntilDue(today);
      if (days >= 0 && days <= 30) {
        insights.add(Insight(
          severity: days <= 10 ? InsightSeverity.warning : InsightSeverity.info,
          category: InsightCategory.criticalPath,
          title: 'Critical: ${s.task.title}',
          detail: 'Due ${Fmt.date(s.due)} (${Fmt.daysWord(days)}). '
              'Long lead-time item — slipping it cascades downstream.',
          taskId: s.task.id,
        ));
      }
    }

    // 3. Dependency conflicts — an open task whose prerequisite is still open
    //    and which is due within three weeks.
    final byId = {for (final s in scheduled) s.task.id: s};
    for (final s in scheduled) {
      if (s.task.isDone) continue;
      if (s.daysUntilDue(today) > 21) continue;
      for (final depId in s.task.dependencies) {
        final dep = byId[depId];
        if (dep != null && !dep.task.isDone) {
          insights.add(Insight(
            severity: InsightSeverity.warning,
            category: InsightCategory.dependency,
            title: 'Blocked: ${s.task.title}',
            detail: 'Needs "${dep.task.title}" done first — that\'s still open.',
            taskId: dep.task.id,
          ));
          break;
        }
      }
    }

    // 4. Budget health.
    final totalActual = budget.fold<int>(0, (a, b) => a + b.actual);
    if (profile.budget > 0 && totalActual > profile.budget) {
      insights.add(Insight(
        severity: InsightSeverity.critical,
        category: InsightCategory.budget,
        title: 'Over budget',
        detail: 'Spent ${Fmt.inr(totalActual)} against your '
            '${Fmt.inr(profile.budget)} cap.',
      ));
    }
    for (final b in budget.where((b) => b.actual > b.planned && b.planned > 0)) {
      insights.add(Insight(
        severity: InsightSeverity.warning,
        category: InsightCategory.budget,
        title: '${b.category} over plan',
        detail: 'Spent ${Fmt.inr(b.actual)} vs planned ${Fmt.inr(b.planned)} '
            '(+${Fmt.inr(b.variance)}).',
      ));
    }

    // 5. Unbooked critical vendors.
    final present = vendors.map((v) => v.type).toSet();
    for (final type in _criticalVendorTypes) {
      final match = vendors.where((v) => v.type == type).toList();
      final booked = match.any((v) => v.booked);
      if (!booked) {
        insights.add(Insight(
          severity: InsightSeverity.warning,
          category: InsightCategory.vendor,
          title: present.contains(type) ? '$type not confirmed' : 'No $type yet',
          detail: 'A confirmed $type is essential — lock this in soon.',
        ));
      }
    }

    // 6. Pending vendor payments.
    final due = vendors.where((v) => v.balance > 0).toList();
    if (due.isNotEmpty) {
      final total = due.fold<int>(0, (a, v) => a + v.balance);
      insights.add(Insight(
        severity: InsightSeverity.info,
        category: InsightCategory.payment,
        title: '${Fmt.inr(total)} in pending payments',
        detail: 'Across ${due.length} vendor(s): '
            '${due.take(3).map((v) => v.name).join(', ')}.',
      ));
    }

    // 7. A gentle win when things look healthy.
    if (overdue.isEmpty) {
      final total = scheduled.length;
      final done = scheduled.where((s) => s.task.isDone).length;
      if (total > 0 && done / total >= 0.4) {
        insights.add(Insight(
          severity: InsightSeverity.positive,
          category: InsightCategory.progress,
          title: 'On track',
          detail: 'Nothing overdue and you\'re ${(done / total * 100).round()}% '
              'through your roadmap. Keep going!',
        ));
      }
    }

    insights.sort((a, b) => b.rank.compareTo(a.rank));
    return insights;
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
