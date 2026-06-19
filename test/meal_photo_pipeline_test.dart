// Ground-truth for "I don't see the food photo in my story". Two halves:
//  1. The device-local full-res pipeline (MealPhotos.save → pathFor → existsSync).
//  2. The synced fallback: a small thumbnail rides on the FoodEntry so the photo
//     shows on every device / after a reinstall (the original is device-local and
//     never synced). The story prefers the local file, else decodes the thumb.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
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

/// A LARGE, detailed image standing in for a real meal photo: smooth structure
/// (compresses like a photo) plus fine texture/noise so it doesn't collapse to a
/// few KB like a solid fill. At full 1080px this lands in the size range where a
/// real detailed photo's base64 can blow past DynamoDB's 400 KB row limit.
Uint8List _detailedJpg({int w = 2400, int h = 2400}) {
  final im = img.Image(width: w, height: h);
  var seed = 0x5DEECE66D;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      final n = (seed & 0x3f) - 32; // ±32 fine texture
      final r = (128 + 110 * math.sin(x / 23) + n).round().clamp(0, 255);
      final g = (128 + 110 * math.sin(y / 31) + n).round().clamp(0, 255);
      final b = (128 + 110 * math.sin((x + y) / 17) + n).round().clamp(0, 255);
      im.setPixelRgb(x, y, r, g, b);
    }
  }
  return Uint8List.fromList(img.encodeJpg(im, quality: 95));
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
    final decoded = img.decodeImage(base64Decode(thumb!));
    expect(decoded, isNotNull);
    // Downscaled to <=1080px on the longest side (matches the local original)…
    expect(decoded!.width <= 1080 && decoded.height <= 1080, isTrue);
    // …and the BASE64 STRING (what DynamoDB actually stores) is under the cap.
    expect(thumb.length, lessThan(290 * 1024));
  });

  test('encodeMealThumb keeps even a detailed photo under the DDB string cap', () {
    // The real bug: a detailed 1080px photo's base64 can exceed 400 KB and
    // silently fail to sync. The adaptive ladder must bring it under the cap.
    final thumb = encodeMealThumb(_detailedJpg());
    expect(thumb, isNotNull);
    expect(
      thumb!.length,
      lessThan(290 * 1024),
      reason: 'base64 length is what counts against DynamoDB 400 KB item limit',
    );
    // Still a real, decodable image (not blank).
    final decoded = img.decodeImage(base64Decode(thumb));
    expect(decoded, isNotNull);
    expect(decoded!.width <= 1080 && decoded.height <= 1080, isTrue);
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
