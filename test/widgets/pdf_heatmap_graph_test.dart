// `pdfViewer`'s open parameters, `heatmap`'s data shapes and colour schemes,
// and `networkGraph`'s layout of unconnected nodes.
//
// The PDF fragment is the whole of what a document can say about how its
// document opens — a dropped `page=` means the reader lands on page one of a
// forty-page contract. The heatmap's 1-D form is how a document hands over a
// flat series, and a scheme it does not know must still colour the grid.

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/default_widgets.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/widgets/advanced/pdf_viewer_factory.dart';
import 'package:flutter_test/flutter_test.dart';

import '../behaviour/painted_probe.dart';

void main() {
  late StateManager stateManager;
  late RenderContext context;

  setUp(() {
    stateManager = StateManager()..initialize(<String, dynamic>{});
    final registry = WidgetRegistry();
    DefaultWidgets.registerAll(registry);
    final bindingEngine = BindingEngine();
    final actionHandler = ActionHandler();
    context = RenderContext(
      renderer: Renderer(
        widgetRegistry: registry,
        bindingEngine: bindingEngine,
        actionHandler: actionHandler,
        stateManager: stateManager,
      ),
      stateManager: stateManager,
      bindingEngine: bindingEngine,
      actionHandler: actionHandler,
      themeManager: ThemeManager.instance,
    );
  });

  Future<void> pump(WidgetTester tester, Map<String, dynamic> definition) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AnimatedBuilder(
          animation: stateManager,
          builder: (_, __) => context.renderer.renderWidget(definition, context),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// Renders the definition on its own repaint boundary so its pixels can be
  /// read back — the only way to ask whether a painter drew anything.
  Future<Painted> painted(
    WidgetTester tester,
    Map<String, dynamic> definition,
  ) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: isolated(
            context.renderer.renderWidget(definition, context),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    late Painted result;
    await tester.runAsync(() async {
      result = await paintedOf(tester, find.byKey(const ValueKey('painted-probe')));
    });
    return result;
  }

  group('pdfViewer', () {
    testWidgets('with no source it says so, and reports it', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'pdfViewer',
        'onError': <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'failed',
          'value': '{{event.message}}',
        },
      });

      expect(find.text('No document'), findsOneWidget);
      expect(stateManager.get<String>('failed'), contains('no src'),
          reason: '§6.13 — a viewer that draws an empty frame and says nothing '
              'looks like a document that is still loading');
    });

    testWidgets('on a platform with no renderer it says which limit was hit',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'pdfViewer',
        'src': 'https://example.com/a.pdf',
        'onError': <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'failed',
          'value': '{{event.message}}',
        },
      });

      // The test platform has no PDF renderer, so this is the branch a
      // desktop or mobile host without one takes — and it is checked before
      // the source is examined, since no source is displayable here.
      expect(find.text('PDF viewing is not available on this platform'),
          findsOneWidget);
      expect(stateManager.get<String>('failed'), contains('no PDF renderer'));
    });
  });

    // Off the browser the factory can only take its "no renderer here"
    // branch, so what a browser would actually be handed — which sources are
    // displayable, and the §10.25 open-parameter fragment that decides the
    // page, the zoom and the chrome — had never been checked anywhere. The
    // seam supplies the browser's half; everything asserted below is the
    // factory's own logic.
    group('what a browser would be handed', () {
      late List<String> sources;

      setUp(() {
        sources = <String>[];
        debugPdfSupported = true;
        debugBuildPdfView = ({
          required String source,
          required double? height,
          Key? key,
        }) {
          sources.add(source);
          return const SizedBox.shrink();
        };
      });

      tearDown(() {
        debugPdfSupported = null;
        debugBuildPdfView = null;
      });

      Future<String> sourceFor(
        WidgetTester tester,
        Map<String, dynamic> extra,
      ) async {
        await pump(tester, <String, dynamic>{
          'type': 'pdfViewer',
          'src': 'https://example.com/contract.pdf',
          ...extra,
        });
        return sources.single;
      }

      testWidgets('with nothing declared it fits the width', (tester) async {
        expect(await sourceFor(tester, const {}),
            'https://example.com/contract.pdf#view=FitH',
            reason: 'a contract that opens zoomed to a corner is unreadable '
                'on a phone; fitting the width is the default for a reason');
      });

      testWidgets('the declared page is where the reader lands',
          (tester) async {
        expect(await sourceFor(tester, <String, dynamic>{'page': 12}),
            contains('page=12'),
            reason: 'a dropped page number lands the reader on page one of a '
                'forty-page document with no sign anything was ignored');
      });

      testWidgets('a zoom is sent as a percentage and wins over the fit',
          (tester) async {
        final source = await sourceFor(
            tester, <String, dynamic>{'zoom': 1.5, 'fit': 'height'});

        expect(source, contains('zoom=150'));
        expect(source, isNot(contains('view=Fit')),
            reason: 'an explicit zoom and a fit are two answers to the same '
                'question; sending both leaves the viewer to pick');
      });

      testWidgets('each fit has its own parameter', (tester) async {
        expect(await sourceFor(tester, <String, dynamic>{'fit': 'height'}),
            contains('view=FitV'));
        sources.clear();
        expect(await sourceFor(tester, <String, dynamic>{'fit': 'page'}),
            contains('view=Fit'));
      });

      testWidgets('hidden chrome is asked for by name', (tester) async {
        final source = await sourceFor(tester, <String, dynamic>{
          'showToolbar': false,
          'showPageNav': false,
        });

        expect(source, contains('toolbar=0'));
        expect(source, contains('navpanes=0'),
            reason: 'a document embedding a PDF in a card does not want the '
                'reader chrome over it');
      });

      testWidgets('hiding the zoom control pins the view instead',
          (tester) async {
        expect(await sourceFor(tester, <String, dynamic>{'showZoom': false}),
            contains('view=Fit'),
            reason: 'there is no open parameter for the zoom control, so the '
                'only way to honour the request is to leave it nothing to '
                'change');
      });

      testWidgets('an existing fragment is replaced, not appended to',
          (tester) async {
        await pump(tester, <String, dynamic>{
          'type': 'pdfViewer',
          'src': 'https://example.com/a.pdf#page=2',
          'page': 9,
        });

        expect(sources.single, 'https://example.com/a.pdf#page=9&view=FitH',
            reason: 'two fragments in one URL is a URL the viewer cannot '
                'read');
      });

      testWidgets('a data: URI is handed over untouched', (tester) async {
        await pump(tester, <String, dynamic>{
          'type': 'pdfViewer',
          'src': 'data:application/pdf;base64,JVBERi0=',
          'page': 3,
        });

        expect(sources.single, 'data:application/pdf;base64,JVBERi0=',
            reason: 'a data URI carries no fragment slot; appending one '
                'corrupts the payload');
      });

      testWidgets('a source the browser cannot fetch is reported, not drawn',
          (tester) async {
        await pump(tester, <String, dynamic>{
          'type': 'pdfViewer',
          'src': 'bundle://docs/contract.pdf',
          'onError': <String, dynamic>{
            'type': 'state',
            'action': 'set',
            'binding': 'error',
            'value': '{{event.message}}',
          },
        });
        await tester.pumpAndSettle();

        expect(sources, isEmpty);
        expect(stateManager.get<String>('error'), contains('bundle'),
            reason: 'a bundle-served document needs the host to hand over '
                'bytes; drawing an empty frame instead says nothing about '
                'what is missing');
      });
    });

  group('heatmap', () {
    Map<String, dynamic> heatmap({Map<String, dynamic> extra = const {}}) =>
        <String, dynamic>{
          'type': 'heatmap',
          'data': <dynamic>[
            <dynamic>[1, 2],
            <dynamic>[3, 4],
          ],
          ...extra,
        };

    testWidgets('a 2-D grid prints its values', (tester) async {
      await pump(tester, heatmap());

      expect(find.text('1'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('a flat series is folded into rows by `columns`',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'heatmap',
        'data': <dynamic>[1, 2, 3, 4, 5],
        'columns': 2,
      });

      expect(find.text('5'), findsOneWidget,
          reason: 'a series that does not divide evenly still has a last row; '
              'dropping it loses the most recent value');
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('a flat series with no column count draws nothing',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'heatmap',
        'data': <dynamic>[1, 2, 3],
      });

      expect(find.text('1'), findsNothing,
          reason: 'without a width there is no grid; guessing one would draw '
              'a shape the document did not describe');
    });

    testWidgets('values can be turned off', (tester) async {
      await pump(tester, heatmap(extra: <String, dynamic>{
        'showValues': false,
      }));

      expect(find.text('1'), findsNothing);
    });

    testWidgets('labels are drawn when asked for', (tester) async {
      await pump(tester, heatmap(extra: <String, dynamic>{
        'showLabels': true,
        'rowLabels': <dynamic>['Mon', 'Tue'],
        'columnLabels': <dynamic>['AM', 'PM'],
      }));

      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('PM'), findsOneWidget);
    });

    testWidgets('a cell reports where it was tapped', (tester) async {
      await pump(tester, heatmap(extra: <String, dynamic>{
        'showLabels': true,
        'rowLabels': <dynamic>['Mon', 'Tue'],
        'columnLabels': <dynamic>['AM', 'PM'],
        'onCellTap': <String, dynamic>{
          'type': 'batch',
          'actions': <dynamic>[
            <String, dynamic>{
              'type': 'state',
              'action': 'set',
              'binding': 'value',
              'value': '{{event.value}}',
            },
            <String, dynamic>{
              'type': 'state',
              'action': 'set',
              'binding': 'rowLabel',
              'value': '{{event.rowLabel}}',
            },
          ],
        },
      }));

      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();

      expect(stateManager.get('value'), 3);
      expect(stateManager.get('rowLabel'), 'Tue',
          reason: 'the label is what a document shows in its detail panel; '
              'the index alone makes the caller re-derive it');
    });

    testWidgets('every named colour scheme draws', (tester) async {
      for (final scheme in const [
        'blue',
        'purple',
        'orange',
        'grayscale',
        'chartreuse',
      ]) {
        await pump(tester, heatmap(extra: <String, dynamic>{
          'colorScheme': scheme,
        }));
        expect(find.text('1'), findsOneWidget, reason: scheme);
      }
    });

    testWidgets('a declared colour range replaces the scheme', (tester) async {
      await pump(tester, heatmap(extra: <String, dynamic>{
        'colorRange': <String, dynamic>{'low': '#FFFFFF', 'high': '#FF0000'},
        'minValue': 0,
        'maxValue': 10,
      }));

      expect(find.text('1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('with no data at all there is nothing to draw', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'heatmap',
        'data': <dynamic>[],
      });

      expect(tester.takeException(), isNull);
    });
  });

  group('networkGraph', () {
    testWidgets('nodes with no edges are still laid out on the canvas',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'networkGraph',
        'nodes': <dynamic>[
          <String, dynamic>{'id': 'a', 'label': 'A'},
          <String, dynamic>{'id': 'b', 'label': 'B'},
          <String, dynamic>{'id': 'c', 'label': 'C'},
          <String, dynamic>{'id': 'd', 'label': 'D'},
        ],
        'edges': <dynamic>[],
        'height': 300,
      });

      expect(tester.takeException(), isNull,
          reason: 'unconnected nodes have no force to place them; stacking '
              'them all at the centre hides every one but the last');
      expect(find.byType(CustomPaint), findsWidgets);
    });

    // The edge line and the arrowhead are both painted in the edge colour,
    // the line at partial opacity — so a tolerance wide enough to hold both.
    const edgeRed = Color(0xFFFF4040);
    const nodeGreen = Color(0xFF00AA00);

    /// How many horizontal bands hold pixels of [colour] — one band per row
    /// of nodes. Labels are painted, not `Text` widgets, so this is the only
    /// way to ask where the layout put things.
    int bands(Painted p, Color colour) {
      var count = 0;
      var inBand = false;
      for (var y = 0; y < p.height; y++) {
        var hit = false;
        for (var x = 0; x < p.width && !hit; x++) {
          final c = p.at(x, y);
          hit = c.a >= 0.5 &&
              (c.r * 255 - colour.r * 255).abs() <= 40 &&
              (c.g * 255 - colour.g * 255).abs() <= 40 &&
              (c.b * 255 - colour.b * 255).abs() <= 40;
        }
        if (hit && !inBand) count++;
        inBand = hit;
      }
      return count;
    }

    Map<String, dynamic> pair({
      bool? graphDirected,
      bool? edgeDirected,
    }) =>
        <String, dynamic>{
          'type': 'networkGraph',
          'nodes': <dynamic>[
            <String, dynamic>{'id': 'a', 'label': 'A', 'x': 60, 'y': 100},
            <String, dynamic>{'id': 'b', 'label': 'B', 'x': 240, 'y': 100},
          ],
          'edges': <dynamic>[
            <String, dynamic>{
              'source': 'a',
              'target': 'b',
              if (edgeDirected != null) 'directed': edgeDirected,
            },
          ],
          if (graphDirected != null) 'directed': graphDirected,
          'edgeColor': '#FF0000',
          'backgroundColor': '#FFFFFF',
          'width': 320,
          'height': 200,
        };

    testWidgets('an edge marked directed paints more than a plain line',
        (tester) async {
      final plain = (await painted(tester, pair())).count(edgeRed,
          tolerance: 70);
      final arrowed = (await painted(tester, pair(edgeDirected: true)))
          .count(edgeRed, tolerance: 70);

      expect(arrowed, greaterThan(plain),
          reason: 'the arrowhead is a filled triangle in the edge colour; if '
              'nothing extra reached the canvas the direction was never drawn');
    });

    testWidgets('`directed` on the graph reaches every edge', (tester) async {
      final plain =
          (await painted(tester, pair())).count(edgeRed, tolerance: 70);
      final arrowed = (await painted(tester, pair(graphDirected: true)))
          .count(edgeRed, tolerance: 70);

      expect(arrowed, greaterThan(plain),
          reason: "§10.13's own example puts `directed` on the graph; reading "
              'only the per-edge spelling drew a dependency graph that shows '
              'what is connected but never which way it points');
    });

    testWidgets('an edge can refuse the graph-wide default', (tester) async {
      final all = (await painted(tester, pair(graphDirected: true)))
          .count(edgeRed, tolerance: 70);
      final opted = (await painted(
              tester, pair(graphDirected: true, edgeDirected: false)))
          .count(edgeRed, tolerance: 70);

      expect(opted, lessThan(all),
          reason: 'the per-edge value is the more specific statement and has '
              'to win, or a mixed graph cannot be drawn at all');
    });

    testWidgets('`layout: grid` puts the nodes on rows, not on a circle',
        (tester) async {
      Map<String, dynamic> six(String layout) => <String, dynamic>{
            'type': 'networkGraph',
            'layout': layout,
            'nodes': <dynamic>[
              for (var i = 0; i < 6; i++)
                <String, dynamic>{'id': 'n$i', 'label': ''},
            ],
            'nodeColor': '#00AA00',
            'backgroundColor': '#FFFFFF',
            'width': 400,
            'height': 400,
          };

      final grid = bands(await painted(tester, six('grid')), nodeGreen);
      final circle = bands(await painted(tester, six('circular')), nodeGreen);

      // Six nodes make a 3-column grid: two rows, so two bands.
      expect(grid, 2,
          reason: 'a grid is rows of equal height; naming the layout and '
              'drawing a circle means the word was read and thrown away');
      expect(circle, greaterThan(grid));
    });

    testWidgets('a pinch scales what is drawn', (tester) async {
      final definition = <String, dynamic>{
        'type': 'networkGraph',
        'nodes': <dynamic>[
          <String, dynamic>{'id': 'a', 'label': 'A', 'x': 120, 'y': 100},
          <String, dynamic>{'id': 'b', 'label': 'B', 'x': 200, 'y': 100},
        ],
        'nodeColor': '#00AA00',
        'backgroundColor': '#FFFFFF',
        'width': 320,
        'height': 200,
      };

      final before = await painted(tester, definition);
      final beforeNodes = before.count(nodeGreen, tolerance: 40);

      // The graph sits centred on the screen, so the pinch has to land on it.
      final centre = tester.getCenter(find.byType(CustomPaint).first);
      final left = await tester.startGesture(centre - const Offset(30, 0));
      final right = await tester.startGesture(centre + const Offset(30, 0));
      await tester.pump();
      await left.moveBy(const Offset(-60, 0));
      await right.moveBy(const Offset(60, 0));
      await tester.pump();
      await left.up();
      await right.up();
      await tester.pumpAndSettle();

      late Painted after;
      await tester.runAsync(() async {
        after = await paintedOf(
            tester, find.byKey(const ValueKey('painted-probe')));
      });

      expect(after.count(nodeGreen, tolerance: 40), greaterThan(beforeNodes),
          reason: 'a graph that cannot be zoomed is unreadable the moment it '
              'holds more nodes than fit on screen');
    });
  });
}
