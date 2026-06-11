import 'package:flutter/material.dart';
import 'package:food_at_peace/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

/// One referenced calculation: a plain-English method + a citation that links
/// out to the primary source.
class _Source {
  const _Source(this.title, this.method, this.citation, this.url);
  final String title;
  final String method;
  final String citation;
  final String url;
}

/// Citations & methodology for the health estimates the app shows (App Store
/// Guideline 1.4.1). The reference text is kept in English (bibliographic) while
/// the screen chrome is localized.
const List<_Source> _sources = [
  _Source(
    'Resting energy (BMR)',
    'Estimated from your sex, age, height and weight using the Mifflin–St Jeor equation.',
    'Mifflin MD, St Jeor ST, Hill LA, et al. A new predictive equation for resting '
        'energy expenditure in healthy individuals. Am J Clin Nutr. 1990;51(2):241–247.',
    'https://pubmed.ncbi.nlm.nih.gov/2305711/',
  ),
  _Source(
    'Daily calorie budget',
    'Resting energy (BMR) + active energy burned (from Apple Health) + your goal gap '
        '(−500 lose / 0 maintain / +400 gain kcal per day).',
    'U.S. Department of Agriculture & U.S. Department of Health and Human Services. '
        'Dietary Guidelines for Americans, 2020–2025.',
    'https://www.dietaryguidelines.gov/',
  ),
  _Source(
    'Protein target',
    '1.6 g of protein per kilogram of body weight.',
    'Jäger R, Kerksick CM, Campbell BI, et al. International Society of Sports '
        'Nutrition Position Stand: protein and exercise. J Int Soc Sports Nutr. 2017;14:20.',
    'https://jissn.biomedcentral.com/articles/10.1186/s12970-017-0177-8',
  ),
  _Source(
    'Saturated-fat cap',
    'Limited to less than 10% of your daily calories.',
    'U.S. Department of Agriculture & U.S. Department of Health and Human Services. '
        'Dietary Guidelines for Americans, 2020–2025.',
    'https://www.dietaryguidelines.gov/',
  ),
];

/// A scrollable list of the references behind the app's calorie / macro
/// estimates, each linking to its primary source, plus a medical disclaimer.
class SourcesScreen extends StatelessWidget {
  const SourcesScreen({super.key});

  Future<void> _open(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok) {
      messenger.showSnackBar(SnackBar(content: Text(url)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(t.sourcesTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(t.sourcesIntro, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          // Disclaimer.
          Card(
            color: scheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: scheme.onSecondaryContainer,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      t.sourcesDisclaimer,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSecondaryContainer,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (final s in _sources) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(s.method, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 10),
                    Text(
                      s.citation,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _open(context, s.url),
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: Text(t.viewSource),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          minimumSize: const Size(0, 36),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
