// Ground-truth for "I don't see the food photo in my story". Two halves:
//  1. The device-local full-res pipeline (MealPhotos.save → pathFor → existsSync).
//  2. The synced fallback: a small thumbnail rides on the FoodEntry so the photo
//     shows on every device / after a reinstall (the original is device-local and
//     never synced). The story prefers the local file, else decodes the thumb.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_at_peace/src/data/meal_photos.dart';
import 'package:food_at_peace/src/models/food_entry.dart';
import 'package:food_at_peace/src/models/meal_type.dart';
import 'package:image/image.dart' as img;

Uint8List _jpg({int w = 1600, int h = 1200}) {
  final im = img.Image(width: w, height: h);
  img.fill(im, color: img.ColorRgb8(210, 120, 60));
  return Uint8List.fromList(img.encodeJpg(im));
}

FoodEntry _entry({String? thumb}) => FoodEntry(
  id: '12345',
  name: 'Salmon poke bowl',
  calories: 540,
  proteinG: 38,
  satFatG: 5,
  mealType: MealType.lunch,
  timestamp: DateTime(2026, 6, 18, 12, 40),
  source: FoodSource.photo,
  updatedAt: DateTime(2026, 6, 18, 12, 40),
  photoThumb: thumb,
);

void main() {
  test('MealPhotos.save writes a file pathFor/existsSync then finds', () async {
    final dir = await Directory.systemTemp.createTemp('fap_mp_test');
    final mp = MealPhotos(dir);
    await mp.save('12345', _jpg());
    expect(
      File(mp.pathFor('12345')).existsSync(),
      isTrue,
      reason: 'the food story looks up the photo at pathFor(id)',
    );
  });

  test('encodeMealThumb yields a crisp, decodable base64 JPEG under the DDB cap', () {
    final thumb = encodeMealThumb(_jpg());
    expect(thumb, isNotNull);
    final bytes = base64Decode(thumb!);
    final decoded = img.decodeImage(bytes);
    expect(decoded, isNotNull);
    // Downscaled to <=1080px on the longest side (matches the local original)…
    expect(decoded!.width <= 1080 && decoded.height <= 1080, isTrue);
    // …and comfortably under DynamoDB's 400 KB per-item limit so it syncs.
    expect(bytes.length, lessThan(380 * 1024));
  });

  test('photoThumb round-trips through toJson/fromJson (so it syncs)', () {
    final thumb = encodeMealThumb(_jpg());
    final restored = FoodEntry.fromJson(_entry(thumb: thumb).toJson());
    expect(restored.photoThumb, thumb);
  });

  test('a no-photo entry omits photoThumb from its JSON (stays lean)', () {
    expect(_entry().toJson().containsKey('photoThumb'), isFalse);
  });

  test('legacy JSON without photoThumb still parses (1.0.x compatibility)', () {
    final legacy = _entry().toJson()..remove('photoThumb');
    expect(FoodEntry.fromJson(legacy).photoThumb, isNull);
  });
}
