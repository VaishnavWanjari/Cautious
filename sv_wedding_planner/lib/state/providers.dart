import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/knowledge_base.dart';
import '../data/local_store.dart';
import '../engine/insights_engine.dart';
import '../engine/personalization_engine.dart';
import '../engine/reminder_engine.dart';
import '../engine/timeline_engine.dart';
import '../models/enums.dart';
import '../models/insight.dart';
import '../models/other_models.dart';
import '../models/reminder.dart';
import '../models/wedding_profile.dart';
import '../models/wedding_task.dart';

/// Injected at app start (see main.dart) so the whole tree shares one store.
final localStoreProvider = Provider<LocalStore>(
  (ref) => throw UnimplementedError('localStoreProvider must be overridden'),
);

final knowledgeBaseProvider = Provider<KnowledgeBase>((ref) => const KnowledgeBase());
final personalizationEngineProvider =
    Provider<PersonalizationEngine>((ref) => const PersonalizationEngine());
final timelineEngineProvider = Provider<TimelineEngine>((ref) => const TimelineEngine());
final insightsEngineProvider = Provider<InsightsEngine>((ref) => const InsightsEngine());
final reminderEngineProvider = Provider<ReminderEngine>((ref) => const ReminderEngine());

/// Raw master task list loaded from the knowledge engine asset.
final masterTasksProvider = FutureProvider<List<WeddingTask>>((ref) async {
  return ref.read(knowledgeBaseProvider).loadAll();
});

// ---------------------------------------------------------------------------
// Profile
// ---------------------------------------------------------------------------
class ProfileNotifier extends StateNotifier<WeddingProfile> {
  final LocalStore store;
  ProfileNotifier(this.store, WeddingProfile initial) : super(initial);

  void update(WeddingProfile p) {
    state = p;
    store.saveProfile(p);
    store.setOnboarded(true);
  }
}

final profileProvider =
    StateNotifierProvider<ProfileNotifier, WeddingProfile>((ref) {
  final store = ref.watch(localStoreProvider);
  return ProfileNotifier(store, store.loadProfile() ?? const WeddingProfile());
});

// ---------------------------------------------------------------------------
// Task status overrides
// ---------------------------------------------------------------------------
class TaskStatusNotifier extends StateNotifier<Map<String, TaskStatus>> {
  final LocalStore store;
  TaskStatusNotifier(this.store) : super(store.loadTaskStatus());

  void set(String taskId, TaskStatus status) {
    state = {...state, taskId: status};
    store.saveTaskStatus(state);
  }

  void toggleDone(String taskId) {
    final current = state[taskId] ?? TaskStatus.notStarted;
    set(taskId, current == TaskStatus.done ? TaskStatus.notStarted : TaskStatus.done);
  }
}

final taskStatusProvider =
    StateNotifierProvider<TaskStatusNotifier, Map<String, TaskStatus>>((ref) {
  return TaskStatusNotifier(ref.watch(localStoreProvider));
});

// ---------------------------------------------------------------------------
// The personalized, scheduled roadmap (the core computed value)
// ---------------------------------------------------------------------------
class Roadmap {
  final List<ScheduledTask> scheduled;
  final List<FunnelStage> funnel;
  final int masterCount;
  const Roadmap({
    required this.scheduled,
    required this.funnel,
    required this.masterCount,
  });

  int get total => scheduled.length;
  int get done => scheduled.where((s) => s.task.isDone).length;
  double get progress => total == 0 ? 0 : done / total;
}

final roadmapProvider = Provider<AsyncValue<Roadmap>>((ref) {
  final masterAsync = ref.watch(masterTasksProvider);
  final profile = ref.watch(profileProvider);
  final statusOverrides = ref.watch(taskStatusProvider);

  return masterAsync.whenData((master) {
    final withStatus = master
        .map((t) => t.copyWith(
              status: statusOverrides[t.id] ?? TaskStatus.notStarted,
            ))
        .toList();

    final result = ref.read(personalizationEngineProvider).personalize(withStatus, profile);
    final scheduled = ref.read(timelineEngineProvider).schedule(result.tasks, profile);

    return Roadmap(
      scheduled: scheduled,
      funnel: result.funnel,
      masterCount: master.length,
    );
  });
});

