/// Pure-Dart localization. Holds string tables per language and resolves a key
/// to the active language, falling back to Hindi, then to the key itself.
library;

class Localization {
  Localization({required this.tables, required this.fallbackLang, required String active})
      : _active = active;

  /// lang code -> (key -> string)
  final Map<String, Map<String, String>> tables;
  final String fallbackLang;
  String _active;

  String get active => _active;
  List<String> get languages => tables.keys.toList();

  void setLanguage(String lang) {
    if (tables.containsKey(lang)) _active = lang;
  }

  /// Translate [key]. Optional [params] replace {name} placeholders.
  String t(String key, [Map<String, String>? params]) {
    var s = tables[_active]?[key] ?? tables[fallbackLang]?[key] ?? key;
    if (params != null) {
      params.forEach((k, v) => s = s.replaceAll('{$k}', v));
    }
    return s;
  }

  factory Localization.fromTables(
    Map<String, Map<String, dynamic>> raw, {
    required String fallbackLang,
    required String active,
  }) {
    final tables = <String, Map<String, String>>{};
    raw.forEach((lang, obj) {
      final strings = (obj['strings'] as Map?)?.cast<String, dynamic>() ?? const {};
      tables[lang] = {for (final e in strings.entries) e.key: e.value.toString()};
    });
    return Localization(
      tables: tables,
      fallbackLang: fallbackLang,
      active: tables.containsKey(active) ? active : fallbackLang,
    );
  }
}
