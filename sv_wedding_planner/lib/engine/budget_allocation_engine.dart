import '../models/other_models.dart';

/// Splits a single total wedding budget into per-category planned amounts using
/// industry thumb-rules for Indian weddings (2026). The user gives ONE number —
/// their total budget — and the app bifurcates it the way a planner would.
///
/// Percentages are grounded in 2026 Indian-wedding budget breakdowns
/// (venue + catering ≈ 45-55%, attire + jewellery ≈ 15-20%, ~4% contingency).
class BudgetAllocationEngine {
  const BudgetAllocationEngine();

  /// Category → share of total (must sum to 1.0).
  static const Map<String, double> thumbRule = {
    'Venue': 0.17,
    'Catering': 0.25,
    'Decoration': 0.09,
    'Photography': 0.08,
    'Clothing': 0.08,
    'Jewellery': 0.11,
    'Makeup': 0.03,
    'Entertainment': 0.03,
    'Travel & Honeymoon': 0.05,
    'Accommodation': 0.02,
    'Gifts': 0.02,
    'Miscellaneous': 0.03,
    'Contingency': 0.04,
  };

  /// Returns budget lines whose planned amounts sum to [total].
  ///
  /// If [previous] is supplied, actual-spent values are carried over for any
  /// category that still exists, so re-allocating never wipes recorded spends.
  List<BudgetItem> allocate(int total, {List<BudgetItem> previous = const []}) {
    final actuals = {for (final b in previous) b.category: b.actual};
    final items = <BudgetItem>[];
    var assigned = 0;
    final entries = thumbRule.entries.toList();

    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      // Give the last category the rounding remainder so the sum is exact.
      final planned = i == entries.length - 1
          ? total - assigned
          : (total * e.value).round();
      assigned += planned;
      items.add(BudgetItem(
        category: e.key,
        planned: planned < 0 ? 0 : planned,
        actual: actuals[e.key] ?? 0,
      ));
    }
    return items;
  }

  /// A human-readable one-line preview, e.g. for the onboarding screen.
  List<MapEntry<String, int>> preview(int total) =>
      allocate(total).map((b) => MapEntry(b.category, b.planned)).toList();
}
