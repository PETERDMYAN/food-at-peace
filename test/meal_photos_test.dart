import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_at_peace/src/data/meal_photos.dart';
import 'package:image/image.dart' as img;

void main() {
  test('save writes a jpg keyed by id; delete removes it', () async {
    final dir = Directory.systemTemp.createTempSync('meal_photos_test');
    final mp = MealPhotos(dir);
    final bytes = Uint8List.fromList(img.encodeJpg(img.Image(width: 8, height: 8)));

    await mp.save('abc', bytes);
    expect(mp.pathFor('abc'), endsWith('abc.jpg'));
    expect(File(mp.pathFor('abc')).existsSync(), isTrue);

    await mp.delete('abc');
    expect(File(mp.pathFor('abc')).existsSync(), isFalse);
    dir.deleteSync(recursive: true);
  });

  test('save swallows invalid image bytes (no throw, no file)', () async {
    final dir = Directory.systemTemp.createTempSync('meal_photos_test2');
    final mp = MealPhotos(dir);
    await mp.save('bad', Uint8List.fromList([1, 2, 3])); // not an image
    expect(File(mp.pathFor('bad')).existsSync(), isFalse);
    dir.deleteSync(recursive: true);
  });
}
