import '../core/format.dart';
import '../models/enums.dart';
import '../models/other_models.dart';
import '../models/wedding_profile.dart';
import '../state/providers.dart';

/// A local, rule-based Wedding Copilot. It answers the planner-style questions
/// from the brief ("What should I do next?", "Am I missing anything?",
/// "Optimise my budget") using the live roadmap and finance state.
///
/// This is deliberately offline and deterministic so the app is useful without
/// any API key. The [respond] surface matches what a hosted LLM would consume,
/// so it can be swapped for a real model (e.g. Claude) without touching the UI.
class CopilotEngine {
  const CopilotEngine();

  CopilotReply respond(
    String query, {
    required Roadmap roadmap,
    required WeddingProfile profile,
    required List<BudgetItem> budget,
    required List<Vendor> vendors,
  }) {
    final q = query.toLowerCase();
    final now = DateTime.now();

    if (_matches(q, ['next', 'today', 'do now', 'start'])) {
      final focus = roadmap.scheduled
          .where((s) => !s.task.isDone)
          .take(4)
          .map((s) =>
              '• ${s.task.title}  —  due ${Fmt.date(s.due)} (${Fmt.daysWord(s.daysUntilDue(now))})')
          .toList();
      return CopilotReply(
        'Here\'s what I\'d tackle next:',
        focus.isEmpty ? ['You\'re all caught up! 🎉'] : focus,
      );
    }

    if (_matches(q, ['missing', 'forget', 'forgot', 'overlook'])) {
      final overdue = roadmap.scheduled.where((s) => s.isOverdue(now)).toList();
      final criticalPending = roadmap.scheduled
          .where((s) => !s.task.isDone && s.task.priority == Priority.critical)
          .take(4)
          .toList();
      final lines = <String>[];
      if (overdue.isNotEmpty) {
        lines.add('⚠️ ${overdue.length} task(s) are overdue:');
        lines.addAll(overdue.take(3).map((s) => '   • ${s.task.title}'));
      }
      if (criticalPending.isNotEmpty) {
        lines.add('🔴 Critical items still open:');
        lines.addAll(criticalPending.map((s) => '   • ${s.task.title}'));
      }
      return CopilotReply(
        lines.isEmpty ? 'Nothing critical is slipping — great job!' : 'I checked your roadmap:',
        lines.isEmpty ? const [] : lines,
      );
    }

    if (_matches(q, ['budget', 'money', 'save', 'cost', 'expense'])) {
      final planned = budget.fold<int>(0, (s, b) => s + b.planned);
      final actual = budget.fold<int>(0, (s, b) => s + b.actual);
      final overspent = budget.where((b) => b.actual > b.planned).toList();
      final lines = <String>[
        'Planned: ${Fmt.inr(planned)}  •  Spent: ${Fmt.inr(actual)}',
        'Remaining vs your ${Fmt.inr(profile.budget)} cap: ${Fmt.inr(profile.budget - actual)}',
      ];
      if (overspent.isNotEmpty) {
        lines.add('Watch these categories going over plan:');
        lines.addAll(overspent.map((b) => '   • ${b.category}: +${Fmt.inr(b.variance)}'));
      } else {
        lines.add('💡 Tip: book decor + florist together to negotiate a bundle.');
      }
      return CopilotReply('Budget health check:', lines);
    }

    if (_matches(q, ['honeymoon', 'destination', 'trip'])) {
      return CopilotReply(
        'For a December trip on your budget, I\'d suggest:',
        const [
          '• Maldives — peak-season sun, overwater villas',
          '• Bali — great value, easy visa-on-arrival',
          '• Andaman — no passport needed, pristine beaches',
        ],
      );
    }

    if (_matches(q, ['vendor', 'pending', 'payment', 'pay'])) {
      final unbooked = vendors.where((v) => !v.booked).toList();
      final due = vendors.where((v) => v.balance > 0).toList();
      final lines = <String>[
        if (unbooked.isNotEmpty)
          'Not booked yet: ${unbooked.map((v) => v.type).join(', ')}',
        if (due.isNotEmpty)
          'Balance due: ${Fmt.inr(due.fold<int>(0, (s, v) => s + v.balance))} across ${due.length} vendor(s)',
        if (unbooked.isEmpty && due.isEmpty) 'All vendors booked and paid. 👏',
      ];
      return CopilotReply('Vendor status:', lines);
    }

    if (_matches(q, ['postpone', 'delay', 'slip', 'move'])) {
      return CopilotReply(
        'You can move most tasks, but be careful with the critical path:',
        const [
          'Venue, caterer, photographer and outfits have long lead times —',
          'slipping them cascades onto everything downstream.',
          'Ask me "what am I missing" to see what\'s at risk.',
        ],
      );
    }

    // Default: progress summary.
    return CopilotReply(
      'You\'re ${(roadmap.progress * 100).round()}% through your roadmap '
      '(${roadmap.done}/${roadmap.total} tasks).',
      const [
        'Try asking me:',
        '   • "What should I do next?"',
        '   • "Am I missing anything?"',
        '   • "Optimise my budget"',
        '   • "Suggest honeymoon destinations"',
      ],
    );
  }

  bool _matches(String q, List<String> keys) => keys.any(q.contains);
}

class CopilotReply {
  final String headline;
  final List<String> lines;
  const CopilotReply(this.headline, this.lines);
}
