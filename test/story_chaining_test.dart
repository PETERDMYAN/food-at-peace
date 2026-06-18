// Verifies the story viewer chains across a tray: advancing past the last page
// of one story rolls into the next (not quit), and going back crosses the
// boundary the other way. Plain-widget pages (no images) so it settles cleanly.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_at_peace/src/features/circle/story_viewer.dart';

void main() {
  Future<Size> open(WidgetTester t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showStories(
                  ctx,
                  stories: const [
                    Story(pages: [Center(child: Text('A1')), Center(child: Text('A2'))]),
                    Story(pages: [Center(child: Text('B1'))]),
                  ],
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    return t.getSize(find.byType(MaterialApp));
  }

  testWidgets('advancing past the last page chains to the next story', (t) async {
    final size = await open(t);
    Future<void> tapRight() async {
      await t.tapAt(Offset(size.width * 0.8, size.height * 0.5));
      await t.pumpAndSettle();
    }

    expect(find.text('A1'), findsOneWidget);
    await tapRight();
    expect(find.text('A2'), findsOneWidget);
    await tapRight(); // past the last page of story A …
    expect(
      find.text('B1'),
      findsOneWidget,
      reason: 'should roll into the next story, not quit',
    );
  });

  testWidgets('going back crosses the boundary to the previous story', (t) async {
    final size = await open(t);
    Future<void> tapRight() async {
      await t.tapAt(Offset(size.width * 0.8, size.height * 0.5));
      await t.pumpAndSettle();
    }

    Future<void> tapLeft() async {
      await t.tapAt(Offset(size.width * 0.1, size.height * 0.5));
      await t.pumpAndSettle();
    }

    await tapRight(); // A2
    await tapRight(); // B1 (story B)
    expect(find.text('B1'), findsOneWidget);
    await tapLeft(); // back across the boundary → A2
    expect(find.text('A2'), findsOneWidget);
  });

  testWidgets('advancing past the very last story closes the viewer', (t) async {
    final size = await open(t);
    Future<void> tapRight() async {
      await t.tapAt(Offset(size.width * 0.8, size.height * 0.5));
      await t.pumpAndSettle();
    }

    await tapRight(); // A2
    await tapRight(); // B1
    await tapRight(); // end of last story → close
    expect(find.text('B1'), findsNothing);
    expect(find.text('open'), findsOneWidget); // back to the launcher
  });
}