/// Today's focus tasks derived from the roadmap.
final todaysFocusProvider = Provider<List<ScheduledTask>>((ref) {
  final roadmap = ref.watch(roadmapProvider);
  return roadmap.maybeWhen(
    data: (r) => ref.read(timelineEngineProvider).todaysFocus(r.scheduled, DateTime.now()),
    orElse: () => const [],
  );
});

/// In-app reminder agenda derived from the scheduled roadmap.
final remindersProvider = Provider<List<Reminder>>((ref) {
  final roadmap = ref.watch(roadmapProvider);
  return roadmap.maybeWhen(
    data: (r) => ref.read(reminderEngineProvider).build(r.scheduled),
    orElse: () => const [],
  );
});

/// Proactive AI insights derived from the roadmap, budget and vendors.
final insightsProvider = Provider<List<Insight>>((ref) {
  final roadmap = ref.watch(roadmapProvider);
  final budget = ref.watch(budgetProvider);
  final vendors = ref.watch(vendorsProvider);
  final profile = ref.watch(profileProvider);
  return roadmap.maybeWhen(
    data: (r) => ref.read(insightsEngineProvider).analyze(
          scheduled: r.scheduled,
          budget: budget,
          vendors: vendors,
          profile: profile,
        ),
    orElse: () => const [],
  );
});

// ---------------------------------------------------------------------------
// Vendors / Budget / Shopping / Guests
// ---------------------------------------------------------------------------
class VendorsNotifier extends StateNotifier<List<Vendor>> {
  final LocalStore store;
  VendorsNotifier(this.store) : super(store.loadVendors());
  void _persist() => store.saveVendors(state);
  void add(Vendor v) { state = [...state, v]; _persist(); }
  void update(Vendor v) { state = [for (final x in state) x.id == v.id ? v : x]; _persist(); }
  void remove(String id) { state = state.where((x) => x.id != id).toList(); _persist(); }
}

final vendorsProvider = StateNotifierProvider<VendorsNotifier, List<Vendor>>(
    (ref) => VendorsNotifier(ref.watch(localStoreProvider)));

class BudgetNotifier extends StateNotifier<List<BudgetItem>> {
  final LocalStore store;
  BudgetNotifier(this.store) : super(store.loadBudget());
  void _persist() => store.saveBudget(state);
  void add(BudgetItem v) { state = [...state, v]; _persist(); }
  void update(BudgetItem v) { state = [for (final x in state) x.id == v.id ? v : x]; _persist(); }
  void remove(String id) { state = state.where((x) => x.id != id).toList(); _persist(); }
}

final budgetProvider = StateNotifierProvider<BudgetNotifier, List<BudgetItem>>(
    (ref) => BudgetNotifier(ref.watch(localStoreProvider)));

class ShoppingNotifier extends StateNotifier<List<ShoppingItem>> {
  final LocalStore store;
  ShoppingNotifier(this.store) : super(store.loadShopping());
  void _persist() => store.saveShopping(state);
  void add(ShoppingItem v) { state = [...state, v]; _persist(); }
  void update(ShoppingItem v) { state = [for (final x in state) x.id == v.id ? v : x]; _persist(); }
  void remove(String id) { state = state.where((x) => x.id != id).toList(); _persist(); }
}

final shoppingProvider = StateNotifierProvider<ShoppingNotifier, List<ShoppingItem>>(
    (ref) => ShoppingNotifier(ref.watch(localStoreProvider)));

class GuestsNotifier extends StateNotifier<List<Guest>> {
  final LocalStore store;
  GuestsNotifier(this.store) : super(store.loadGuests());
  void _persist() => store.saveGuests(state);
  void add(Guest v) { state = [...state, v]; _persist(); }
  void update(Guest v) { state = [for (final x in state) x.id == v.id ? v : x]; _persist(); }
  void remove(String id) { state = state.where((x) => x.id != id).toList(); _persist(); }
}

final guestsProvider = StateNotifierProvider<GuestsNotifier, List<Guest>>(
    (ref) => GuestsNotifier(ref.watch(localStoreProvider)));
