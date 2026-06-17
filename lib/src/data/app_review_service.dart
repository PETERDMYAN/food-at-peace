import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/providers.dart';

/// Thin wrapper over the OS "rate this app" flow so the prompter depends on an
/// interface and tests can inject a fake (the real `SKStoreReviewController`
/// can't run in a unit test).
abstract interface class AppReviewService {
  Future<bool> isAvailable();
  Future<void> requestReview();
}

/// `in_app_review`-backed implementation (SKStoreReviewController on iOS).
class StoreKitAppReviewService implements AppReviewService {
  final InAppReview _inner = InAppReview.instance;

  @override
  Future<bool> isAvailable() async {
    try {
      return await _inner.isAvailable();
    } catch (_) {
      return false; // e.g. web / unsupported
    }
  }

  @override
  Future<void> requestReview() async {
    try {
      await _inner.requestReview();
    } catch (_) {
      // Best-effort — the OS may decline to show it; never surface an error.
    }
  }
}

final appReviewServiceProvider = Provider<AppReviewService>(
  (ref) => StoreKitAppReviewService(),
);

/// Asks for an App Store review **once**, on the 5th time the user opens the app
/// (post-onboarding — it's driven from the home shell, which only mounts after
/// onboarding). iOS rate-limits the prompt anyway, and we never ask twice.
class AppReviewPrompter {
  AppReviewPrompter(this._prefs, this._service);

  final SharedPreferences _prefs;
  final AppReviewService _service;

  static const _countKey = 'app_open_count';
  static const _askedKey = 'app_review_requested';

  /// Opens before we ask (the open being registered counts, so the 5th open
  /// triggers it).
  static const opensBeforeAsk = 5;

  /// Count this open and, if we've hit the threshold and haven't asked before,
  /// request the native review prompt. Best-effort; safe to call every launch.
  Future<void> registerOpenAndMaybeAsk() async {
    if (_prefs.getBool(_askedKey) ?? false) return;
    final opens = (_prefs.getInt(_countKey) ?? 0) + 1;
    await _prefs.setInt(_countKey, opens);
    if (opens < opensBeforeAsk) return;
    if (!await _service.isAvailable()) return; // try again next launch
    await _service.requestReview();
    await _prefs.setBool(_askedKey, true);
  }
}

final appReviewPrompterProvider = Provider<AppReviewPrompter>(
  (ref) => AppReviewPrompter(
    ref.read(sharedPreferencesProvider),
    ref.read(appReviewServiceProvider),
  ),
);
