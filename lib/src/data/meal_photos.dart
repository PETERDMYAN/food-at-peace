import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Local, device-only persistence of meal photos, keyed by food-entry id
/// (`<app-documents>/meal_photos/<id>.jpg`). Deliberately NOT part of the synced
/// [FoodEntry] model — the path is local, so syncing it would be meaningless and
/// could be clobbered on merge. Other devices simply won't show the photo.
class MealPhotos {
  MealPhotos(this.dir);

  /// The `meal_photos/` directory (already created).
  final Directory dir;

  String pathFor(String id) => '${dir.path}/$id.jpg';

  /// Downscale to ≤1080px and store as JPEG under [id]. Best-effort; swallows
  /// decode/IO errors so a photo hiccup never blocks logging a meal.
  Future<void> save(String id, Uint8List originalBytes) async {
    try {
      final decoded = img.decodeImage(originalBytes);
      if (decoded == null) return;
      final longest =
          decoded.width >= decoded.height ? decoded.width : decoded.height;
      final out = longest > 1080
          ? img.copyResize(
              decoded,
              width: decoded.width >= decoded.height ? 1080 : null,
              height: decoded.height > decoded.width ? 1080 : null,
            )
          : decoded;
      await File(pathFor(id)).writeAsBytes(img.encodeJpg(out, quality: 85), flush: true);
    } catch (_) {
      // best-effort
    }
  }

  Future<void> delete(String id) async {
    try {
      final f = File(pathFor(id));
      if (await f.exists()) await f.delete();
    } catch (_) {
      // best-effort
    }
  }

  /// Resolve + create the meal-photos directory. Call once at startup.
  static Future<MealPhotos> create() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/meal_photos');
    if (!await dir.exists()) await dir.create(recursive: true);
    return MealPhotos(dir);
  }
}

/// Overridden in `main()` with the initialized instance (and in tests with a
/// temp-dir instance), like [sharedPreferencesProvider].
final mealPhotosProvider = Provider<MealPhotos>(
  (ref) => throw UnimplementedError('mealPhotosProvider must be overridden in main()'),
);

/// A small (≤[maxSide]px) JPEG of [bytes] as a base64 string — the thumbnail we
/// store ON the [FoodEntry] so the meal photo **syncs** across devices / survives
/// a reinstall (the full-resolution original stays device-local in [MealPhotos]).
/// Kept small on purpose so it doesn't bloat the synced row. Top-level + single
/// positional arg so it runs off the UI isolate via `compute`. Null on failure.
String? encodeMealThumb(Uint8List bytes, {int maxSide = 480, int quality = 72}) {
  try {
    final d = img.decodeImage(bytes);
    if (d == null) return null;
    final longest = d.width >= d.height ? d.width : d.height;
    final out = longest > maxSide
        ? img.copyResize(
            d,
            width: d.width >= d.height ? maxSide : null,
            height: d.height > d.width ? maxSide : null,
          )
        : d;
    return base64Encode(img.encodeJpg(out, quality: quality));
  } catch (_) {
    return null;
  }
}
