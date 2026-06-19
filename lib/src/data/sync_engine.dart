import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/food_entry.dart';
import '../models/sync_record.dart';
import '../models/user_profile.dart';
import '../models/weight_entry.dart';
import '../providers/providers.dart';
import 'auth_client.dart';
import 'sync_client.dart';

// ---- Cursor ----------------------------------------------------------------

/// Remembers the last `serverTime` we synced to, scoped to a user. A different
/// signed-in user resets the cursor to 0 (→ a full pull of their data).
class SyncCursorStore {
  SyncCursorStore(this._prefs);

  final SharedPreferences _prefs;
  static const _msKey = 'sync_cursor_ms';
  static const _userKey = 'sync_cursor_user';

  int cursorFor(String userId) {
    if (_prefs.getString(_userKey) != userId) return 0;
    return _prefs.getInt(_msKey) ?? 0;
  }

  Future<void> save(String userId, int serverTimeMs) async {
    await _prefs.setString(_userKey, userId);
    await _prefs.setInt(_msKey, serverTimeMs);
  }

  /// Forgets the cursor entirely — used after account deletion so that a later
  /// sign-in (even by the same user) starts at 0 and re-pushes everything
  /// that's still on the device.
  Future<void> clear() async {
    await _prefs.remove(_msKey);
    await _prefs.remove(_userKey);
  }
}

// ---- Pure merge (last-write-wins, tombstone-aware) -------------------------

/// Merges [server] records into [local] by id: a server record wins only when
/// it's strictly newer than the local row. Tombstones are kept (the UI hides
/// them). Local-only rows are preserved. Pure — unit-tested.
List<T> mergeById<T>({
  required List<T> local,
  required List<SyncRecord> server,
  required String Function(T) idOf,
  required int Function(T) updatedAtMsOf,
  required T Function(SyncRecord) fromRecord,
}) {
  final byId = {for (final e in local) idOf(e): e};
  for (final rec in server) {
    final existing = byId[rec.id];
    if (existing == null || rec.updatedAtMs > updatedAtMsOf(existing)) {
      byId[rec.id] = fromRecord(rec);
    }
  }
  return byId.values.toList();
}

/// LWW for the profile singleton — with a restore guard.
UserProfile mergeProfile(UserProfile local, SyncRecord? server) {
  if (server == null) return local;
  final serverProfile = _profileFromRecord(server);
  // Restore guard: on a fresh install the local profile is *unconfigured* (the
  // default, possibly filled with launch-time HealthKit stats). That health
  // refresh stamps the local profile with `updatedAt = now`, which would beat
  // the user's real (configured) server profile under plain last-write-wins —
  // silently discarding their name/targets after a reinstall. So a configured
  // server profile ALWAYS wins over an unconfigured local one.
  if (serverProfile.isConfigured && !local.isConfigured) return serverProfile;
  if (server.updatedAtMs > local.syncUpdatedAt.millisecondsSinceEpoch) {
    return serverProfile;
  }
  return local;
}

// ---- Model <-> record mappers ----------------------------------------------

SyncRecord _foodToRecord(FoodEntry e) => SyncRecord(
  id: e.id,
  updatedAtMs: e.syncUpdatedAt.millisecondsSinceEpoch,
  deleted: e.deleted,
  data: e.toJson(),
);

FoodEntry _foodFromRecord(SyncRecord r) => FoodEntry.fromJson(r.data).copyWith(
  updatedAt: DateTime.fromMillisecondsSinceEpoch(r.updatedAtMs),
  deleted: r.deleted,
);

SyncRecord _weightToRecord(WeightEntry e) => SyncRecord(
  id: e.id,
  updatedAtMs: e.syncUpdatedAt.millisecondsSinceEpoch,
  deleted: e.deleted,
  data: e.toJson(),
);

WeightEntry _weightFromRecord(SyncRecord r) =>
    WeightEntry.fromJson(r.data).copyWith(
      updatedAt: DateTime.fromMillisecondsSinceEpoch(r.updatedAtMs),
      deleted: r.deleted,
    );

SyncRecord _profileToRecord(UserProfile p) => SyncRecord(
  id: 'profile',
  updatedAtMs: p.syncUpdatedAt.millisecondsSinceEpoch,
  deleted: false,
  data: p.toJson(),
);

UserProfile _profileFromRecord(SyncRecord r) => UserProfile.fromJson(
  r.data,
).copyWith(updatedAt: DateTime.fromMillisecondsSinceEpoch(r.updatedAtMs));

// ---- Engine ----------------------------------------------------------------

enum SyncPhase { idle, syncing, error }

class SyncState {
  const SyncState({this.phase = SyncPhase.idle, this.lastSyncedAt, this.error});

  final SyncPhase phase;
  final DateTime? lastSyncedAt;
  final String? error;

  SyncState copyWith({
    SyncPhase? phase,
    DateTime? lastSyncedAt,
    String? error,
    bool clearError = false,
  }) => SyncState(
    phase: phase ?? this.phase,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    error: clearError ? null : (error ?? this.error),
  );
}

final syncClientProvider = Provider<SyncClient>(
  (ref) => SyncClient(baseUrl: proxyBaseUrl),
);

final syncCursorStoreProvider = Provider<SyncCursorStore>(
  (ref) => SyncCursorStore(ref.watch(sharedPreferencesProvider)),
);

