/// Core enumerations for the SV Wedding Planner knowledge engine.

enum Persona { bride, groom, parent, planner, family }

enum WeddingSide { brideSide, groomSide, both }

enum Ceremony {
  roka,
  engagement,
  sakharpuda,
  haldi,
  mehendi,
  sangeet,
  wedding,
  reception,
  honeymoon,
  postWedding,
}

enum Priority { critical, high, medium, low }

enum TaskStatus { notStarted, inProgress, blocked, done }

extension CeremonyLabel on Ceremony {
  String get label {
    switch (this) {
      case Ceremony.roka:
        return 'Roka';
      case Ceremony.engagement:
        return 'Engagement';
      case Ceremony.sakharpuda:
        return 'Sakharpuda';
      case Ceremony.haldi:
        return 'Haldi';
      case Ceremony.mehendi:
        return 'Mehendi';
      case Ceremony.sangeet:
        return 'Sangeet';
      case Ceremony.wedding:
        return 'Wedding';
      case Ceremony.reception:
        return 'Reception';
      case Ceremony.honeymoon:
        return 'Honeymoon';
      case Ceremony.postWedding:
        return 'Post-Wedding';
    }
  }
}

extension PriorityMeta on Priority {
  String get label {
    switch (this) {
      case Priority.critical:
        return 'Critical';
      case Priority.high:
        return 'High';
      case Priority.medium:
        return 'Medium';
      case Priority.low:
        return 'Low';
    }
  }

  /// Higher weight = scheduled earlier / surfaced first.
  int get weight {
    switch (this) {
      case Priority.critical:
        return 4;
      case Priority.high:
        return 3;
      case Priority.medium:
        return 2;
      case Priority.low:
        return 1;
    }
  }
}

extension PersonaLabel on Persona {
  String get label {
    switch (this) {
      case Persona.bride:
        return 'Bride';
      case Persona.groom:
        return 'Groom';
      case Persona.parent:
        return 'Parent';
      case Persona.planner:
        return 'Wedding Planner';
      case Persona.family:
        return 'Family Member';
    }
  }
}

Ceremony? ceremonyFromString(String raw) {
  for (final c in Ceremony.values) {
    if (c.name.toLowerCase() == raw.toLowerCase()) return c;
  }
  return null;
}

Priority priorityFromString(String raw) {
  for (final p in Priority.values) {
    if (p.name.toLowerCase() == raw.toLowerCase()) return p;
  }
  return Priority.medium;
}
