import 'enums.dart';

/// An atomic wedding task drawn from the Wedding Knowledge Engine.
///
/// Every task carries rich metadata so the personalization engine can decide
/// whether it applies to a given [WeddingProfile], and the timeline engine can
/// schedule it relative to the wedding date while respecting dependencies.
class WeddingTask {
  final String id;
  final String title;
  final String description;
  final String category;
  final String subcategory;

  final Set<Persona> applicablePersonas;
  final WeddingSide side;
  final Ceremony ceremony;
  final Priority priority;

  /// IDs of tasks that must be completed before this one can start.
  final List<String> dependencies;

  /// Offset in days from the wedding date. Negative = before the wedding.
  /// e.g. -120 means "start ~120 days before the wedding".
  final int startOffsetDays;
  final int estimatedDurationDays;
  final int bufferDays;

  final int costEstimate; // INR, 0 when not a spend item
  final String budgetCategory;
  final bool mandatory;

  // Applicability filters — empty list means "applies to all".
  final List<String> regions;
  final List<String> religions;
  final List<String> communities;
  final List<String> weddingTypes;
  final int minGuestCount;
  final int minBudget;

  final List<String> requiredVendors;
  final List<String> shoppingItems;
  final List<String> tags;
  final double aiConfidence;

  // Runtime state (persisted separately).
  final TaskStatus status;

  const WeddingTask({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.subcategory = '',
    this.applicablePersonas = const {},
    this.side = WeddingSide.both,
    this.ceremony = Ceremony.wedding,
    this.priority = Priority.medium,
    this.dependencies = const [],
    this.startOffsetDays = -60,
    this.estimatedDurationDays = 3,
    this.bufferDays = 2,
    this.costEstimate = 0,
    this.budgetCategory = 'Miscellaneous',
    this.mandatory = false,
    this.regions = const [],
    this.religions = const [],
    this.communities = const [],
    this.weddingTypes = const [],
    this.minGuestCount = 0,
    this.minBudget = 0,
    this.requiredVendors = const [],
    this.shoppingItems = const [],
    this.tags = const [],
    this.aiConfidence = 0.8,
    this.status = TaskStatus.notStarted,
  });

  bool get isDone => status == TaskStatus.done;

  WeddingTask copyWith({TaskStatus? status}) => WeddingTask(
        id: id,
        title: title,
        description: description,
        category: category,
        subcategory: subcategory,
        applicablePersonas: applicablePersonas,
        side: side,
        ceremony: ceremony,
        priority: priority,
        dependencies: dependencies,
        startOffsetDays: startOffsetDays,
        estimatedDurationDays: estimatedDurationDays,
        bufferDays: bufferDays,
        costEstimate: costEstimate,
        budgetCategory: budgetCategory,
        mandatory: mandatory,
        regions: regions,
        religions: religions,
        communities: communities,
        weddingTypes: weddingTypes,
        minGuestCount: minGuestCount,
        minBudget: minBudget,
        requiredVendors: requiredVendors,
        shoppingItems: shoppingItems,
        tags: tags,
        aiConfidence: aiConfidence,
        status: status ?? this.status,
      );

  static Set<Persona> _personas(dynamic raw) {
    if (raw == null) return const {};
    final list = (raw as List).cast<String>();
    final out = <Persona>{};
    for (final s in list) {
      for (final p in Persona.values) {
        if (p.name.toLowerCase() == s.toLowerCase()) out.add(p);
      }
    }
    return out;
  }

  static List<String> _strList(dynamic raw) =>
      raw == null ? const [] : (raw as List).map((e) => e.toString()).toList();

  factory WeddingTask.fromJson(Map<String, dynamic> j) {
    WeddingSide side = WeddingSide.both;
    for (final s in WeddingSide.values) {
      if (s.name == j['side']) side = s;
    }
    return WeddingTask(
      id: j['id'] as String,
      title: j['title'] as String,
      description: j['description'] ?? '',
      category: j['category'] ?? 'General',
      subcategory: j['subcategory'] ?? '',
      applicablePersonas: _personas(j['personas']),
      side: side,
      ceremony: ceremonyFromString(j['ceremony'] ?? 'wedding') ?? Ceremony.wedding,
      priority: priorityFromString(j['priority'] ?? 'medium'),
      dependencies: _strList(j['dependencies']),
      startOffsetDays: (j['startOffsetDays'] ?? -60) as int,
      estimatedDurationDays: (j['estimatedDurationDays'] ?? 3) as int,
      bufferDays: (j['bufferDays'] ?? 2) as int,
      costEstimate: (j['costEstimate'] ?? 0) as int,
      budgetCategory: j['budgetCategory'] ?? 'Miscellaneous',
      mandatory: j['mandatory'] ?? false,
      regions: _strList(j['regions']),
      religions: _strList(j['religions']),
      communities: _strList(j['communities']),
      weddingTypes: _strList(j['weddingTypes']),
      minGuestCount: (j['minGuestCount'] ?? 0) as int,
      minBudget: (j['minBudget'] ?? 0) as int,
      requiredVendors: _strList(j['requiredVendors']),
      shoppingItems: _strList(j['shoppingItems']),
      tags: _strList(j['tags']),
      aiConfidence: (j['aiConfidence'] ?? 0.8).toDouble(),
    );
  }
}

/// A task paired with its engine-computed schedule window.
class ScheduledTask {
  final WeddingTask task;
  final DateTime start;
  final DateTime due;

  const ScheduledTask({required this.task, required this.start, required this.due});

  int daysUntilDue(DateTime now) => due.difference(_dateOnly(now)).inDays;
  bool isOverdue(DateTime now) => !task.isDone && due.isBefore(_dateOnly(now));

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
