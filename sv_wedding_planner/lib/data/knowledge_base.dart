import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/wedding_task.dart';

/// Loads the Wedding Knowledge Engine tasks from the bundled JSON asset.
///
/// The seed asset ships a curated, richly-tagged subset. In production this
/// loader is swapped for a Firestore-backed source holding the full
/// 10,000-15,000 atomic tasks; the rest of the app is agnostic to the source.
class KnowledgeBase {
  const KnowledgeBase();

  Future<List<WeddingTask>> loadAll() async {
    final raw = await rootBundle.loadString('assets/data/wedding_tasks.json');
    final list = json.decode(raw) as List<dynamic>;
    return list
        .map((e) => WeddingTask.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
