import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../models/other_models.dart';
import '../state/providers.dart';
import '../widgets/common.dart';

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budget = ref.watch(budgetProvider);
    final profile = ref.watch(profileProvider);
    final theme = Theme.of(context);

    final planned = budget.fold<int>(0, (s, b) => s + b.planned);
    final actual = budget.fold<int>(0, (s, b) => s + b.actual);
    final remaining = profile.budget - actual;

    final palette = <Color>[
      Colors.pink, Colors.orange, Colors.teal, Colors.indigo,
      Colors.green, Colors.amber, Colors.purple, Colors.cyan,
      Colors.redAccent, Colors.blueGrey,
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        Text('Budget',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Cap ${Fmt.inr(profile.budget)} • Planned ${Fmt.inr(planned)} • Spent ${Fmt.inr(actual)}',
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 16),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  height: 180,
                  child: budget.isEmpty
                      ? const EmptyState(icon: Icons.pie_chart, message: 'Add budget lines to see the split.')
                      : PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 44,
                            sections: [
                              for (var i = 0; i < budget.length; i++)
                                if (budget[i].planned > 0)
                                  PieChartSectionData(
                                    value: budget[i].planned.toDouble(),
                                    color: palette[i % palette.length],
                                    radius: 44,
                                    showTitle: false,
                                  ),
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: profile.budget == 0 ? 0 : (actual / profile.budget).clamp(0, 1).toDouble(),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                  color: remaining < 0 ? Colors.redAccent : theme.colorScheme.primary,
                ),
                const SizedBox(height: 6),
                Text(
                  remaining >= 0
                      ? '${Fmt.inr(remaining)} left within your cap'
                      : 'Over cap by ${Fmt.inr(-remaining)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: remaining < 0 ? Colors.redAccent : theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        SectionHeader('Categories', trailing: IconButton(
          icon: const Icon(Icons.add),
          onPressed: () => _editBudget(context, ref, null),
        )),
        for (var i = 0; i < budget.length; i++)
          _BudgetRow(item: budget[i], color: palette[i % palette.length]),
      ],
    );
  }
}

class _BudgetRow extends ConsumerWidget {
  final BudgetItem item;
  final Color color;
  const _BudgetRow({required this.item, required this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final over = item.actual > item.planned;
    final ratio = item.planned == 0 ? 0.0 : (item.actual / item.planned).clamp(0, 1).toDouble();
    return Card(
      child: ListTile(
        leading: CircleAvatar(radius: 8, backgroundColor: color),
        title: Text(item.category, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(
                value: ratio,
                minHeight: 5,
                borderRadius: BorderRadius.circular(3),
                color: over ? Colors.redAccent : color,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
              const SizedBox(height: 4),
              Text('${Fmt.inr(item.actual)} of ${Fmt.inr(item.planned)}'
                  '${over ? '  •  over by ${Fmt.inr(item.variance)}' : ''}',
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: over ? Colors.redAccent : theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        onTap: () => _editBudget(context, ref, item),
      ),
    );
  }
}

void _editBudget(BuildContext context, WidgetRef ref, BudgetItem? existing) {
  final category = TextEditingController(text: existing?.category ?? '');
  final planned = TextEditingController(text: existing?.planned.toString() ?? '');
  final actual = TextEditingController(text: existing?.actual.toString() ?? '');

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(existing == null ? 'Add category' : 'Edit category',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(controller: category, decoration: const InputDecoration(labelText: 'Category')),
          const SizedBox(height: 10),
          TextField(controller: planned, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Planned (₹)')),
          const SizedBox(height: 10),
          TextField(controller: actual, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Actual spent (₹)')),
          const SizedBox(height: 16),
          Row(
            children: [
              if (existing != null)
                TextButton.icon(
                  onPressed: () {
                    ref.read(budgetProvider.notifier).remove(existing.id);
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
              const Spacer(),
              FilledButton(
                onPressed: () {
                  final item = (existing ?? BudgetItem(category: '')).copyWith(
                    category: category.text.trim().isEmpty ? 'Misc' : category.text.trim(),
                    planned: int.tryParse(planned.text) ?? 0,
                    actual: int.tryParse(actual.text) ?? 0,
                  );
                  final notifier = ref.read(budgetProvider.notifier);
                  existing == null ? notifier.add(item) : notifier.update(item);
                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
