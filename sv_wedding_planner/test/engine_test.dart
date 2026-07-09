import 'package:flutter_test/flutter_test.dart';
import 'package:sv_wedding_planner/engine/personalization_engine.dart';
import 'package:sv_wedding_planner/engine/timeline_engine.dart';
import 'package:sv_wedding_planner/models/enums.dart';
import 'package:sv_wedding_planner/models/wedding_profile.dart';
import 'package:sv_wedding_planner/models/wedding_task.dart';

List<WeddingTask> _sample() => [
      const WeddingTask(
        id: 'A',
        title: 'Book venue',
        description: '',
        category: 'Venue',
        ceremony: Ceremony.wedding,
        priority: Priority.critical,
        mandatory: true,
        startOffsetDays: -200,
        estimatedDurationDays: 10,
        bufferDays: 5,
      ),
      const WeddingTask(
        id: 'B',
        title: 'Confirm mandap layout',
        description: '',
        category: 'Venue',
        ceremony: Ceremony.wedding,
        priority: Priority.high,
        dependencies: ['A'],
        startOffsetDays: -30,
        estimatedDurationDays: 2,
      ),
      const WeddingTask(
        id: 'C',
        title: 'Honeymoon flights',
        description: '',
        category: 'Honeymoon',
        ceremony: Ceremony.honeymoon,
        priority: Priority.medium,
        weddingTypes: ['honeymoon'],
        startOffsetDays: -60,
      ),
    ];

void main() {
  group('PersonalizationEngine', () {
    test('keeps honeymoon task when honeymoon is included', () {
      final res = const PersonalizationEngine()
          .personalize(_sample(), const WeddingProfile(honeymoonIncluded: true));
      expect(res.tasks.any((t) => t.id == 'C'), isTrue);
      expect(res.funnel.first.count, 3);
    });

    test('drops honeymoon task when honeymoon is excluded', () {
      final res = const PersonalizationEngine()
          .personalize(_sample(), const WeddingProfile(honeymoonIncluded: false));
      expect(res.tasks.any((t) => t.id == 'C'), isFalse);
    });

    test('ranks mandatory critical tasks first', () {
      final res = const PersonalizationEngine()
          .personalize(_sample(), const WeddingProfile());
      expect(res.tasks.first.id, 'A');
    });
  });

  group('TimelineEngine', () {
    test('a dependent task is never due before its prerequisite finishes', () {
      final wedding = DateTime(2026, 11, 25);
      final scheduled = const TimelineEngine()
          .schedule(_sample(), WeddingProfile(weddingDate: wedding));
      final a = scheduled.firstWhere((s) => s.task.id == 'A');
      final b = scheduled.firstWhere((s) => s.task.id == 'B');
      expect(b.start.isAfter(a.due) || b.start.isAtSameMomentAs(a.due), isTrue);
    });

    test('schedule is sorted by due date', () {
      final scheduled = const TimelineEngine()
          .schedule(_sample(), WeddingProfile(weddingDate: DateTime(2026, 11, 25)));
      for (var i = 1; i < scheduled.length; i++) {
        expect(scheduled[i].due.isBefore(scheduled[i - 1].due), isFalse);
      }
    });
  });
}
