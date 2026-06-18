import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_at_peace/l10n/app_localizations.dart';

import '../../providers/providers.dart';

/// Choose which device's **active energy** counts when more than one source
/// (e.g. Garmin Connect + Apple Watch) writes to Apple Health. "Automatic"
/// combines them; picking a source makes it win. Garmin still arrives via Apple
/// Health (a fully direct Garmin link needs Garmin's developer program).
class DataSourcesScreen extends ConsumerWidget {
  const DataSourcesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final connected = ref.watch(healthConnectedProvider);
    final selected = ref.watch(energySourcePriorityProvider);
    final sources = ref.watch(energySourcesProvider);

    Widget option(String label, String? value, {String? subtitle}) {
      final on = selected == value;
      return ListTile(
        leading: Icon(
          on ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          color: on ? scheme.primary : null,
        ),
        title: Text(label),
        subtitle: subtitle == null ? null : Text(subtitle),
        onTap: () => ref.read(energySourcePriorityProvider.notifier).set(value),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(t.dataSources)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t.dataSourcesBody,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(t.dataSourcesHeader, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          if (!connected)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                t.dataSourcesConnectFirst,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            )
          else ...[
            option(t.sourceAutomatic, null),
            sources.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => const SizedBox.shrink(),
              data: (list) => list.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        t.dataSourcesNone,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    )
                  : Column(
                      children: [for (final s in list) option(s, s)],
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
