import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../data/seed_data.dart';
import '../models/other_models.dart';
import '../state/providers.dart';
import '../widgets/common.dart';

// ===========================================================================
// Vendors
// ===========================================================================
class VendorsScreen extends ConsumerWidget {
  const VendorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendors = ref.watch(vendorsProvider);
    final totalDue = vendors.fold<int>(0, (s, v) => s + v.balance);
    return Scaffold(
      appBar: AppBar(title: const Text('Vendors')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editVendor(context, ref, null),
        child: const Icon(Icons.add),
      ),
      body: vendors.isEmpty
          ? const EmptyState(icon: Icons.handshake, message: 'No vendors yet. Add your first.')
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                if (totalDue > 0)
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: ListTile(
                      leading: const Icon(Icons.payments),
                      title: Text('${Fmt.inr(totalDue)} in pending payments'),
                      subtitle: const Text('Across all vendors'),
                    ),
                  ),
                for (final v in vendors)
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(child: Text(v.type.isEmpty ? '?' : v.type[0])),
                      title: Text(v.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${v.type} • ${v.phone}'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          TintPill(v.booked ? 'Booked' : 'Pending',
                              color: v.booked ? Colors.green : Colors.orange),
                          if (v.balance > 0)
                            Text('due ${Fmt.inr(v.balance)}',
                                style: Theme.of(context).textTheme.labelSmall),
                        ],
                      ),
                      onTap: () => _editVendor(context, ref, v),
                    ),
                  ),
              ],
            ),
    );
  }
}

