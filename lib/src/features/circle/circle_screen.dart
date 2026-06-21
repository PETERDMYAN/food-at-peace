import 'package:flutter/material.dart';

import 'circle_feed_screen.dart';
import 'circle_strip.dart';

/// The dedicated "Circle" tab: your circle strip (stories, friends, invite) on
/// top, with the shared-meal photo feed beneath it — so the whole social layer
/// lives in one place, instead of riding on top of the Trends charts.
class CircleScreen extends StatelessWidget {
  const CircleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // No AppBar — the bottom-nav tab already says "Circle", so a title bar just
    // wastes vertical space. The stories strip is the scrolling header of the
    // feed list (Instagram-style) so the WHOLE page scrolls as one — the strip
    // scrolls away as you go down the feed, instead of staying pinned.
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CircleFeedBody(
          header: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: const [
              Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: CircleStrip(),
              ),
              Divider(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
