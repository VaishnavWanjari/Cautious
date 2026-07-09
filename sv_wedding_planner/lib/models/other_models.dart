import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Vendor record for the vendor-management module.
class Vendor {
  final String id;
  final String name;
  final String type; // Photographer, Caterer, Decorator, DJ, Priest...
  final String phone;
  final int contractAmount;
  final int paidAmount;
  final double rating;
  final String notes;
  final bool booked;

  Vendor({
    String? id,
    required this.name,
    required this.type,
    this.phone = '',
    this.contractAmount = 0,
    this.paidAmount = 0,
    this.rating = 0,
    this.notes = '',
    this.booked = false,
  }) : id = id ?? _uuid.v4();

  int get balance => contractAmount - paidAmount;

  Vendor copyWith({
    String? name,
    String? type,
    String? phone,
    int? contractAmount,
    int? paidAmount,
    double? rating,
    String? notes,
    bool? booked,
  }) =>
      Vendor(
        id: id,
        name: name ?? this.name,
        type: type ?? this.type,
        phone: phone ?? this.phone,
        contractAmount: contractAmount ?? this.contractAmount,
        paidAmount: paidAmount ?? this.paidAmount,
        rating: rating ?? this.rating,
        notes: notes ?? this.notes,
        booked: booked ?? this.booked,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'phone': phone,
        'contractAmount': contractAmount,
        'paidAmount': paidAmount,
        'rating': rating,
        'notes': notes,
        'booked': booked,
      };

  factory Vendor.fromJson(Map<String, dynamic> j) => Vendor(
        id: j['id'],
        name: j['name'],
        type: j['type'],
        phone: j['phone'] ?? '',
        contractAmount: (j['contractAmount'] ?? 0) as int,
        paidAmount: (j['paidAmount'] ?? 0) as int,
        rating: (j['rating'] ?? 0).toDouble(),
        notes: j['notes'] ?? '',
        booked: j['booked'] ?? false,
      );
}

/// Planned-vs-actual budget line.
class BudgetItem {
  final String id;
  final String category;
  final int planned;
  final int actual;

  BudgetItem({
    String? id,
    required this.category,
    this.planned = 0,
    this.actual = 0,
  }) : id = id ?? _uuid.v4();

  int get variance => actual - planned;

  BudgetItem copyWith({String? category, int? planned, int? actual}) => BudgetItem(
        id: id,
        category: category ?? this.category,
        planned: planned ?? this.planned,
        actual: actual ?? this.actual,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'category': category, 'planned': planned, 'actual': actual};

  factory BudgetItem.fromJson(Map<String, dynamic> j) => BudgetItem(
        id: j['id'],
        category: j['category'],
        planned: (j['planned'] ?? 0) as int,
        actual: (j['actual'] ?? 0) as int,
      );
}

/// Shopping planner entry, scoped to a person.
class ShoppingItem {
  final String id;
  final String name;
  final String forPerson; // Bride, Groom, Parents, Siblings, Family
  final int budget;
  final String store;
  final bool purchased;

  ShoppingItem({
    String? id,
    required this.name,
    required this.forPerson,
    this.budget = 0,
    this.store = '',
    this.purchased = false,
  }) : id = id ?? _uuid.v4();

  ShoppingItem copyWith({
    String? name,
    String? forPerson,
    int? budget,
    String? store,
    bool? purchased,
  }) =>
      ShoppingItem(
        id: id,
        name: name ?? this.name,
        forPerson: forPerson ?? this.forPerson,
        budget: budget ?? this.budget,
        store: store ?? this.store,
        purchased: purchased ?? this.purchased,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'forPerson': forPerson,
        'budget': budget,
        'store': store,
        'purchased': purchased,
      };

  factory ShoppingItem.fromJson(Map<String, dynamic> j) => ShoppingItem(
        id: j['id'],
        name: j['name'],
        forPerson: j['forPerson'],
        budget: (j['budget'] ?? 0) as int,
        store: j['store'] ?? '',
        purchased: j['purchased'] ?? false,
      );
}

/// Guest / family record with RSVP tracking.
class Guest {
  final String id;
  final String name;
  final String side; // Bride / Groom
  final int seats;
  final String rsvp; // Pending / Yes / No
  final bool invited;

  Guest({
    String? id,
    required this.name,
    this.side = 'Both',
    this.seats = 1,
    this.rsvp = 'Pending',
    this.invited = false,
  }) : id = id ?? _uuid.v4();

  Guest copyWith({
    String? name,
    String? side,
    int? seats,
    String? rsvp,
    bool? invited,
  }) =>
      Guest(
        id: id,
        name: name ?? this.name,
        side: side ?? this.side,
        seats: seats ?? this.seats,
        rsvp: rsvp ?? this.rsvp,
        invited: invited ?? this.invited,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'side': side,
        'seats': seats,
        'rsvp': rsvp,
        'invited': invited,
      };

  factory Guest.fromJson(Map<String, dynamic> j) => Guest(
        id: j['id'],
        name: j['name'],
        side: j['side'] ?? 'Both',
        seats: (j['seats'] ?? 1) as int,
        rsvp: j['rsvp'] ?? 'Pending',
        invited: j['invited'] ?? false,
      );
}
