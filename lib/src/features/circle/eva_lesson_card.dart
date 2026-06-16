import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_at_peace/l10n/app_localizations.dart';

import '../../data/eva_wisdom.dart';
import '../../widgets/story_avatar.dart';

/// A pinned card in "Your circle": **Eva** — a built-in companion everyone
/// follows — and her one life lesson for today. The line is keyed to the local
/// date (via [evaLessonIndex]), so it's the same for everyone and refreshes each
/// day, drawn from a bundled set with no network/model call. Pure client-side;
/// renders nothing until the lessons load (or if the asset is unavailable).
class EvaLessonCard extends ConsumerWidget {
  const EvaLessonCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessons = ref.watch(evaWisdomProvider).asData?.value ?? const [];
    if (lessons.isEmpty) return const SizedBox.shrink();
    final lesson = lessons[evaLessonIndex(DateTime.now(), lessons.length)];

    final t = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Eva's pinned avatar (consistent colour seed so she always looks the
          // same to everyone).
          const StoryAvatar(initials: 'E', colorSeed: 7, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Eva',
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '· ${t.evaDailyLesson}',
                      style: text.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  lesson.text(lang),
                  style: text.bodyMedium?.copyWith(height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
