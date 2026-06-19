import 'package:flutter/material.dart';
import 'package:food_at_peace/l10n/app_localizations.dart';

import 'circle_feed_screen.dart';
import 'circle_strip.dart';

/// The dedicated "Circle" tab: your circle strip (stories, friends, invite) on
/// top, with the shared-meal photo feed beneath it — so the whole social layer
/// lives in one place, instead of riding on top of the Trends charts.
class CircleScreen extends StatelessWidget {
  const CircleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.navCircle)),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: CircleStrip(),
            ),
            Divider(height: 1),
            Expanded(child: CircleFeedBody()),
          ],
        ),
      ),
    );
  }
}
