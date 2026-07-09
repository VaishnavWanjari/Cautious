import '../models/enums.dart';
import '../models/wedding_profile.dart';
import '../models/wedding_task.dart';

/// The heart of the app: progressively filters the master task knowledge base
/// down to the tasks that actually apply to a given [WeddingProfile], the way
/// an experienced planner would prune a generic checklist to your wedding.
///
/// Each stage narrows the set (persona -> religion -> community -> type ->
/// bookings -> ...), and every result carries a short explanation of *why* the
/// funnel produced this count, which the UI surfaces to the user.
class PersonalizationEngine {
  const PersonalizationEngine();

  PersonalizationResult personalize(
    List<WeddingTask> master,
    WeddingProfile p,
  ) {
    final funnel = <FunnelStage>[];
    var current = master;
    funnel.add(FunnelStage('Master knowledge base', current.length));

    // 1. Persona relevance.
    current = current.where((t) => _personaMatches(t, p)).toList();
    funnel.add(FunnelStage('${p.persona.label} relevance', current.length));

    // 2. Side (bride/groom side) relevance.
    current = current.where((t) => _sideMatches(t, p)).toList();
    funnel.add(FunnelStage('${_sideLabel(p.side)} side', current.length));

    // 3. Religion.
    current = current.where((t) => _listMatches(t.religions, p.religion)).toList();
    funnel.add(FunnelStage(p.religion.isEmpty ? 'Religion' : p.religion, current.length));

    // 4. Community.
    current =
        current.where((t) => _listMatches(t.communities, p.community)).toList();
    funnel.add(FunnelStage(
        p.community.isEmpty ? 'Community' : p.community, current.length));

    // 5. Wedding-type toggles (reception / honeymoon / destination / diet).
    current = current.where((t) => _weddingTypeMatches(t, p)).toList();
    funnel.add(FunnelStage('Wedding style', current.length));

    // 6. Scale (guest count & budget floor).
    current = current
        .where((t) => p.guestCount >= t.minGuestCount && p.budget >= t.minBudget)
        .toList();
    funnel.add(FunnelStage('Scale (guests & budget)', current.length));

    // 7. Existing bookings prune already-handled work.
    current = current.where((t) => !_alreadyHandled(t, p)).toList();
    funnel.add(FunnelStage('Existing bookings removed', current.length));

    // 8. AI optimisation: rank by priority, mandatory flag and confidence,
    //    then keep the most actionable slice (~150-200 items).
    current.sort((a, b) => _score(b).compareTo(_score(a)));
    final capped = current.take(200).toList();
    funnel.add(FunnelStage('AI-optimised roadmap', capped.length));

    return PersonalizationResult(tasks: capped, funnel: funnel);
  }

  bool _personaMatches(WeddingTask t, WeddingProfile p) {
    if (t.applicablePersonas.isEmpty) return true;
    // Planners and parents see everything relevant to the couple.
    if (p.persona == Persona.planner || p.persona == Persona.parent) return true;
    return t.applicablePersonas.contains(p.persona) ||
        t.applicablePersonas.contains(Persona.family);
  }

  bool _sideMatches(WeddingTask t, WeddingProfile p) {
    if (t.side == WeddingSide.both || p.side == WeddingSide.both) return true;
    if (p.persona == Persona.planner) return true;
    return t.side == p.side;
  }

  bool _listMatches(List<String> allowed, String value) {
    if (allowed.isEmpty) return true; // applies to everyone
    if (value.isEmpty) return true; // user hasn't specified — don't prune
    return allowed.any((a) => a.toLowerCase() == value.toLowerCase());
  }

  bool _weddingTypeMatches(WeddingTask t, WeddingProfile p) {
    if (t.weddingTypes.isEmpty) return true;
    for (final type in t.weddingTypes) {
      switch (type.toLowerCase()) {
        case 'reception':
          if (!p.receptionIncluded) return false;
          break;
        case 'honeymoon':
          if (!p.honeymoonIncluded) return false;
          break;
        case 'destination':
          if (!p.destinationWedding) return false;
          break;
        case 'vegetarian':
          if (!p.vegetarian) return false;
          break;
        case 'alcohol':
          if (!p.alcohol) return false;
          break;
      }
    }
    return true;
  }

  bool _alreadyHandled(WeddingTask t, WeddingProfile p) {
    final tags = t.tags.map((e) => e.toLowerCase()).toSet();
    if (p.venueBooked && t.id == 'VEN-001') return true;
    if (p.photographerBooked && t.id == 'PHO-001') return true;
    if (p.decoratorBooked && t.id == 'DEC-001') return true;
    if (p.engagementDone &&
        (t.ceremony == Ceremony.roka || t.ceremony == Ceremony.engagement)) {
      return true;
    }
    if (p.shoppingStarted && tags.contains('attire') && t.priority == Priority.low) {
      return true;
    }
    return false;
  }

  double _score(WeddingTask t) {
    var s = t.priority.weight * 100.0;
    if (t.mandatory) s += 250;
    s += t.aiConfidence * 20;
    return s;
  }

  String _sideLabel(WeddingSide s) {
    switch (s) {
      case WeddingSide.brideSide:
        return 'Bride';
      case WeddingSide.groomSide:
        return 'Groom';
      case WeddingSide.both:
        return 'Both';
    }
  }
}

class FunnelStage {
  final String label;
  final int count;
  const FunnelStage(this.label, this.count);
}

class PersonalizationResult {
  final List<WeddingTask> tasks;
  final List<FunnelStage> funnel;
  const PersonalizationResult({required this.tasks, required this.funnel});
}