void _editVendor(BuildContext context, WidgetRef ref, Vendor? existing) {
  final name = TextEditingController(text: existing?.name ?? '');
  final type = TextEditingController(text: existing?.type ?? '');
  final phone = TextEditingController(text: existing?.phone ?? '');
  final contract = TextEditingController(text: existing?.contractAmount.toString() ?? '');
  final paid = TextEditingController(text: existing?.paidAmount.toString() ?? '');
  var booked = existing?.booked ?? false;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheet) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(existing == null ? 'Add vendor' : 'Edit vendor',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 10),
              TextField(controller: type, decoration: const InputDecoration(labelText: 'Type (Photographer, Caterer…)')),
              const SizedBox(height: 10),
              TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
              const SizedBox(height: 10),
              TextField(controller: contract, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Contract amount (₹)')),
              const SizedBox(height: 10),
              TextField(controller: paid, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Paid so far (₹)')),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Booked / confirmed'),
                value: booked,
                onChanged: (v) => setSheet(() => booked = v),
              ),
              Row(
                children: [
                  if (existing != null)
                    TextButton.icon(
                      onPressed: () {
                        ref.read(vendorsProvider.notifier).remove(existing.id);
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      final v = (existing ?? Vendor(name: '', type: '')).copyWith(
                        name: name.text.trim(),
                        type: type.text.trim().isEmpty ? 'Vendor' : type.text.trim(),
                        phone: phone.text.trim(),
                        contractAmount: int.tryParse(contract.text) ?? 0,
                        paidAmount: int.tryParse(paid.text) ?? 0,
                        booked: booked,
                      );
                      final n = ref.read(vendorsProvider.notifier);
                      existing == null ? n.add(v) : n.update(v);
                      Navigator.pop(context);
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ===========================================================================
// Shopping
// ===========================================================================
class ShoppingScreen extends ConsumerWidget {
  const ShoppingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(shoppingProvider);
    final groups = <String, List<ShoppingItem>>{};
    for (final it in items) {
      groups.putIfAbsent(it.forPerson, () => []).add(it);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Shopping Planner')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editShopping(context, ref, null),
        child: const Icon(Icons.add),
      ),
      body: items.isEmpty
          ? const EmptyState(icon: Icons.shopping_bag, message: 'No shopping items yet.')
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                for (final entry in groups.entries) ...[
                  SectionHeader(entry.key,
                      subtitle: '${Fmt.inr(entry.value.fold<int>(0, (s, i) => s + i.budget))} budgeted'),
                  for (final it in entry.value)
                    Card(
                      child: ListTile(
                        leading: Checkbox(
                          value: it.purchased,
                          onChanged: (v) => ref.read(shoppingProvider.notifier)
                              .update(it.copyWith(purchased: v ?? false)),
                        ),
                        title: Text(it.name,
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                decoration: it.purchased ? TextDecoration.lineThrough : null)),
                        subtitle: Text('${Fmt.inr(it.budget)}${it.store.isEmpty ? '' : ' • ${it.store}'}'),
                        onTap: () => _editShopping(context, ref, it),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}

void _editShopping(BuildContext context, WidgetRef ref, ShoppingItem? existing) {
  final name = TextEditingController(text: existing?.name ?? '');
  final store = TextEditingController(text: existing?.store ?? '');
  final budget = TextEditingController(text: existing?.budget.toString() ?? '');
  var person = existing?.forPerson ?? 'Bride';
  const people = ['Bride', 'Groom', 'Parents', 'Siblings', 'Family'];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheet) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(existing == null ? 'Add item' : 'Edit item',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Item')),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: person,
              decoration: const InputDecoration(labelText: 'For'),
              items: [for (final p in people) DropdownMenuItem(value: p, child: Text(p))],
              onChanged: (v) => setSheet(() => person = v ?? person),
            ),
            const SizedBox(height: 10),
            TextField(controller: store, decoration: const InputDecoration(labelText: 'Store')),
            const SizedBox(height: 10),
            TextField(controller: budget, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Budget (₹)')),
            const SizedBox(height: 16),
            Row(
              children: [
                if (existing != null)
                  TextButton.icon(
                    onPressed: () {
                      ref.read(shoppingProvider.notifier).remove(existing.id);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: () {
                    final it = (existing ?? ShoppingItem(name: '', forPerson: person)).copyWith(
                      name: name.text.trim(),
                      forPerson: person,
                      store: store.text.trim(),
                      budget: int.tryParse(budget.text) ?? 0,
                    );
                    final n = ref.read(shoppingProvider.notifier);
                    existing == null ? n.add(it) : n.update(it);
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

// ===========================================================================
// Guests
// ===========================================================================
class GuestsScreen extends ConsumerWidget {
  const GuestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guests = ref.watch(guestsProvider);
    final totalSeats = guests.fold<int>(0, (s, g) => s + g.seats);
    final confirmed = guests.where((g) => g.rsvp == 'Yes').fold<int>(0, (s, g) => s + g.seats);
    return Scaffold(
      appBar: AppBar(title: const Text('Guests & Family')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editGuest(context, ref, null),
        child: const Icon(Icons.add),
      ),
      body: guests.isEmpty
          ? const EmptyState(icon: Icons.groups, message: 'No guests yet.')
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.event_seat),
                    title: Text('$confirmed / $totalSeats seats confirmed'),
                    subtitle: Text('${guests.length} guest groups'),
                  ),
                ),
                for (final g in guests)
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(child: Text('${g.seats}')),
                      title: Text(g.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${g.side} side • ${g.seats} seats'),
                      trailing: TintPill(g.rsvp,
                          color: g.rsvp == 'Yes'
                              ? Colors.green
                              : g.rsvp == 'No'
                                  ? Colors.redAccent
                                  : Colors.orange),
                      onTap: () => _editGuest(context, ref, g),
                    ),
                  ),
              ],
            ),
    );
  }
}

void _editGuest(BuildContext context, WidgetRef ref, Guest? existing) {
  final name = TextEditingController(text: existing?.name ?? '');
  final seats = TextEditingController(text: existing?.seats.toString() ?? '1');
  var side = existing?.side ?? 'Groom';
  var rsvp = existing?.rsvp ?? 'Pending';

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheet) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(existing == null ? 'Add guest group' : 'Edit guest group',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name / group')),
            const SizedBox(height: 10),
            TextField(controller: seats, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Seats')),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: side,
                    decoration: const InputDecoration(labelText: 'Side'),
                    items: const [
                      DropdownMenuItem(value: 'Groom', child: Text('Groom')),
                      DropdownMenuItem(value: 'Bride', child: Text('Bride')),
                      DropdownMenuItem(value: 'Both', child: Text('Both')),
                    ],
                    onChanged: (v) => setSheet(() => side = v ?? side),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: rsvp,
                    decoration: const InputDecoration(labelText: 'RSVP'),
                    items: const [
                      DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                      DropdownMenuItem(value: 'Yes', child: Text('Yes')),
                      DropdownMenuItem(value: 'No', child: Text('No')),
                    ],
                    onChanged: (v) => setSheet(() => rsvp = v ?? rsvp),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (existing != null)
                  TextButton.icon(
                    onPressed: () {
                      ref.read(guestsProvider.notifier).remove(existing.id);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: () {
                    final g = (existing ?? Guest(name: '')).copyWith(
                      name: name.text.trim(),
                      seats: int.tryParse(seats.text) ?? 1,
                      side: side,
                      rsvp: rsvp,
                      invited: true,
                    );
                    final n = ref.read(guestsProvider.notifier);
                    existing == null ? n.add(g) : n.update(g);
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

// ===========================================================================
// Honeymoon
// ===========================================================================
class HoneymoonScreen extends ConsumerWidget {
  const HoneymoonScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Honeymoon Planner')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Card(
            color: theme.colorScheme.primaryContainer,
            child: ListTile(
              leading: const Icon(Icons.flight_takeoff),
              title: Text('Departing ${Fmt.date(profile.honeymoonDate)}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Suggested destinations for your season & budget'),
            ),
          ),
          const SizedBox(height: 8),
          for (final d in SeedData.honeymoonDestinations)
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.place)),
                title: Text(d.$1, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(d.$2),
                trailing: Text(Fmt.inr(d.$3),
                    style: theme.textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ),
          const SizedBox(height: 16),
          Text('Honeymoon checklist',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final item in const [
            'Passport valid 6+ months',
            'Visa applied',
            'Flights & hotels booked',
            'Travel insurance',
            'Forex / travel card',
            'Packing & itinerary',
          ])
            Card(child: ListTile(dense: true, leading: const Icon(Icons.check_circle_outline), title: Text(item))),
        ],
      ),
    );
  }
}
