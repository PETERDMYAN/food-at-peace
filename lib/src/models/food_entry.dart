import 'meal_type.dart';

/// How an entry was created. `photo` is used from Phase 3 (Claude vision).
enum FoodSource { manual, photo }

/// A single logged food item. The macro fields are the totals for the
/// portion that was eaten (not per-100g).
class FoodEntry {
  const FoodEntry({
    required this.id,
    required this.name,
    required this.calories,
    required this.proteinG,
    required this.satFatG,
    required this.mealType,
    required this.timestamp,
    this.source = FoodSource.manual,
    this.servingDescription,
    this.updatedAt,
    this.deleted = false,
    this.photoThumb,
  });

  final String id;
  final String name;
  final double calories;
  final double proteinG;
  final double satFatG;
  final MealType mealType;
  final DateTime timestamp;
  final FoodSource source;
  final String? servingDescription;

  /// A small base64 JPEG thumbnail of the meal photo, carried ON the entry so it
  /// **syncs** and shows on every device / after a reinstall. The full-resolution
  /// original stays device-local in `MealPhotos` (preferred when present). Null
  /// for manual entries, older rows, and the shipped 1.0.x clients (which simply
  /// ignore the field — additive + backward-compatible). See `MealPhotos` /
  /// `encodeMealThumb`.
  final String? photoThumb;

  /// Sync metadata: when this row last changed, and whether it's a tombstone.
  /// [updatedAt] is null for rows created before sync existed; [syncUpdatedAt]
  /// falls back to [timestamp] for those.
  final DateTime? updatedAt;
  final bool deleted;

  DateTime get syncUpdatedAt => updatedAt ?? timestamp;

  FoodEntry copyWith({
    String? name,
    double? calories,
    double? proteinG,
    double? satFatG,
    MealType? mealType,
    DateTime? timestamp,
    FoodSource? source,
    String? servingDescription,
    DateTime? updatedAt,
    bool? deleted,
    String? photoThumb,
  }) {
    return FoodEntry(
      id: id,
      name: name ?? this.name,
      calories: calories ?? this.calories,
      proteinG: proteinG ?? this.proteinG,
      satFatG: satFatG ?? this.satFatG,
      mealType: mealType ?? this.mealType,
      timestamp: timestamp ?? this.timestamp,
      source: source ?? this.source,
      servingDescription: servingDescription ?? this.servingDescription,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      photoThumb: photoThumb ?? this.photoThumb,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'calories': calories,
        'proteinG': proteinG,
        'satFatG': satFatG,
        'mealType': mealType.name,
        'timestamp': timestamp.toIso8601String(),
        'source': source.name,
        'servingDescription': servingDescription,
        'updatedAt': updatedAt?.toIso8601String(),
        'deleted': deleted,
        if (photoThumb != null) 'photoThumb': photoThumb,
      };

  factory FoodEntry.fromJson(Map<String, dynamic> json) => FoodEntry(
        id: json['id'] as String,
        name: json['name'] as String,
        calories: (json['calories'] as num).toDouble(),
        proteinG: (json['proteinG'] as num).toDouble(),
        satFatG: (json['satFatG'] as num).toDouble(),
        mealType: MealType.values.byName(json['mealType'] as String),
        timestamp: DateTime.parse(json['timestamp'] as String),
        source: FoodSource.values
            .byName((json['source'] as String?) ?? FoodSource.manual.name),
        servingDescription: json['servingDescription'] as String?,
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : null,
        deleted: (json['deleted'] as bool?) ?? false,
        photoThumb: json['photoThumb'] as String?,
      );
}
