/// Real-world suggestion data (honeymoon destinations, shopping picks) plus a
/// service abstraction so the source can later become a live online feed.
///
/// The curated figures below are grounded in 2026 market data (indicative
/// land-only cost per couple, excluding airfare). A [RemoteLiveDataService]
/// backed by a search API or the AI Copilot can drop in behind [LiveDataService]
/// to return truly live prices once the user connects an account.
library;

class HoneymoonDestination {
  final String name;
  final String summary;
  final int costPerCoupleInr; // indicative, land-only, 2026
  final String bestSeason;
  final String visa;
  final bool passportRequired;

  const HoneymoonDestination({
    required this.name,
    required this.summary,
    required this.costPerCoupleInr,
    required this.bestSeason,
    required this.visa,
    required this.passportRequired,
  });
}

class ShoppingSuggestion {
  final String item;
  final String forPerson;
  final String brand;
  final int priceFromInr;

  const ShoppingSuggestion({
    required this.item,
    required this.forPerson,
    required this.brand,
    required this.priceFromInr,
  });
}

abstract class LiveDataService {
  /// Whether these results are live (fetched online) vs curated offline data.
  bool get isLive;

  Future<List<HoneymoonDestination>> honeymoonSuggestions({int? maxBudget});
  Future<List<ShoppingSuggestion>> shoppingSuggestions({String? forPerson});
}

/// Offline, curated real-world data. Always available, no network needed.
class CuratedLiveDataService implements LiveDataService {
  const CuratedLiveDataService();

  @override
  bool get isLive => false;

  static const _destinations = <HoneymoonDestination>[
    HoneymoonDestination(
      name: 'Andaman Islands',
      summary: 'No passport needed · pristine beaches & scuba',
      costPerCoupleInr: 40000,
      bestSeason: 'Oct–Apr',
      visa: 'Domestic (no visa)',
      passportRequired: false,
    ),
    HoneymoonDestination(
      name: 'Thailand',
      summary: 'Budget-friendly · beaches, islands & nightlife',
      costPerCoupleInr: 120000,
      bestSeason: 'Nov–Mar',
      visa: 'Visa-free / e-visa',
      passportRequired: true,
    ),
    HoneymoonDestination(
      name: 'Bali, Indonesia',
      summary: 'Great value · temples, rice terraces & villas',
      costPerCoupleInr: 130000,
      bestSeason: 'Apr–Oct (Dec ok)',
      visa: 'Visa on arrival',
      passportRequired: true,
    ),
    HoneymoonDestination(
      name: 'Mauritius',
      summary: 'Turquoise lagoons & luxury resorts',
      costPerCoupleInr: 180000,
      bestSeason: 'Oct–Apr',
      visa: 'Free on arrival',
      passportRequired: true,
    ),
    HoneymoonDestination(
      name: 'Maldives',
      summary: 'Overwater villas · peak romance in December',
      costPerCoupleInr: 250000,
      bestSeason: 'Nov–Apr',
      visa: 'Free on arrival',
      passportRequired: true,
    ),
    HoneymoonDestination(
      name: 'Santorini, Greece',
      summary: 'Iconic caldera sunsets & whitewashed villages',
      costPerCoupleInr: 380000,
      bestSeason: 'Apr–Oct',
      visa: 'Schengen visa',
      passportRequired: true,
    ),
    HoneymoonDestination(
      name: 'Switzerland',
      summary: 'Alpine winter romance · snow, trains & lakes',
      costPerCoupleInr: 400000,
      bestSeason: 'Dec–Mar (snow)',
      visa: 'Schengen visa',
      passportRequired: true,
    ),
  ];

  static const _shopping = <ShoppingSuggestion>[
    ShoppingSuggestion(item: 'Bridal Lehenga', forPerson: 'Bride', brand: 'Kalki Fashion', priceFromInr: 90000),
    ShoppingSuggestion(item: 'Bridal Lehenga (couture)', forPerson: 'Bride', brand: 'Sabyasachi / Manish Malhotra', priceFromInr: 300000),
    ShoppingSuggestion(item: 'Bridal Jewellery Set', forPerson: 'Bride', brand: 'Tanishq / Kalyan', priceFromInr: 250000),
    ShoppingSuggestion(item: 'Sabyasachi Sherwani', forPerson: 'Groom', brand: 'Sabyasachi', priceFromInr: 150000),
    ShoppingSuggestion(item: 'Sherwani + Safa', forPerson: 'Groom', brand: 'Manyavar', priceFromInr: 35000),
    ShoppingSuggestion(item: 'Mother-of-the-couple Saree', forPerson: 'Parents', brand: 'Nalli / Kanjivaram', priceFromInr: 40000),
    ShoppingSuggestion(item: 'Sangeet Outfits', forPerson: 'Siblings', brand: 'FabIndia / Aza', priceFromInr: 25000),
  ];

  @override
  Future<List<HoneymoonDestination>> honeymoonSuggestions({int? maxBudget}) async {
    final list = maxBudget == null
        ? _destinations
        : _destinations.where((d) => d.costPerCoupleInr <= maxBudget).toList();
    return list.isEmpty ? _destinations : list;
  }

  @override
  Future<List<ShoppingSuggestion>> shoppingSuggestions({String? forPerson}) async {
    if (forPerson == null) return _shopping;
    return _shopping.where((s) => s.forPerson == forPerson).toList();
  }
}
