import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One of Eva's daily life lessons, in both supported languages.
class EvaLesson {
  const EvaLesson({required this.en, required this.zh});

  final String en;
  final String zh;

  factory EvaLesson.fromJson(Map<String, dynamic> j) =>
      EvaLesson(en: j['en'] as String, zh: j['zh'] as String);

  /// The line in [languageCode] (`zh` → Chinese, anything else → English).
  String text(String languageCode) => languageCode == 'zh' ? zh : en;
}

/// Index of today's lesson, keyed to the **local calendar date** so it flips at
/// local midnight and is the same for everyone on that date (communal). Pure +
/// deterministic so it's unit-testable. [count] is the number of lessons; the
/// cycle simply repeats once it's exhausted.
int evaLessonIndex(DateTime localNow, int count) {
  if (count <= 0) return 0;
  final epochDay = DateTime.utc(localNow.year, localNow.month, localNow.day)
      .difference(DateTime.utc(1970, 1, 1))
      .inDays;
  return epochDay % count;
}

/// All of Eva's pre-generated lessons, loaded once from the bundled asset — no
/// runtime model call, so it works offline. Returns `[]` if the asset is missing
/// or malformed (the card then simply hides). Additive + bundled, so it's safe
/// for the shipped client (see the `production-safety` skill).
final evaWisdomProvider = FutureProvider<List<EvaLesson>>((ref) async {
  try {
    final raw = await rootBundle.loadString('assets/eva_wisdom.json');
    final list = jsonDecode(raw) as List;
    return [
      for (final e in list) EvaLesson.fromJson(e as Map<String, dynamic>),
    ];
  } catch (_) {
    return const [];
  }
});
