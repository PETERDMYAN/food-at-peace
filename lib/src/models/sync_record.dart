/// One record in the `/sync` envelope (see `backend/src/sync.py`):
/// `{id, updatedAt:<epoch-ms>, deleted, data}`. [data] is the model's own
/// `toJson()` — opaque to the server.
class SyncRecord {
  const SyncRecord({
    required this.id,
    required this.updatedAtMs,
    required this.deleted,
    required this.data,
  });

  final String id;
  final int updatedAtMs;
  final bool deleted;
  final Map<String, dynamic> data;

  Map<String, dynamic> toJson() => {
        'id': id,
        'updatedAt': updatedAtMs,
        'deleted': deleted,
        'data': data,
      };

  factory SyncRecord.fromJson(Map<String, dynamic> json) => SyncRecord(
        id: json['id'] as String,
        updatedAtMs: (json['updatedAt'] as num?)?.toInt() ?? 0,
        deleted: (json['deleted'] as bool?) ?? false,
        data: (json['data'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
}
