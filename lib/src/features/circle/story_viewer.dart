import 'package:flutter/material.dart';

/// One person's story = an ordered list of full-bleed page widgets.
class Story {
  const Story({required this.pages});

  final List<Widget> pages;
}

/// A full-screen, Instagram-stories-style viewer over a **tray** of [stories]
/// (e.g. You → Eva). Within a story: segmented progress bar on top, tap the
/// right side / swipe left to advance, tap left / swipe right to go back, swipe
/// down or ✕ to close. Advancing past the last page of one story rolls into the
/// **next** story (and back past the first page returns to the previous one);
/// only the very end closes the viewer. [initialStory] picks which one opens.
Future<void> showStories(
  BuildContext context, {
  required List<Story> stories,
  int initialStory = 0,
}) {
  // Drop empty stories, remapping the initial index so it still points at the
  // intended (or nearest preceding) one.
  final live = <Story>[];
  var start = 0;
  for (var i = 0; i < stories.length; i++) {
    if (stories[i].pages.isEmpty) continue;
    if (i <= initialStory) start = live.length;
    live.add(stories[i]);
  }
  if (live.isEmpty) return Future<void>.value();
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: true,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, _, _) => _StoryViewer(stories: live, initialStory: start),
      transitionsBuilder: (_, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
    ),
  );
}

/// Back-compat helper for a single story.
Future<void> showStory(BuildContext context, {required List<Widget> pages}) =>
    showStories(context, stories: [Story(pages: pages)]);

class _StoryViewer extends StatefulWidget {
  const _StoryViewer({required this.stories, required this.initialStory});

  final List<Story> stories;
  final int initialStory;

  @override
  State<_StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<_StoryViewer> {
  late int _s = widget.initialStory; // current story
  int _p = 0; // current page within the story

  List<Widget> get _pages => widget.stories[_s].pages;

  void _next() {
    if (_p < _pages.length - 1) {
      setState(() => _p++);
    } else if (_s < widget.stories.length - 1) {
      // End of this story → roll into the next person's story.
      setState(() {
        _s++;
        _p = 0;
      });
    } else {
      Navigator.of(context).pop(); // end of the last story → close
    }
  }

  void _prev() {
    if (_p > 0) {
      setState(() => _p--);
    } else if (_s > 0) {
      // Start of this story → back to the previous person's last page.
      setState(() {
        _s--;
        _p = widget.stories[_s].pages.length - 1;
      });
    }
    // else: very first page — stay put.
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) => d.globalPosition.dx < width * 0.33 ? _prev() : _next(),
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) > 80) Navigator.of(context).pop();
        },
        // Swipe horizontally to move between pages/stories (flick or drag):
        // right-to-left → next, left-to-right → previous.
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v < -80) {
            _next();
          } else if (v > 80) {
            _prev();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            _pages[_p],
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 4, 0),
                  child: Row(
                    children: [
                      // Progress segments for the CURRENT story (reset per story).
                      Expanded(
                        child: Row(
                          children: [
                            for (var j = 0; j < _pages.length; j++)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                  child: Container(
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: j <= _p
                                          ? Colors.white
                                          : Colors.white24,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 22,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
