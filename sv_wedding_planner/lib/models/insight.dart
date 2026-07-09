/// A proactive, AI-planner-style observation about the wedding plan.
///
/// The [InsightsEngine] derives these from the live roadmap, budget and vendor
/// state so the app can answer "what's delayed?", "what am I forgetting?" and
/// "what will be affected if this slips?" without the user having to ask.
enum InsightSeverity { critical, warning, info, positive }

enum InsightCategory { overdue, criticalPath, dependency, budget, vendor, payment, upcoming, progress }

class Insight {
  final InsightSeverity severity;
  final InsightCategory category;
  final String title;
  final String detail;

  /// Optional anchor to a task so the UI can deep-link into it.
  final String? taskId;

  const Insight({
    required this.severity,
    required this.category,
    required this.title,
    required this.detail,
    this.taskId,
  });

  /// Higher = surfaced first.
  int get rank {
    switch (severity) {
      case InsightSeverity.critical:
        return 4;
      case InsightSeverity.warning:
        return 3;
      case InsightSeverity.info:
        return 2;
      case InsightSeverity.positive:
        return 1;
    }
  }
}
