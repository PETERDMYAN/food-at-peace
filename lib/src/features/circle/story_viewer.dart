import 'package:flutter/material.dart';

/// A full-screen, Instagram-stories-style viewer: segmented progress bar on top,
/// tap the right side to advance / left to go back, swipe down or ✕ to close.
/// [pages] are full-bleed page widgets (each lays out under the progress bar).
Future<void> showStory(BuildContext context, {required List<Widget> pages}) {
  if (pages.isEmpty) return Future<void>.value();
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: true,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, _, _) => _StoryViewer(pages: pages),
      transitionsBuilder: (_, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
    ),
  );
}

class _StoryViewer extends StatefulWidget {
  const _StoryViewer({required this.pages});

  final List<Widget> pages;

  @override
  State<_StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<_StoryViewer> {
  int _i = 0;

  void _next() {
    if (_i < widget.pages.length - 1) {
      setState(() => _i++);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _prev() {
    if (_i > 0) setState(() => _i--);
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
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.pages[_i],
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 4, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            for (var j = 0; j < widget.pages.length; j++)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                  child: Container(
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: j <= _i
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
