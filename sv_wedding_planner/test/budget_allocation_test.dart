import 'package:flutter_test/flutter_test.dart';
import 'package:sv_wedding_planner/engine/budget_allocation_engine.dart';
import 'package:sv_wedding_planner/models/other_models.dart';

void main() {
  const engine = BudgetAllocationEngine();

  test('thumb-rule percentages sum to 1.0', () {
    final total = BudgetAllocationEngine.thumbRule.values.fold<double>(0, (a, b) => a + b);
    expect((total - 1.0).abs() < 1e-9, isTrue);
  });

  test('allocated planned amounts sum exactly to the total', () {
    const total = 3500000;
    final items = engine.allocate(total);
    final sum = items.fold<int>(0, (a, b) => a + b.planned);
    expect(sum, total);
  });

  test('catering gets the largest slice', () {
    final items = engine.allocate(2000000);
    items.sort((a, b) => b.planned.compareTo(a.planned));
    expect(items.first.category, 'Catering');
  });

  test('re-allocation preserves recorded actuals', () {
    final previous = [BudgetItem(category: 'Venue', planned: 1, actual: 123456)];
    final items = engine.allocate(2000000, previous: previous);
    final venue = items.firstWhere((b) => b.category == 'Venue');
    expect(venue.actual, 123456);
  });
}
