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

/// Largest base64 string we'll store for a meal thumb. DynamoDB caps a synced
/// row at 400 KB and the **base64 string is what's stored** (≈33% bigger than the
/// JPEG bytes), so we keep the encoded string well under that, leaving headroom
/// for the rest of the entry's fields + attribute overhead. A detailed 1080px
/// photo can otherwise blow past 400 KB and silently fail to sync — after a
/// reinstall (the device-local original is gone) the photo then vanishes.
const int _thumbBase64Cap = 290 * 1024;

/// A base64 JPEG copy of [bytes] — the copy we store ON the [FoodEntry] so the
/// meal photo **syncs** across devices / survives a reinstall (the full-res
/// original stays device-local in [MealPhotos]). Starts crisp ([maxSide]px /
/// [quality]) and steps the size + quality down only as needed so the encoded
/// string always fits under [_thumbBase64Cap]. Top-level + single positional arg
/// so it runs off the UI isolate via `compute`. Null on failure.
String? encodeMealThumb(Uint8List bytes, {int maxSide = 1080, int quality = 78}) {
  try {
    final d = img.decodeImage(bytes);
    if (d == null) return null;
    // Crisp first, then degrade. Each rung is (longest-side px, JPEG quality).
    // The low rungs guarantee a fit even for an extreme (highly-detailed) photo
    // — a synced low-res photo always beats one that silently vanishes.
    final ladder = <(int, int)>[
      (maxSide, quality),
      (maxSide, 64),
      (900, 64),
      (760, 60),
      (640, 56),
      (520, 52),
      (420, 48),
      (340, 44),
    ];
    String? best;
    for (final (side, q) in ladder) {
      final longest = d.width >= d.height ? d.width : d.height;
      final out = longest > side
          ? img.copyResize(
              d,
              width: d.width >= d.height ? side : null,
              height: d.height > d.width ? side : null,
            )
          : d;
      final b64 = base64Encode(img.encodeJpg(out, quality: q));
      best = b64;
      if (b64.length <= _thumbBase64Cap) return b64;
    }
    return best; // smallest we could manage — still better than no photo
  } catch (_) {
    return null;
  }
}
