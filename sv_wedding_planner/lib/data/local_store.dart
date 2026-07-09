import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/enums.dart';
import '../models/other_models.dart';
import '../models/wedding_profile.dart';

/// Offline-first persistence backed by shared_preferences. This mirrors the
/// shape the Firestore repository will use so that swapping the backend later
/// touches only this class.
class LocalStore {
  static const _kProfile = 'profile';
  static const _kTaskStatus = 'task_status';
  static const _kVendors = 'vendors';
  static const _kBudget = 'budget';
  static const _kShopping = 'shopping';
  static const _kGuests = 'guests';
  static const _kOnboarded = 'onboarded';

  final SharedPreferences prefs;
  LocalStore(this.prefs);

  static Future<LocalStore> create() async =>
      LocalStore(await SharedPreferences.getInstance());

  bool get onboarded => prefs.getBool(_kOnboarded) ?? false;
  Future<void> setOnboarded(bool v) => prefs.setBool(_kOnboarded, v);

  // ---- Profile ----
  WeddingProfile? loadProfile() {
    final raw = prefs.getString(_kProfile);
    if (raw == null) return null;
    return WeddingProfile.fromJson(json.decode(raw) as Map<String, dynamic>);
  }

  Future<void> saveProfile(WeddingProfile p) =>
      prefs.setString(_kProfile, json.encode(p.toJson()));

  // ---- Task status overrides (id -> status) ----
  Map<String, TaskStatus> loadTaskStatus() {
    final raw = prefs.getString(_kTaskStatus);
    if (raw == null) return {};
    final map = json.decode(raw) as Map<String, dynamic>;
    return map.map((k, v) {
      final status = TaskStatus.values.firstWhere(
        (s) => s.name == v,
        orElse: () => TaskStatus.notStarted,
      );
      return MapEntry(k, status);
    });
  }

  Future<void> saveTaskStatus(Map<String, TaskStatus> status) {
    final map = status.map((k, v) => MapEntry(k, v.name));
    return prefs.setString(_kTaskStatus, json.encode(map));
  }

  // ---- Generic list persistence ----
  List<Vendor> loadVendors() => _loadList(_kVendors, Vendor.fromJson);
  Future<void> saveVendors(List<Vendor> v) =>
      _saveList(_kVendors, v.map((e) => e.toJson()).toList());

  List<BudgetItem> loadBudget() => _loadList(_kBudget, BudgetItem.fromJson);
  Future<void> saveBudget(List<BudgetItem> v) =>
      _saveList(_kBudget, v.map((e) => e.toJson()).toList());

  List<ShoppingItem> loadShopping() => _loadList(_kShopping, ShoppingItem.fromJson);
  Future<void> saveShopping(List<ShoppingItem> v) =>
      _saveList(_kShopping, v.map((e) => e.toJson()).toList());

  List<Guest> loadGuests() => _loadList(_kGuests, Guest.fromJson);
  Future<void> saveGuests(List<Guest> v) =>
      _saveList(_kGuests, v.map((e) => e.toJson()).toList());

  List<T> _loadList<T>(String key, T Function(Map<String, dynamic>) from) {
    final raw = prefs.getString(key);
    if (raw == null) return [];
    final list = json.decode(raw) as List<dynamic>;
    return list.map((e) => from(e as Map<String, dynamic>)).toList();
  }

  Future<void> _saveList(String key, List<Map<String, dynamic>> data) =>
      prefs.setString(key, json.encode(data));
}
