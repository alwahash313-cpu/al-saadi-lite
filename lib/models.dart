import 'dart:convert';

enum ClipKind { video, image, audio, text }

class EditorClip {
  String id;
  ClipKind kind;
  String path;
  int startMs;
  int durationMs;
  double speed;
  String text;

  EditorClip({
    required this.id,
    required this.kind,
    required this.path,
    this.startMs = 0,
    this.durationMs = 5000,
    this.speed = 1.0,
    this.text = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'kind': kind.name, 'path': path,
    'startMs': startMs, 'durationMs': durationMs,
    'speed': speed, 'text': text,
  };

  factory EditorClip.fromJson(Map<String, dynamic> j) => EditorClip(
    id: j['id'] as String,
    kind: ClipKind.values.firstWhere((e) => e.name == j['kind']),
    path: j['path'] as String,
    startMs: j['startMs'] as int? ?? 0,
    durationMs: j['durationMs'] as int? ?? 5000,
    speed: (j['speed'] as num?)?.toDouble() ?? 1,
    text: j['text'] as String? ?? '',
  );
}

class EditorProject {
  String id;
  String name;
  DateTime updatedAt;
  List<EditorClip> clips;

  EditorProject({
    required this.id,
    required this.name,
    DateTime? updatedAt,
    List<EditorClip>? clips,
  }) : updatedAt = updatedAt ?? DateTime.now(),
       clips = clips ?? [];

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'updatedAt': updatedAt.toIso8601String(),
    'clips': clips.map((e) => e.toJson()).toList(),
  };

  factory EditorProject.fromJson(Map<String, dynamic> j) => EditorProject(
    id: j['id'] as String,
    name: j['name'] as String,
    updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? '') ?? DateTime.now(),
    clips: ((j['clips'] as List?) ?? [])
      .map((e) => EditorClip.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
  );

  String encode() => jsonEncode(toJson());
  factory EditorProject.decode(String value) =>
      EditorProject.fromJson(jsonDecode(value) as Map<String, dynamic>);
}
