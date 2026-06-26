/// Pure-Dart dialogue + audio-map + world + boss + secret-reference models.
/// Parsed from the matching `assets/config/*.json` files.
library;

class DialogueLine {
  const DialogueLine({
    required this.id,
    required this.speaker,
    required this.text,
    required this.voice,
    required this.portrait,
    required this.trigger,
  });

  final String id;
  final String speaker;
  final String text;
  final String voice; // audio_map voice key (may be empty)
  final String portrait;
  final String trigger; // intro | level_start | enemy | boss | ending | generic

  factory DialogueLine.fromJson(Map<String, dynamic> j) => DialogueLine(
        id: j['id'] as String,
        speaker: (j['speaker'] as String?) ?? '',
        text: (j['text'] as String?) ?? '',
        voice: (j['voice'] as String?) ?? '',
        portrait: (j['portrait'] as String?) ?? '',
        trigger: (j['trigger'] as String?) ?? 'generic',
      );
}

/// All dialogue, queryable by id or by trigger.
class DialogueBook {
  DialogueBook(this._byId, this._all);
  final Map<String, DialogueLine> _byId;
  final List<DialogueLine> _all;

  DialogueLine? byId(String id) => _byId[id];
  List<DialogueLine> byTrigger(String trigger) =>
      _all.where((l) => l.trigger == trigger).toList();
  List<DialogueLine> get all => List.unmodifiable(_all);

  factory DialogueBook.fromJson(Map<String, dynamic> j) {
    final lines = ((j['lines'] as List?) ?? const [])
        .map((e) => DialogueLine.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    return DialogueBook({for (final l in lines) l.id: l}, lines);
  }
}

/// Resolves logical audio keys -> asset file paths. Missing keys return null so
/// the audio layer can skip them silently (lets the owner add mp3s gradually).
class AudioMap {
  AudioMap(this.voice, this.ambient, this.sfx, this.music);
  final Map<String, String> voice;
  final Map<String, String> ambient;
  final Map<String, String> sfx;
  final Map<String, String> music;

  String? voicePath(String key) => voice[key];
  String? ambientPath(String key) => ambient[key];
  String? sfxPath(String key) => sfx[key];
  String? musicPath(String key) => music[key];

  static Map<String, String> _strMap(dynamic raw) {
    final m = (raw as Map?)?.cast<String, dynamic>() ?? const {};
    return {for (final e in m.entries) e.key: e.value.toString()};
  }

  factory AudioMap.fromJson(Map<String, dynamic> j) => AudioMap(
        _strMap(j['voice']),
        _strMap(j['ambient']),
        _strMap(j['sfx']),
        _strMap(j['music']),
      );
}

class WorldDef {
  const WorldDef({
    required this.id,
    required this.label,
    required this.ambient,
    required this.skyTop,
    required this.skyBottom,
    required this.groundColor,
    required this.outfit,
  });
  final String id;
  final String label;
  final String ambient;
  final String skyTop;
  final String skyBottom;
  final String groundColor;
  final String outfit;
  factory WorldDef.fromJson(Map<String, dynamic> j) => WorldDef(
        id: j['id'] as String,
        label: (j['label'] as String?) ?? (j['id'] as String),
        ambient: (j['ambient'] as String?) ?? '',
        skyTop: (j['skyTop'] as String?) ?? '#FFE8B0',
        skyBottom: (j['skyBottom'] as String?) ?? '#F5C16C',
        groundColor: (j['groundColor'] as String?) ?? '#7A5230',
        outfit: (j['outfit'] as String?) ?? 'default',
      );
}

class BossDef {
  const BossDef({
    required this.level,
    required this.id,
    required this.name,
    required this.type,
    required this.gimmick,
    required this.portrait,
  });
  final int level;
  final String id;
  final String name;
  final String type;
  final String gimmick;
  final String portrait;
  factory BossDef.fromJson(Map<String, dynamic> j) => BossDef(
        level: (j['level'] as num).toInt(),
        id: j['id'] as String,
        name: (j['name'] as String?) ?? (j['id'] as String),
        type: (j['type'] as String?) ?? '',
        gimmick: (j['gimmick'] as String?) ?? '',
        portrait: (j['portrait'] as String?) ?? '',
      );
}

class SecretReference {
  const SecretReference({
    required this.id,
    required this.trigger,
    required this.type,
    required this.content,
  });
  final String id;
  final String trigger;
  final String type; // text | image
  final String content;
  bool get isActive => content.trim().isNotEmpty;
  factory SecretReference.fromJson(Map<String, dynamic> j) => SecretReference(
        id: (j['id'] as String?) ?? '',
        trigger: (j['trigger'] as String?) ?? '',
        type: (j['type'] as String?) ?? 'text',
        content: (j['content'] as String?) ?? '',
      );
}
