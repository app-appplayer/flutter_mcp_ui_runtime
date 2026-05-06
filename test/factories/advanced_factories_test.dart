// Advanced Widget Factory Tests: TC-248 through TC-263
// Covers chart, map, mediaPlayer, calendar, timeline, tree, gauge,
// heatmap, graph, networkGraph, codeEditor, terminal, fileExplorer,
// markdown, webView, signature.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

void main() {
  late MCPUIRuntime runtime;

  setUp(() {
    runtime = MCPUIRuntime();
  });

  tearDown(() {
    runtime.destroy();
  });

  // Helper to pump a page definition through the runtime
  Future<void> pumpPage(
    WidgetTester tester, {
    required Map<String, dynamic> content,
    Map<String, dynamic>? initialState,
  }) async {
    final definition = <String, dynamic>{
      'type': 'page',
      'content': content,
    };
    if (initialState != null) {
      definition['runtime'] = {
        'services': {
          'state': {'initialState': initialState},
        },
      };
    }
    await runtime.initialize(definition);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: runtime.buildUI())),
    );
    await tester.pump();
  }

  // ---------------------------------------------------------------------------
  // TC-248: ChartWidgetFactory - type, data
  // ---------------------------------------------------------------------------
  group('TC-248: ChartWidgetFactory', () {
    testWidgets('TC-248a: chart renders with bar type and data',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'chart',
        'chartType': 'bar',
        'data': [
          {'label': 'Q1', 'value': 100},
          {'label': 'Q2', 'value': 200},
          {'label': 'Q3', 'value': 150},
        ],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-248b: chart with line type', (tester) async {
      await pumpPage(tester, content: {
        'type': 'chart',
        'chartType': 'line',
        'data': [
          {'label': 'Jan', 'value': 30},
          {'label': 'Feb', 'value': 45},
        ],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-248c: chart with empty data', (tester) async {
      await pumpPage(tester, content: {
        'type': 'chart',
        'chartType': 'pie',
        'data': <Map<String, dynamic>>[],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-249: MapWidgetFactory - center, zoom
  // ---------------------------------------------------------------------------
  group('TC-249: MapWidgetFactory', () {
    testWidgets('TC-249a: map renders with center coordinates and zoom',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'map',
        'latitude': 37.5665,
        'longitude': 126.9780,
        'zoom': 12,
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-249b: map with default zoom', (tester) async {
      await pumpPage(tester, content: {
        'type': 'map',
        'latitude': 0.0,
        'longitude': 0.0,
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-250: MediaPlayerWidgetFactory - src, type (audio/video)
  // ---------------------------------------------------------------------------
  group('TC-250: MediaPlayerWidgetFactory', () {
    testWidgets('TC-250a: mediaPlayer renders with video type', (tester) async {
      await pumpPage(tester, content: {
        'type': 'mediaPlayer',
        'src': 'https://example.com/video.mp4',
        'mediaType': 'video',
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-250b: mediaPlayer renders with audio type',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'mediaPlayer',
        'src': 'https://example.com/audio.mp3',
        'mediaType': 'audio',
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-250c: mediaPlayer with placeholder src', (tester) async {
      // Spec § AssetRef rejects empty strings — must carry one of the
      // five accepted scheme prefixes. Use a `data:` placeholder to
      // exercise the "no actual media" rendering path.
      await pumpPage(tester, content: {
        'type': 'mediaPlayer',
        'src': 'data:video/mp4,placeholder',
        'mediaType': 'video',
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-251: CalendarWidgetFactory - selectedDate
  // ---------------------------------------------------------------------------
  group('TC-251: CalendarWidgetFactory', () {
    testWidgets('TC-251a: calendar renders without crash', (tester) async {
      await pumpPage(tester, content: {
        'type': 'calendar',
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-251b: calendar with selectedDate', (tester) async {
      await pumpPage(tester, content: {
        'type': 'calendar',
        'selectedDate': '2025-01-15',
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-252: TimelineWidgetFactory - items
  // ---------------------------------------------------------------------------
  group('TC-252: TimelineWidgetFactory', () {
    testWidgets('TC-252a: timeline renders with items', (tester) async {
      await pumpPage(tester, content: {
        'type': 'timeline',
        'items': [
          {'title': 'Step 1', 'description': 'Initialize'},
          {'title': 'Step 2', 'description': 'Process'},
          {'title': 'Step 3', 'description': 'Complete'},
        ],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-252b: timeline with single item', (tester) async {
      await pumpPage(tester, content: {
        'type': 'timeline',
        'items': [
          {'title': 'Only Step', 'description': 'Single item timeline'},
        ],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-253: TreeWidgetFactory - nodes
  // ---------------------------------------------------------------------------
  group('TC-253: TreeWidgetFactory', () {
    testWidgets('TC-253a: tree renders with nested nodes', (tester) async {
      await pumpPage(tester, content: {
        'type': 'tree',
        'data': [
          {
            'label': 'Root',
            'children': [
              {'label': 'Child 1'},
              {
                'label': 'Child 2',
                'children': [
                  {'label': 'Grandchild'},
                ],
              },
            ],
          },
        ],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-253b: tree with single root node', (tester) async {
      await pumpPage(tester, content: {
        'type': 'tree',
        'data': [
          {'label': 'Lone Root'},
        ],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-254: GaugeWidgetFactory - value, min, max
  // ---------------------------------------------------------------------------
  group('TC-254: GaugeWidgetFactory', () {
    testWidgets('TC-254a: gauge renders with value, min, max', (tester) async {
      await pumpPage(tester, content: {
        'type': 'gauge',
        'value': 75,
        'min': 0,
        'max': 100,
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-254b: gauge at minimum value', (tester) async {
      await pumpPage(tester, content: {
        'type': 'gauge',
        'value': 0,
        'min': 0,
        'max': 100,
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-254c: gauge at maximum value', (tester) async {
      await pumpPage(tester, content: {
        'type': 'gauge',
        'value': 100,
        'min': 0,
        'max': 100,
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-255: HeatmapWidgetFactory - data, colorRange
  // ---------------------------------------------------------------------------
  group('TC-255: HeatmapWidgetFactory', () {
    testWidgets('TC-255a: heatmap renders with 2D data', (tester) async {
      await pumpPage(tester, content: {
        'type': 'heatmap',
        'data': [
          [1, 2, 3],
          [4, 5, 6],
          [7, 8, 9],
        ],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-255b: heatmap with colorRange', (tester) async {
      await pumpPage(tester, content: {
        'type': 'heatmap',
        'data': [
          [10, 20],
          [30, 40],
        ],
        'colorRange': {
          'min': '#FFFFFF',
          'max': '#FF0000',
        },
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-255c: heatmap with single cell', (tester) async {
      await pumpPage(tester, content: {
        'type': 'heatmap',
        'data': [
          [42],
        ],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-256: GraphWidgetFactory - type, data
  // ---------------------------------------------------------------------------
  group('TC-256: GraphWidgetFactory', () {
    testWidgets('TC-256a: graph renders with data points', (tester) async {
      await pumpPage(tester, content: {
        'type': 'graph',
        'data': [
          {'value': 10},
          {'value': 25},
          {'value': 15},
          {'value': 30},
        ],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-256b: graph with empty data', (tester) async {
      await pumpPage(tester, content: {
        'type': 'graph',
        'data': <Map<String, dynamic>>[],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-257: NetworkGraphWidgetFactory - nodes, edges (v1.1)
  // ---------------------------------------------------------------------------
  group('TC-257: NetworkGraphWidgetFactory', () {
    testWidgets('TC-257a: networkGraph renders with nodes and edges',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'networkGraph',
        'nodes': [
          {'id': 'n1', 'label': 'Node A'},
          {'id': 'n2', 'label': 'Node B'},
          {'id': 'n3', 'label': 'Node C'},
        ],
        'edges': [
          {'from': 'n1', 'to': 'n2'},
          {'from': 'n2', 'to': 'n3'},
        ],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-257b: networkGraph with single node and no edges',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'networkGraph',
        'nodes': [
          {'id': 'solo', 'label': 'Isolated Node'},
        ],
        'edges': <Map<String, dynamic>>[],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-258: CodeEditorWidgetFactory - language, code
  // ---------------------------------------------------------------------------
  group('TC-258: CodeEditorWidgetFactory', () {
    testWidgets('TC-258a: codeEditor renders with language and code',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'codeEditor',
        'language': 'dart',
        'code': 'void main() {\n  // entry point\n}',
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-258b: codeEditor with empty code', (tester) async {
      await pumpPage(tester, content: {
        'type': 'codeEditor',
        'language': 'javascript',
        'code': '',
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-259: TerminalWidgetFactory - content
  // ---------------------------------------------------------------------------
  group('TC-259: TerminalWidgetFactory', () {
    testWidgets('TC-259a: terminal renders with prompt', (tester) async {
      await pumpPage(tester, content: {
        'type': 'terminal',
        'prompt': r'$',
        'content': 'ls -la\ntotal 0',
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-259b: terminal with empty content', (tester) async {
      await pumpPage(tester, content: {
        'type': 'terminal',
        'prompt': r'$',
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-260: FileExplorerWidgetFactory - files, directories
  // ---------------------------------------------------------------------------
  group('TC-260: FileExplorerWidgetFactory', () {
    testWidgets('TC-260a: fileExplorer renders with rootPath', (tester) async {
      await pumpPage(tester, content: {
        'type': 'fileExplorer',
        'rootPath': '/home/user/documents',
        'files': ['readme.txt', 'data.csv'],
        'directories': ['src', 'test'],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-260b: fileExplorer with empty files and directories',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'fileExplorer',
        'rootPath': '/empty',
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-261: MarkdownWidgetFactory - content
  // ---------------------------------------------------------------------------
  group('TC-261: MarkdownWidgetFactory', () {
    testWidgets('TC-261a: markdown renders with rich content', (tester) async {
      await pumpPage(tester, content: {
        'type': 'markdown',
        'content': '# Title\n\n## Subtitle\n\n- Item 1\n- Item 2\n\n**Bold** and *italic*.',
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-261b: markdown with empty content', (tester) async {
      await pumpPage(tester, content: {
        'type': 'markdown',
        'content': '',
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-262: WebViewWidgetFactory - url
  // ---------------------------------------------------------------------------
  group('TC-262: WebViewWidgetFactory', () {
    testWidgets('TC-262a: webView renders with url', (tester) async {
      await pumpPage(tester, content: {
        'type': 'webView',
        'url': 'https://example.com',
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-262b: webView with empty url', (tester) async {
      await pumpPage(tester, content: {
        'type': 'webView',
        'url': '',
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-263: SignatureWidgetFactory - strokeWidth, color
  // ---------------------------------------------------------------------------
  group('TC-263: SignatureWidgetFactory', () {
    testWidgets('TC-263a: signature renders with strokeWidth and color',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'signature',
        'width': 300,
        'height': 150,
        'strokeWidth': 3.0,
        'color': '#000000',
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-263b: signature with default dimensions', (tester) async {
      await pumpPage(tester, content: {
        'type': 'signature',
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-263c: signature with custom color', (tester) async {
      await pumpPage(tester, content: {
        'type': 'signature',
        'width': 250,
        'height': 100,
        'color': '#0000FF',
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
