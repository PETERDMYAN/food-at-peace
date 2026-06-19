import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../providers/providers.dart';

/// Reserved photo-store id for the profile photo. It shares the durable per-user
/// S3 store with meal photos (key `meal/<uid>/__profile__.jpg`), so the profile
/// photo survives a reinstall / new device too.
const String _profilePhotoId = '__profile__';

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
/// invalidation needed — `Image.memory` is keyed by the bytes). The original is
/// kept locally AND uploaded to the durable per-user S3 store, so it survives a
/// reinstall / new device (restored on sign-in) instead of being lost.
class ProfilePhotoNotifier extends Notifier<Uint8List?> {
  File get _file => ref.read(profilePhotoFileProvider);

  @override
  Uint8List? build() {
    final local = _file.existsSync() ? _file.readAsBytesSync() : null;
    // No local copy but signed in (e.g. fresh install / new device) → pull it
    // back from the cloud. Watching auth re-runs this when the user signs in.
    final token = ref.watch(authProvider)?.token;
    if (local == null && token != null && token.isNotEmpty) {
      Future.microtask(() => _hydrateFromCloud(token));
    }
    return local;
  }

  /// Center-crop to a square, downscale to 512px, store locally + publish, and
  /// upload to the durable S3 store (best-effort).
  Future<void> setFromBytes(Uint8List original) async {
    final jpg = _square(original);
    if (jpg == null) return;
    await _file.writeAsBytes(jpg, flush: true);
    state = jpg;
    final token = ref.read(authProvider)?.token;
    if (token != null && token.isNotEmpty) {
      unawaited(
        ref
            .read(mealPhotoStoreProvider)
            .uploadFullRes(_profilePhotoId, jpg, token),
      );
    }
  }

  Future<void> clear() async {
    if (await _file.exists()) await _file.delete();
    state = null;
    final token = ref.read(authProvider)?.token;
    if (token != null && token.isNotEmpty) {
      unawaited(
        ref.read(mealPhotoStoreProvider).deleteRemote(_profilePhotoId, token),
      );
    }
  }

  /// Restore the profile photo from S3 into the local file (no-op if we already
  /// have it or there's nothing in the cloud).
  Future<void> _hydrateFromCloud(String token) async {
    if (_file.existsSync()) return;
    final bytes = await ref
        .read(mealPhotoStoreProvider)
        .fetchBytes(_profilePhotoId, token);
    if (bytes == null || bytes.isEmpty) return;
    await _file.writeAsBytes(bytes, flush: true);
    state = bytes;
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
