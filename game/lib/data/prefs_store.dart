/// shared_preferences-backed [KeyValueStore]. Reads are synchronous against an
/// in-memory cache hydrated once at startup, so the pure progress model stays
/// synchronous; writes persist asynchronously.
library;

import 'package:shared_preferences/shared_preferences.dart';

import '../logic/progress.dart';

class PrefsStore implements KeyValueStore {
  PrefsStore._(this._prefs);

  final SharedPreferences _prefs;

  static Future<PrefsStore> create() async {
    final prefs = await SharedPreferences.getInstance();
    return PrefsStore._(prefs);
  }

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  Future<void> setString(String key, String value) => _prefs.setString(key, value);
}
