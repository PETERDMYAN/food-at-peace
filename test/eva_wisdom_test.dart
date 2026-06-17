import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_at_peace/src/data/eva_wisdom.dart';

void main() {
  test('evaLessonIndex is stable per local date and advances daily', () {
    final i = evaLessonIndex(DateTime(2026, 6, 17, 23, 30), 100);
    expect(i, inInclusiveRange(0, 99));
    // Same calendar date, any time of day → same lesson (communal).
    expect(evaLessonIndex(DateTime(2026, 6, 17, 0, 1), 100), i);
    // Next local day → the next lesson, wrapping the cycle.
    expect(evaLessonIndex(DateTime(2026, 6, 18, 9), 100), (i + 1) % 100);
  });

  test('evaLessonIndex stays in range and never throws on empty', () {
    expect(evaLessonIndex(DateTime(2026, 1, 1), 0), 0);
    expect(evaLessonIndex(DateTime(2026, 1, 1), 7), inInclusiveRange(0, 6));
  });

  test('EvaLesson.text picks the language', () {
    const l = EvaLesson(en: 'Rest is part of the work.', zh: '休息也是努力的一部分。');
    expect(l.text('zh'), '休息也是努力的一部分。');
    expect(l.text('en'), 'Rest is part of the work.');
    expect(l.text('fr'), 'Rest is part of the work.'); // non-zh → English
  });

  test('EvaLesson.author picks the language; missing → localized fallback', () {
    const l = EvaLesson(en: 'x', zh: 'x', byEn: 'Michael Pollan', byZh: '迈克尔·波伦');
    expect(l.author('en'), 'Michael Pollan');
    expect(l.author('zh'), '迈克尔·波伦');
    // fromJson without by* falls back to a localized Unknown.
    final f = EvaLesson.fromJson({'en': 'x', 'zh': 'y'});
    expect(f.author('en'), 'Unknown');
    expect(f.author('zh'), '佚名');
  });

  test('eva_wisdom.json has 100 lessons, each bilingual + attributed', () {
    final raw = File('assets/eva_wisdom.json').readAsStringSync();
    final list = jsonDecode(raw) as List;
    expect(list.length, 100);
    for (final e in list) {
      final m = e as Map<String, dynamic>;
      expect((m['en'] as String).trim(), isNotEmpty);
      expect((m['zh'] as String).trim(), isNotEmpty);
      expect((m['byEn'] as String).trim(), isNotEmpty);
      expect((m['byZh'] as String).trim(), isNotEmpty);
    }
  });
}
