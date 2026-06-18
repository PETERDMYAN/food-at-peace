import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// The on-disk profile photo file. Overridden in `main()` with the real
/// `<app-documents>/profile.jpg`; defaults to a non-existent temp path so tests
/// and the screenshot harness just see "no photo" without needing an override.
final profilePhotoFileProvider = Provider<File>(
  (ref) => File('${Directory.systemTemp.path}/fap_profile_unset.jpg'),
);

/// Resolve the real profile-photo file (call once in `main()`).
Future<File> resolveProfilePhotoFile() async {
  final docs = await getApplicationDocumentsDirectory();
  return File('${docs.path}/profile.jpg');
}

/// The user's profile photo as JPEG bytes (null = none). Held in memory so every
/// avatar that watches it refreshes the instant it changes (no image-cache
/// invalidation needed — `Image.memory` is keyed by the bytes). Local-only for
/// now; sharing it to friends' circles needs an S3 upload (follow-up).
class ProfilePhotoNotifier extends Notifier<Uint8List?> {
  File get _file => ref.read(profilePhotoFileProvider);

  @override
  Uint8List? build() => _file.existsSync() ? _file.readAsBytesSync() : null;

  /// Center-crop to a square, downscale to 512px, store + publish.
  Future<void> setFromBytes(Uint8List original) async {
    final jpg = _square(original);
    if (jpg == null) return;
    await _file.writeAsBytes(jpg, flush: true);
    state = jpg;
  }

  Future<void> clear() async {
    if (await _file.exists()) await _file.delete();
    state = null;
  }
}

final profilePhotoProvider =
    NotifierProvider<ProfilePhotoNotifier, Uint8List?>(ProfilePhotoNotifier.new);

Uint8List? _square(Uint8List original) {
  try {
    final d = img.decodeImage(original);
    if (d == null) return null;
    final side = d.width < d.height ? d.width : d.height;
    final cropped = img.copyCrop(
      d,
      x: (d.width - side) ~/ 2,
      y: (d.height - side) ~/ 2,
      width: side,
      height: side,
    );
    final out = side > 512 ? img.copyResize(cropped, width: 512, height: 512) : cropped;
    return Uint8List.fromList(img.encodeJpg(out, quality: 88));
  } catch (_) {
    return null;
  }
}
