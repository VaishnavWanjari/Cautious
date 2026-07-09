import 'enums.dart';

/// The user-supplied context that drives personalization. Every answer the
/// user gives in the conversational interview narrows the knowledge base.
class WeddingProfile {
  final String coupleGroom;
  final String coupleBride;
  final Persona persona;
  final WeddingSide side;

  final DateTime? weddingDate;
  final DateTime? receptionDate;
  final DateTime? engagementDate;
  final DateTime? honeymoonDate;

  final String religion; // e.g. Hindu, Muslim, Christian, Sikh
  final String community; // e.g. Maharashtrian, Punjabi, Tamil
  final String state; // Indian state
  final int budget; // INR
  final int guestCount;

  final bool receptionIncluded;
  final bool honeymoonIncluded;
  final bool destinationWedding;
  final bool vegetarian;
  final bool alcohol;

  // Existing bookings — used to prune tasks that are already handled.
  final bool venueBooked;
  final bool photographerBooked;
  final bool decoratorBooked;
  final bool engagementDone;
  final bool shoppingStarted;

  const WeddingProfile({
    this.coupleGroom = '',
    this.coupleBride = '',
    this.persona = Persona.groom,
    this.side = WeddingSide.both,
    this.weddingDate,
    this.receptionDate,
    this.engagementDate,
    this.honeymoonDate,
    this.religion = 'Hindu',
    this.community = '',
    this.state = '',
    this.budget = 2500000,
    this.guestCount = 300,
    this.receptionIncluded = true,
    this.honeymoonIncluded = true,
    this.destinationWedding = false,
    this.vegetarian = true,
    this.alcohol = false,
    this.venueBooked = false,
    this.photographerBooked = false,
    this.decoratorBooked = false,
    this.engagementDone = false,
    this.shoppingStarted = false,
  });

  bool get isComplete => weddingDate != null && coupleGroom.isNotEmpty;

  WeddingProfile copyWith({
    String? coupleGroom,
    String? coupleBride,
    Persona? persona,
    WeddingSide? side,
    DateTime? weddingDate,
    DateTime? receptionDate,
    DateTime? engagementDate,
    DateTime? honeymoonDate,
    String? religion,
    String? community,
    String? state,
    int? budget,
    int? guestCount,
    bool? receptionIncluded,
    bool? honeymoonIncluded,
    bool? destinationWedding,
    bool? vegetarian,
    bool? alcohol,
    bool? venueBooked,
    bool? photographerBooked,
    bool? decoratorBooked,
    bool? engagementDone,
    bool? shoppingStarted,
  }) {
    return WeddingProfile(
      coupleGroom: coupleGroom ?? this.coupleGroom,
      coupleBride: coupleBride ?? this.coupleBride,
      persona: persona ?? this.persona,
      side: side ?? this.side,
      weddingDate: weddingDate ?? this.weddingDate,
      receptionDate: receptionDate ?? this.receptionDate,
      engagementDate: engagementDate ?? this.engagementDate,
      honeymoonDate: honeymoonDate ?? this.honeymoonDate,
      religion: religion ?? this.religion,
      community: community ?? this.community,
      state: state ?? this.state,
      budget: budget ?? this.budget,
      guestCount: guestCount ?? this.guestCount,
      receptionIncluded: receptionIncluded ?? this.receptionIncluded,
      honeymoonIncluded: honeymoonIncluded ?? this.honeymoonIncluded,
      destinationWedding: destinationWedding ?? this.destinationWedding,
      vegetarian: vegetarian ?? this.vegetarian,
      alcohol: alcohol ?? this.alcohol,
      venueBooked: venueBooked ?? this.venueBooked,
      photographerBooked: photographerBooked ?? this.photographerBooked,
      decoratorBooked: decoratorBooked ?? this.decoratorBooked,
      engagementDone: engagementDone ?? this.engagementDone,
      shoppingStarted: shoppingStarted ?? this.shoppingStarted,
    );
  }

  Map<String, dynamic> toJson() => {
        'coupleGroom': coupleGroom,
        'coupleBride': coupleBride,
        'persona': persona.name,
        'side': side.name,
        'weddingDate': weddingDate?.toIso8601String(),
        'receptionDate': receptionDate?.toIso8601String(),
        'engagementDate': engagementDate?.toIso8601String(),
        'honeymoonDate': honeymoonDate?.toIso8601String(),
        'religion': religion,
        'community': community,
        'state': state,
        'budget': budget,
        'guestCount': guestCount,
        'receptionIncluded': receptionIncluded,
        'honeymoonIncluded': honeymoonIncluded,
        'destinationWedding': destinationWedding,
        'vegetarian': vegetarian,
        'alcohol': alcohol,
        'venueBooked': venueBooked,
        'photographerBooked': photographerBooked,
        'decoratorBooked': decoratorBooked,
        'engagementDone': engagementDone,
        'shoppingStarted': shoppingStarted,
      };

  static DateTime? _date(dynamic v) =>
      v == null ? null : DateTime.tryParse(v as String);

  factory WeddingProfile.fromJson(Map<String, dynamic> j) {
    Persona persona = Persona.groom;
    for (final p in Persona.values) {
      if (p.name == j['persona']) persona = p;
    }
    WeddingSide side = WeddingSide.both;
    for (final s in WeddingSide.values) {
      if (s.name == j['side']) side = s;
    }
    return WeddingProfile(
      coupleGroom: j['coupleGroom'] ?? '',
      coupleBride: j['coupleBride'] ?? '',
      persona: persona,
      side: side,
      weddingDate: _date(j['weddingDate']),
      receptionDate: _date(j['receptionDate']),
      engagementDate: _date(j['engagementDate']),
      honeymoonDate: _date(j['honeymoonDate']),
      religion: j['religion'] ?? 'Hindu',
      community: j['community'] ?? '',
      state: j['state'] ?? '',
      budget: (j['budget'] ?? 2500000) as int,
      guestCount: (j['guestCount'] ?? 300) as int,
      receptionIncluded: j['receptionIncluded'] ?? true,
      honeymoonIncluded: j['honeymoonIncluded'] ?? true,
      destinationWedding: j['destinationWedding'] ?? false,
      vegetarian: j['vegetarian'] ?? true,
      alcohol: j['alcohol'] ?? false,
      venueBooked: j['venueBooked'] ?? false,
      photographerBooked: j['photographerBooked'] ?? false,
      decoratorBooked: j['decoratorBooked'] ?? false,
      engagementDone: j['engagementDone'] ?? false,
      shoppingStarted: j['shoppingStarted'] ?? false,
    );
  }
}
