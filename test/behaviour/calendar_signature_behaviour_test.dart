// `calendar`'s week and day views, and `signature`'s whole gesture path —
// neither had ever been drawn by a test, and `signature` had never had a stroke
// put on it.
//
// Both are asked here the way the rest of the behaviour suite asks: not "does
// it build" but "is what I declared on the screen, and does what I do to it
// change the picture". A signature pad that accepts a drag and paints nothing
// builds perfectly.

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

import 'painted_probe.dart';

void main() {
  final live = <MCPUIRuntime>[];
  tearDown(() {
    for (final runtime in live) {
      runtime.destroy();
    }
    live.clear();
  });

  var seq = 0;

  Future<Painted> render(
    WidgetTester tester,
    Map<String, dynamic> content, {
    Map<String, dynamic>? initialState,
    Size size = const Size(420, 460),
    Key? key,
  }) async {
    final probeKey = key ?? ValueKey('probe-${seq++}');
    final runtime = MCPUIRuntime();
    live.add(runtime);
    final definition = <String, dynamic>{'type': 'page', 'content': content};
    if (initialState != null) {
      definition['runtime'] = {
        'services': {
          'state': {'initialState': initialState},
        },
      };
    }
    await runtime.initialize(definition);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: isolated(
            SizedBox(
                width: size.width, height: size.height, child: runtime.buildUI()),
            key: probeKey,
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    late Painted painted;
    await tester.runAsync(() async {
      painted = await paintedOf(tester, find.byKey(probeKey));
    });
    return painted;
  }

  group('calendar views', () {
    Map<String, dynamic> calendar(String view) => {
          'type': 'calendar',
          'view': view,
          'selectedDate': '2026-08-12',
          'events': [
            {'date': '2026-08-12', 'title': 'Shift review'},
            {'date': '2026-08-13', 'title': 'Line audit'},
          ],
        };

    testWidgets('month, week and day each draw a different picture',
        (tester) async {
      final month = await render(tester, calendar('month'));
      final week = await render(tester, calendar('week'));
      final day = await render(tester, calendar('day'));

      for (final entry in {'month': month, 'week': week, 'day': day}.entries) {
        expect(entry.value.nonBackground(), greaterThan(0),
            reason: '${entry.key} drew nothing at all');
      }
      // A `view` that is read and then ignored is the defect this catches: all
      // three would be the same month grid.
      expect(difference(month, week), greaterThan(0.01),
          reason: 'week must not be the month grid');
      expect(difference(week, day), greaterThan(0.01),
          reason: 'day must not be the week strip');
    });

    testWidgets('an event on the selected day reaches the day view',
        (tester) async {
      await render(tester, calendar('day'));
      expect(find.text('Shift review'), findsWidgets,
          reason: 'the day view is where an event is read, not just counted');
      expect(find.text('Line audit'), findsNothing,
          reason: 'and it is the SELECTED day, not the next one');
    });

    testWidgets('the week view carries the days of its week', (tester) async {
      await render(tester, calendar('week'));
      // 2026-08-12 is a Wednesday; the week strip must show its neighbours.
      expect(find.text('12'), findsWidgets);
      expect(find.text('13'), findsWidgets);
    });

    testWidgets('a view outside the enum is refused by the schema, not drawn',
        (tester) async {
      // The fallback branch in the factory is unreachable from a document: the
      // schema rejects `view: decade` before the widget is built. Pinning the
      // gate is the honest test — asserting the fallback would require going
      // around the validation a real document cannot go around.
      final runtime = MCPUIRuntime();
      live.add(runtime);
      await expectLater(
        runtime.initialize({'type': 'page', 'content': calendar('decade')}),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('signature', () {
    testWidgets('a drag paints a stroke, and clear takes it away',
        (tester) async {
      const pad = {
        'type': 'signature',
        'penColor': '#E91E63',
        'penWidth': 4,
        'showClearButton': true,
      };

      const padKey = ValueKey('pad');
      final blank =
          await render(tester, pad, size: const Size(300, 200), key: padKey);
      expect(blank.count(const Color(0xFFE91E63)), 0,
          reason: 'nothing has been drawn yet');

      // Drag across the pad: this is the gesture path (`_onPanStart` /
      // `_onPanUpdate`) that no test had ever run.
      final centre = tester.getCenter(find.byType(GestureDetector).first);
      final gesture = await tester.startGesture(centre - const Offset(60, 20));
      await gesture.moveBy(const Offset(40, 15));
      await gesture.moveBy(const Offset(40, -15));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 50));

      late Painted drawn;
      await tester.runAsync(() async {
        drawn = await paintedOf(tester, find.byKey(padKey));
      });
      expect(drawn.count(const Color(0xFFE91E63)), greaterThan(0),
          reason: 'a pad that accepts a drag and paints nothing is the defect');

      // The clear affordance must actually clear.
      final clear = find.byIcon(Icons.clear);
      if (clear.evaluate().isNotEmpty) {
        await tester.tap(clear.first);
        await tester.pump(const Duration(milliseconds: 50));
        late Painted cleared;
        await tester.runAsync(() async {
          cleared = await paintedOf(tester, find.byKey(padKey));
        });
        expect(cleared.count(const Color(0xFFE91E63)), 0,
            reason: 'clear has to remove the strokes, not hide the button');
      }
    });

    testWidgets('a finished stroke hands the document a picture it can submit',
        (tester) async {
      final runtime = MCPUIRuntime();
      live.add(runtime);
      await runtime.initialize(<String, dynamic>{
        'type': 'page',
        'state': <String, dynamic>{
          'initial': <String, dynamic>{'signatureData': '', 'count': 0},
        },
        'content': <String, dynamic>{
          'type': 'signature',
          'binding': 'signatureData',
          'penColor': '#000000',
          // §10.19's own example, verbatim.
          'onSignatureEnd': <String, dynamic>{
            'type': 'state',
            'action': 'set',
            'binding': 'fromEvent',
            'value': '{{event.value}}',
          },
        },
      });
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 300, height: 200, child: runtime.buildUI()),
        ),
      ));
      await tester.pump();

      final centre = tester.getCenter(find.byType(GestureDetector).first);
      // `toImage` is a real encode, so the whole gesture runs inside
      // `runAsync` — without it the future never completes and the binding
      // stays empty for a reason that has nothing to do with the behaviour.
      await tester.runAsync(() async {
        final gesture = await tester.startGesture(centre - const Offset(60, 20));
        await gesture.moveBy(const Offset(40, 15));
        await gesture.moveBy(const Offset(40, -15));
        await gesture.up();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      final stored = runtime.stateManager.get<String>('signatureData');
      expect(stored, isNotNull);
      expect(stored, startsWith('data:image/png;base64,'),
          reason: '§10.19 says the binding holds a base64 PNG or an SVG path; '
              'an internal stroke dump is neither, so a document could not '
              'render or submit what the user signed');
      expect(stored!.length, greaterThan(100),
          reason: 'an empty encode is a blank picture');

      expect(runtime.stateManager.get<String>('fromEvent'), stored,
          reason: "the spec's own onSignatureEnd example writes "
              '`{{event.value}}`; with no `value` on the event it stored '
              'null and the signature was lost at the moment it was made');
    });

    testWidgets('the stroke coordinates stay reachable on the event',
        (tester) async {
      final runtime = MCPUIRuntime();
      live.add(runtime);
      await runtime.initialize(<String, dynamic>{
        'type': 'page',
        'state': <String, dynamic>{'initial': <String, dynamic>{}},
        'content': <String, dynamic>{
          'type': 'signature',
          'onSignatureEnd': <String, dynamic>{
            'type': 'state',
            'action': 'set',
            'binding': 'strokes',
            'value': '{{event.strokes}}',
          },
        },
      });
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 300, height: 200, child: runtime.buildUI()),
        ),
      ));
      await tester.pump();

      final centre = tester.getCenter(find.byType(GestureDetector).first);
      await tester.runAsync(() async {
        final gesture = await tester.startGesture(centre - const Offset(60, 20));
        await gesture.moveBy(const Offset(40, 15));
        await gesture.moveBy(const Offset(40, -15));
        await gesture.up();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      final strokes = runtime.stateManager.get<List<dynamic>>('strokes');
      expect(strokes, hasLength(1),
          reason: 'a document that wants the vector rather than the picture '
              'still has it');
      expect((strokes!.first as List).length, greaterThan(1));
    });

    testWidgets('clearing puts the binding back to nothing', (tester) async {
      final runtime = MCPUIRuntime();
      live.add(runtime);
      await runtime.initialize(<String, dynamic>{
        'type': 'page',
        'state': <String, dynamic>{
          'initial': <String, dynamic>{'signatureData': 'stale'},
        },
        'content': <String, dynamic>{
          'type': 'signature',
          'binding': 'signatureData',
          'showClearButton': true,
        },
      });
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 300, height: 200, child: runtime.buildUI()),
        ),
      ));
      await tester.pump();

      // The clear affordance only appears once there is something to clear.
      final centre = tester.getCenter(find.byType(GestureDetector).first);
      await tester.runAsync(() async {
        final gesture = await tester.startGesture(centre - const Offset(60, 20));
        await gesture.moveBy(const Offset(40, 15));
        await gesture.moveBy(const Offset(40, -15));
        await gesture.up();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      expect(runtime.stateManager.get<String>('signatureData'),
          startsWith('data:image/png;base64,'));

      await tester.tap(find.byIcon(Icons.clear).first);
      await tester.pump();

      expect(runtime.stateManager.get('signatureData'), isNull,
          reason: 'a cleared pad that leaves the old picture in state submits '
              'a signature the user has just withdrawn');
    });

    testWidgets('the declared stroke colour is the colour painted',
        (tester) async {
      const padKey = ValueKey('teal-pad');
      await render(
        tester,
        {'type': 'signature', 'penColor': '#00897B', 'penWidth': 6},
        size: const Size(300, 200),
        key: padKey,
      );

      // Two moves, not one: the first update crosses the touch slop, so a
      // single-jump drag leaves the stroke with one point and `_drawStroke`
      // draws nothing below two. (A one-point stroke marking nothing is its own
      // small question — a tap on a signature pad arguably deserves a dot —
      // left as it is rather than changed on the way past.)
      // The same gesture shape as the test above — two moves, so the stroke
      // has more than the one point `_drawStroke` needs.
      final centre = tester.getCenter(find.byType(GestureDetector).first);
      final gesture = await tester.startGesture(centre - const Offset(60, 20));
      await gesture.moveBy(const Offset(40, 15));
      await gesture.moveBy(const Offset(40, -15));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 50));

      late Painted painted;
      await tester.runAsync(() async {
        painted = await paintedOf(tester, find.byKey(padKey));
      });
      expect(painted.count(const Color(0xFF00897B)), greaterThan(0),
          reason: 'a declared colour that is read and discarded draws in the '
              'default instead, and nothing says so');
    });
  });
}
