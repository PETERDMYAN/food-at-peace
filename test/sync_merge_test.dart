import 'package:flutter_test/flutter_test.dart';

import 'package:food_at_peace/src/data/sync_engine.dart';
import 'package:food_at_peace/src/models/food_entry.dart';
import 'package:food_at_peace/src/models/meal_type.dart';
import 'package:food_at_peace/src/models/sync_record.dart';
import 'package:food_at_peace/src/models/user_profile.dart';

FoodEntry _food(String id, int updatedAtMs, {double cal = 100}) => FoodEntry(
      id: id,
      name: 'local',
      calories: cal,
      proteinG: 0,
      satFatG: 0,
      mealType: MealType.snack,
      timestamp: DateTime.fromMillisecondsSinceEpoch(updatedAtMs),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAtMs),
    );

SyncRecord _rec(String id, int ms, {bool deleted = false, double cal = 999}) =>
    SyncRecord(
      id: id,
      updatedAtMs: ms,
      deleted: deleted,
      data: {
        'id': id,
        'name': 'server',
        'calories': cal,
        'proteinG': 0,
        'satFatG': 0,
        'mealType': 'snack',
        'timestamp': DateTime.fromMillisecondsSinceEpoch(ms).toIso8601String(),
      },
    );

List<FoodEntry> _merge(List<FoodEntry> local, List<SyncRecord> server) =>
    mergeById<FoodEntry>(
      local: local,
      server: server,
      idOf: (e) => e.id,
      updatedAtMsOf: (e) => e.syncUpdatedAt.millisecondsSinceEpoch,
      fromRecord: (r) => FoodEntry.fromJson(r.data).copyWith(
        updatedAt: DateTime.fromMillisecondsSinceEpoch(r.updatedAtMs),
        deleted: r.deleted,
      ),
    );

void main() {
  group('mergeById (last-write-wins + tombstones)', () {
    test('a newer server record replaces the local row', () {
      final out = _merge([_food('a', 100, cal: 100)], [_rec('a', 200, cal: 500)]);
      expect(out.single.calories, 500);
    });

    test('an older server record is ignored', () {
      final out = _merge([_food('a', 200, cal: 100)], [_rec('a', 100, cal: 500)]);
      expect(out.single.calories, 100);
    });

    test('a newer tombstone marks the local row deleted', () {
      final out = _merge([_food('a', 100)], [_rec('a', 200, deleted: true)]);
      expect(out.single.deleted, isTrue);
    });

    test('local-only and server-only rows both survive', () {
      final out = _merge([_food('a', 100)], [_rec('b', 100)]);
      expect(out.map((e) => e.id).toSet(), {'a', 'b'});
    });
  });

  group('mergeProfile', () {
    UserProfile prof(int? ms) => UserProfile.defaultProfile.copyWith(
          weightKg: 70,
          updatedAt:
              ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms),
        );
    SyncRecord precord(int ms, double kg) => SyncRecord(
          id: 'profile',
          updatedAtMs: ms,
          deleted: false,
          data: UserProfile.defaultProfile.copyWith(weightKg: kg).toJson(),
        );

    test('a newer server profile wins', () {
      expect(mergeProfile(prof(100), precord(200, 88)).weightKg, 88);
    });

    test('an older server profile is ignored', () {
      expect(mergeProfile(prof(200), precord(100, 88)).weightKg, 70);
    });

    test('a null server profile keeps local', () {
      expect(mergeProfile(prof(100), null).weightKg, 70);
    });

    // Reinstall restore: the fresh local profile is unconfigured but launch-time
    // health refresh bumped its timestamp newer than the server. The user's real
    // configured server profile must still win (else their name/targets vanish).
    test('configured server restores over a fresh unconfigured local, even when '
        'the local timestamp is newer', () {
      final localFreshNewer = UserProfile.defaultProfile.copyWith(
        weightKg: 74, // launch-time health stat
        updatedAt: DateTime.fromMillisecondsSinceEpoch(9000), // "now"
      ); // isConfigured stays false
      final serverConfigured = SyncRecord(
        id: 'profile',
        updatedAtMs: 5000, // earlier than local
        deleted: false,
        data: UserProfile.defaultProfile
            .copyWith(name: 'roro', isConfigured: true, weightKg: 80)
            .toJson(),
      );
      final merged = mergeProfile(localFreshNewer, serverConfigured);
      expect(merged.isConfigured, isTrue);
      expect(merged.name, 'roro');
      expect(merged.weightKg, 80);
    });

    test('a configured local profile is NOT clobbered by an older server', () {
      final localConfiguredNewer = UserProfile.defaultProfile.copyWith(
        isConfigured: true,
        weightKg: 70,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(9000),
      );
      final serverOlder = SyncRecord(
        id: 'profile',
        updatedAtMs: 5000,
        deleted: false,
        data: UserProfile.defaultProfile
            .copyWith(isConfigured: true, weightKg: 88)
            .toJson(),
      );
      expect(mergeProfile(localConfiguredNewer, serverOlder).weightKg, 70);
    });
  });
}
