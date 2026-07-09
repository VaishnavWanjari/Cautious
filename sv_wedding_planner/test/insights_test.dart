import 'package:flutter_test/flutter_test.dart';
import 'package:sv_wedding_planner/engine/insights_engine.dart';
import 'package:sv_wedding_planner/engine/reminder_engine.dart';
import 'package:sv_wedding_planner/models/enums.dart';
import 'package:sv_wedding_planner/models/insight.dart';
import 'package:sv_wedding_planner/models/other_models.dart';
import 'package:sv_wedding_planner/models/wedding_profile.dart';
import 'package:sv_wedding_planner/models/wedding_task.dart';

ScheduledTask _task(String id, DateTime due,
    {Priority priority = Priority.medium,
    bool done = false,
    List<String> deps = const []}) {
  return ScheduledTask(
    task: WeddingTask(
      id: id,
      title: 'Task $id',
      description: '',
      category: 'Test',
      priority: priority,
      dependencies: deps,
      status: done ? TaskStatus.done : TaskStatus.notStarted,
    ),
    start: due.subtract(const Duration(days: 3)),
    due: due,
  );
}

void main() {
  final now = DateTime(2026, 1, 1);

  group('InsightsEngine', () {
    test('flags overdue tasks as critical', () {
      final scheduled = [_task('A', DateTime(2025, 12, 20))];
      final out = const InsightsEngine().analyze(
        scheduled: scheduled,
        budget: const [],
        vendors: const [],
        profile: const WeddingProfile(),
        now: now,
      );
      expect(out.any((i) => i.category == InsightCategory.overdue), isTrue);
      expect(out.first.severity, InsightSeverity.critical);
    });

    test('flags over-budget spend', () {
      final out = const InsightsEngine().analyze(
        scheduled: const [],
        budget: [BudgetItem(category: 'Venue', planned: 100, actual: 500)],
        vendors: const [],
        profile: const WeddingProfile(budget: 300),
        now: now,
      );
      expect(out.any((i) => i.category == InsightCategory.budget), isTrue);
    });

    test('flags a blocked dependency', () {
      final scheduled = [
        _task('DEP', DateTime(2026, 1, 20), done: false),
        _task('B', DateTime(2026, 1, 10), deps: ['DEP']),
      ];
      final out = const InsightsEngine().analyze(
        scheduled: scheduled,
        budget: const [],
        vendors: const [],
        profile: const WeddingProfile(),
        now: now,
      );
      expect(out.any((i) => i.category == InsightCategory.dependency), isTrue);
    });

    test('reports a positive insight when healthy', () {
      final scheduled = [
        _task('A', DateTime(2026, 6, 1), done: true),
        _task('B', DateTime(2026, 6, 2), done: true),
        _task('C', DateTime(2026, 6, 3), done: false),
      ];
      final out = const InsightsEngine().analyze(
        scheduled: scheduled,
        budget: const [],
        vendors: const [],
        profile: const WeddingProfile(),
        now: now,
      );
      expect(out.any((i) => i.severity == InsightSeverity.positive), isTrue);
    });
  });

  group('ReminderEngine', () {
    test('overdue reminders sort before upcoming ones', () {
      final scheduled = [
        _task('UP', DateTime(2026, 3, 1)),
        _task('OVER', DateTime(2025, 12, 1)),
      ];
      final reminders = const ReminderEngine().build(scheduled, now: now);
      expect(reminders.first.taskId, 'OVER');
      expect(reminders.first.overdue, isTrue);
    });

    test('skips completed tasks', () {
      final reminders = const ReminderEngine().build(
        [_task('DONE', DateTime(2026, 3, 1), done: true)],
        now: now,
      );
      expect(reminders, isEmpty);
    });
  });
}