/// Best-effort bidirectional sync. Triggers itself on sign-in and after local
/// edits (debounced); the app also calls [syncNow] on resume and from the
/// manual "Sync now" button. Keep it alive by watching it somewhere durable
/// (the HomeShell does), so its listeners are active.
class SyncEngine extends Notifier<SyncState> {
  Timer? _debounce;
  bool _running = false;
  bool _applyingMerge = false; // suppress self-trigger during a merge reload
  bool _suspended = false; // account deletion in progress — no syncs allowed
  Completer<void>? _runningDone; // completes when the in-flight sync ends

  /// Quiesces the engine for account deletion: cancels the pending debounce,
  /// blocks new syncs, and waits for any in-flight sync to finish — otherwise
  /// a racing push could repopulate the account mid-deletion (or re-save the
  /// cursor after it's been cleared).
  Future<void> suspendForAccountDeletion() async {
    _suspended = true;
    _debounce?.cancel();
    final inFlight = _runningDone;
    if (inFlight != null) await inFlight.future;
  }

  /// Re-enables syncing (call from a `finally` after the deletion attempt).
  void resumeAfterAccountDeletion() => _suspended = false;

  @override
  SyncState build() {
    ref.keepAlive(); // app-lifetime engine: stay alive so its listeners keep firing
    ref.onDispose(() => _debounce?.cancel());

    // Initial pull when a user signs in (or the persisted session loads).
    ref.listen(authProvider, (prev, next) {
      if (next != null && prev?.userId != next.userId) scheduleSync();
    });
    if (ref.read(authProvider) != null) scheduleSync();

    // Debounced push after any local change (but not our own merge reloads).
    ref.listen(foodEntriesProvider, (_, _) => _onLocalChange());
    ref.listen(weightEntriesProvider, (_, _) => _onLocalChange());
    ref.listen(profileProvider, (_, _) => _onLocalChange());

    return const SyncState();
  }

  void _onLocalChange() {
    if (!_applyingMerge) scheduleSync();
  }

  /// Coalesces bursts of edits into a single sync ~2s later.
  void scheduleSync() {
    if (_suspended) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), syncNow);
  }

  Future<void> syncNow() async {
    final session = ref.read(authProvider);
    if (_suspended || session == null || _running) return;
    _running = true;
    _runningDone = Completer<void>();
    state = state.copyWith(phase: SyncPhase.syncing, clearError: true);
    try {
      final cursor = ref.read(syncCursorStoreProvider);
      final since = cursor.cursorFor(session.userId);
      final foodRepo = ref.read(foodRepositoryProvider);
      final weightRepo = ref.read(weightRepositoryProvider);
      final profileRepo = ref.read(profileRepositoryProvider);

      bool changed(DateTime t) => t.millisecondsSinceEpoch > since;

      final result = await ref
          .read(syncClientProvider)
          .sync(
            token: session.token,
            sinceMs: since,
            food: [
              for (final e in foodRepo.loadAll())
                if (changed(e.syncUpdatedAt)) _foodToRecord(e),
            ],
            weight: [
              for (final e in weightRepo.loadAll())
                if (changed(e.syncUpdatedAt)) _weightToRecord(e),
            ],
            profile: changed(profileRepo.load().syncUpdatedAt)
                ? _profileToRecord(profileRepo.load())
                : null,
          );

      _applyingMerge = true;
      if (result.food.isNotEmpty) {
        await foodRepo.saveAll(
          mergeById<FoodEntry>(
            local: foodRepo.loadAll(),
            server: result.food,
            idOf: (e) => e.id,
            updatedAtMsOf: (e) => e.syncUpdatedAt.millisecondsSinceEpoch,
            fromRecord: _foodFromRecord,
          ),
        );
        ref.read(foodEntriesProvider.notifier).reload();
      }
      if (result.weight.isNotEmpty) {
        await weightRepo.saveAll(
          mergeById<WeightEntry>(
            local: weightRepo.loadAll(),
            server: result.weight,
            idOf: (e) => e.id,
            updatedAtMsOf: (e) => e.syncUpdatedAt.millisecondsSinceEpoch,
            fromRecord: _weightFromRecord,
          ),
        );
        ref.read(weightEntriesProvider.notifier).reload();
      }
      if (result.profile != null) {
        await profileRepo.save(
          mergeProfile(profileRepo.load(), result.profile),
        );
        ref.read(profileProvider.notifier).reload();
      }
      _applyingMerge = false;

      await cursor.save(session.userId, result.serverTimeMs);
      state = state.copyWith(
        phase: SyncPhase.idle,
        lastSyncedAt: DateTime.now(),
        clearError: true,
      );
    } on SessionExpired {
      await ref.read(authProvider.notifier).signOut();
      state = state.copyWith(phase: SyncPhase.idle);
    } catch (e) {
      state = state.copyWith(
        phase: SyncPhase.error,
        error: e is AuthException
            ? e.message
            : 'Sync failed. Please try again.',
      );
    } finally {
      _applyingMerge = false;
      _running = false;
      _runningDone?.complete();
      _runningDone = null;
    }
  }
}

final syncEngineProvider = NotifierProvider<SyncEngine, SyncState>(
  SyncEngine.new,
);
