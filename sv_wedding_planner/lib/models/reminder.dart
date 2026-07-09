/// A single, timeline-derived reminder shown in the in-app agenda.
///
/// Reminders are computed from the scheduled roadmap — no OS scheduling is
/// required, so they work identically on every platform. The architecture is
/// ready to also hand these to an OS notification plugin (or FCM) later.
class Reminder {
  final String taskId;
  final String title;
  final DateTime remindOn;
  final DateTime dueOn;
  final String ceremony;
  final bool overdue;

  const Reminder({
    required this.taskId,
    required this.title,
    required this.remindOn,
    required this.dueOn,
    required this.ceremony,
    required this.overdue,
  });
}
