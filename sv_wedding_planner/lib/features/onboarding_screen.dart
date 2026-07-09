import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../models/enums.dart';
import '../models/wedding_profile.dart';
import '../state/providers.dart';
import 'home_shell.dart';

/// Conversational interview that captures the [WeddingProfile]. As the user
/// answers, the live task count updates to show the knowledge engine narrowing.
class OnboardingScreen extends ConsumerStatefulWidget {
  final bool editing;
  const OnboardingScreen({super.key, this.editing = false});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late WeddingProfile _p;
  final _groom = TextEditingController();
  final _bride = TextEditingController();

  @override
  void initState() {
    super.initState();
    _p = ref.read(profileProvider);
    _groom.text = _p.coupleGroom;
    _bride.text = _p.coupleBride;
  }

  Future<void> _pickDate(DateTime? current, ValueChanged<DateTime> onPick) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime(now.year + 1, now.month, now.day),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) onPick(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final masterAsync = ref.watch(masterTasksProvider);

    // Live preview of how many tasks this profile personalizes to.
    final previewCount = masterAsync.maybeWhen(
      data: (master) {
        final withStatus = master;
        return ref.read(personalizationEngineProvider).personalize(withStatus, _p).tasks.length;
      },
      orElse: () => null,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editing ? 'Wedding profile' : 'Let\'s personalize'),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 8,
          bottom: MediaQuery.of(context).padding.bottom + 12,
        ),
        child: FilledButton(
          onPressed: _save,
          child: Text(widget.editing ? 'Save & regenerate roadmap' : 'Generate my roadmap'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      previewCount == null
                          ? 'Loading the knowledge engine…'
                          : 'AI will personalize to ~$previewCount actionable tasks',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          _label('Who are you?'),
          Wrap(
            spacing: 8,
            children: [
              for (final persona in Persona.values)
                ChoiceChip(
                  label: Text(persona.label),
                  selected: _p.persona == persona,
                  onSelected: (_) => setState(() => _p = _p.copyWith(persona: persona)),
                ),
            ],
          ),
          const SizedBox(height: 16),

          _label('The couple'),
          TextField(controller: _groom, decoration: const InputDecoration(labelText: 'Groom name')),
          const SizedBox(height: 10),
          TextField(controller: _bride, decoration: const InputDecoration(labelText: 'Bride name')),
          const SizedBox(height: 16),

          _label('Key dates'),
          _dateTile('Wedding date', _p.weddingDate,
              (d) => setState(() => _p = _p.copyWith(weddingDate: d))),
          _dateTile('Reception date', _p.receptionDate,
              (d) => setState(() => _p = _p.copyWith(receptionDate: d))),
          _dateTile('Engagement date', _p.engagementDate,
              (d) => setState(() => _p = _p.copyWith(engagementDate: d))),
          _dateTile('Honeymoon date', _p.honeymoonDate,
              (d) => setState(() => _p = _p.copyWith(honeymoonDate: d))),
          const SizedBox(height: 16),

          _label('Religion'),
          _chips(['Hindu', 'Muslim', 'Christian', 'Sikh', 'Jain'], _p.religion,
              (v) => setState(() => _p = _p.copyWith(religion: v))),
          const SizedBox(height: 12),
          _label('Community'),
          _chips(['Maharashtrian', 'Punjabi', 'Gujarati', 'Tamil', 'Bengali', 'Marwari'],
              _p.community, (v) => setState(() => _p = _p.copyWith(community: v))),
          const SizedBox(height: 12),
          _label('Which side are you?'),
          _chips(['Groom', 'Bride', 'Both'], _sideLabel(_p.side), (v) {
            setState(() => _p = _p.copyWith(side: _sideFrom(v)));
          }),
          const SizedBox(height: 16),

          _label('Guest count: ${_p.guestCount}'),
          Slider(
            value: _p.guestCount.toDouble().clamp(50, 2000).toDouble(),
            min: 50, max: 2000, divisions: 39,
            label: '${_p.guestCount}',
            onChanged: (v) => setState(() => _p = _p.copyWith(guestCount: v.round())),
          ),
          _label('Budget: ${Fmt.inr(_p.budget)}'),
          Slider(
            value: _p.budget.toDouble().clamp(500000, 20000000).toDouble(),
            min: 500000, max: 20000000, divisions: 39,
            label: Fmt.inr(_p.budget),
            onChanged: (v) => setState(() => _p = _p.copyWith(budget: v.round())),
          ),
          const SizedBox(height: 8),

          _switch('Reception included', _p.receptionIncluded,
              (v) => setState(() => _p = _p.copyWith(receptionIncluded: v))),
          _switch('Honeymoon included', _p.honeymoonIncluded,
              (v) => setState(() => _p = _p.copyWith(honeymoonIncluded: v))),
          _switch('Destination wedding', _p.destinationWedding,
              (v) => setState(() => _p = _p.copyWith(destinationWedding: v))),
          _switch('Pure vegetarian', _p.vegetarian,
              (v) => setState(() => _p = _p.copyWith(vegetarian: v))),
          _switch('Alcohol / bar', _p.alcohol,
              (v) => setState(() => _p = _p.copyWith(alcohol: v))),
          const Divider(height: 32),
          _label('Already handled?'),
          _switch('Venue booked', _p.venueBooked,
              (v) => setState(() => _p = _p.copyWith(venueBooked: v))),
          _switch('Photographer booked', _p.photographerBooked,
              (v) => setState(() => _p = _p.copyWith(photographerBooked: v))),
          _switch('Decorator booked', _p.decoratorBooked,
              (v) => setState(() => _p = _p.copyWith(decoratorBooked: v))),
          _switch('Engagement done', _p.engagementDone,
              (v) => setState(() => _p = _p.copyWith(engagementDone: v))),
          _switch('Shopping started', _p.shoppingStarted,
              (v) => setState(() => _p = _p.copyWith(shoppingStarted: v))),
        ],
      ),
    );
  }

  void _save() {
    final finalProfile = _p.copyWith(
      coupleGroom: _groom.text.trim(),
      coupleBride: _bride.text.trim(),
    );
    ref.read(profileProvider.notifier).update(finalProfile);
    if (widget.editing) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeShell()),
      );
    }
  }

  Widget _label(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(s, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
      );

  Widget _chips(List<String> options, String selected, ValueChanged<String> onSelect) => Wrap(
        spacing: 8,
        children: [
          for (final o in options)
            ChoiceChip(
              label: Text(o),
              selected: selected.toLowerCase() == o.toLowerCase(),
              onSelected: (_) => onSelect(o),
            ),
        ],
      );

  Widget _dateTile(String label, DateTime? date, ValueChanged<DateTime> onPick) => Card(
        child: ListTile(
          leading: const Icon(Icons.event),
          title: Text(label),
          trailing: Text(Fmt.date(date), style: const TextStyle(fontWeight: FontWeight.w600)),
          onTap: () => _pickDate(date, onPick),
        ),
      );

  Widget _switch(String label, bool value, ValueChanged<bool> onChanged) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(label),
        value: value,
        onChanged: onChanged,
      );

  String _sideLabel(WeddingSide s) => switch (s) {
        WeddingSide.brideSide => 'Bride',
        WeddingSide.groomSide => 'Groom',
        WeddingSide.both => 'Both',
      };

  WeddingSide _sideFrom(String v) => switch (v.toLowerCase()) {
        'bride' => WeddingSide.brideSide,
        'groom' => WeddingSide.groomSide,
        _ => WeddingSide.both,
      };
}
