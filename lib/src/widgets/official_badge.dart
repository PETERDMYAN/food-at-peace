import 'package:flutter/material.dart';
import 'package:food_at_peace/l10n/app_localizations.dart';

/// A blue "Official" tag for the first-party accounts (the creator **@roro** and
/// the coach **Eva**) so users can tell them apart from peer friends. Verified
/// style: a check glyph + label on a blue tint. Shown to everyone *except* the
/// creator themselves (see the call sites' `viewerIsRoro` gate).
class OfficialBadge extends StatelessWidget {
  const OfficialBadge({super.key});

  /// The conventional "verified/official" blue (distinct from the app's green).
  static const Color blue = Color(0xFF2E9BFF);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 2, 7, 2),
      decoration: BoxDecoration(
        color: blue.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified, size: 13, color: blue),
          const SizedBox(width: 3),
          Text(
            AppLocalizations.of(context).officialBadge,
            style: const TextStyle(
              color: blue,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
