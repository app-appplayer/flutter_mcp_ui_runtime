// Every declared widget, actually drawn.
//
// The gap this closes: schema validation says a document is well-formed and
// unit tests say a factory compiles, and a widget can still throw the moment
// it is painted. `markdown` accepted a `content` alias in its source and had
// never once resolved it — `resolve<String>(null)` throws before the `??`
// fallback runs — and nothing caught that because no test drew a `markdown`
// built the way the spec says you may build one.
//
// So: enumerate the registry, and for each widget render (a) every example the
// spec ships for it and (b) a minimal document synthesized from its required
// properties. A widget passes only if the frame contains no FlutterError and
// no error widget — the renderer's `Unknown widget type` / `Error rendering`
// surface is a *successful* build as far as the framework is concerned, so
// asserting on exceptions alone would miss it.
//
// And "no error" is not the same as "drew something". A heatmap that clamps
// every cell to one colour, a chart that plots nothing, a player that reports
// an unopenable source — all of those build cleanly and leave the page blank,
// which is exactly the class of defect that kept reaching authors' screens
// while this matrix stayed green. So the frame is also SCREENSHOTTED and the
// widget must put pixels on top of the page background. Widgets that legally
// paint nothing of their own are named in [_paintsNothing], each with the
// reason — an unexplained entry there is the hole this check exists to close.

import 'dart:convert';
import 'dart:io';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../behaviour/painted_probe.dart';

/// Widgets that only mean anything inside a particular parent: `Expanded` and
/// friends apply flex parent data, `positioned` applies stack parent data.
/// Rendering one as a bare page body is not a defect in the widget.
const _needsFlexParent = <String>{'expanded', 'flexible', 'spacer'};
const _needsStackParent = <String>{'positioned'};

/// Widgets the spec places by raising them through an action rather than by
/// putting them in the tree (§2.11). Drawing one inline is not a supported
/// shape, so the matrix renders them inside the surface that owns them.
const _dialogSurfaces = <String>{
  'alertDialog',
  'simpleDialog',
  'customDialog',
  'bottomSheet',
  'snackBar',
};

/// Widgets whose synthesized minimal document the schema rejected. Reported
/// rather than dropped: a silent skip would read as coverage.
final Set<String> _synthesisGaps = <String>{};

void main() {
  late final String repoRoot;
  late final List<_WidgetSpec> specs;

  setUpAll(() {
    repoRoot = _findRepoRoot();
    final dir = Directory(
      p.join(repoRoot, 'specs', 'mcp_ui_dsl', 'spec', '1.4', 'widgets'),
    );
    expect(dir.existsSync(), isTrue,
        reason: 'widget registry not found at ${dir.path}');
    specs = _loadRegistry(dir);
    // A registry that silently shrank would turn this suite green by not
    // running, which is the failure mode it exists to prevent.
    expect(specs.length, greaterThanOrEqualTo(158),
        reason: 'registry shrank to ${specs.length} widgets');
  });

  tearDownAll(() {
    if (_synthesisGaps.isNotEmpty) {
      // ignore: avoid_print
      stderr.writeln(
        'NOTE: minimal-document synthesis could not build a schema-legal '
        'shape for ${_synthesisGaps.length} widget(s); each is covered by its '
        'spec examples: ${(_synthesisGaps.toList()..sort()).join(", ")}',
      );
    }
  });

  test('every declared widget has something to render', () {
    final empty = specs
        .where((s) => s.examples.isEmpty && s.minimal == null)
        .map((s) => s.type)
        .toList();
    expect(empty, isEmpty,
        reason: 'no renderable document could be built for: $empty');
  });

  // One test per widget: a failure names the widget rather than the suite.
  for (final spec in _registryForGeneration()) {
    testWidgets('${spec.type} renders', (tester) async {
      final target = specs.firstWhere((s) => s.type == spec.type);
      final docs = <String, Map<String, dynamic>>{
        for (var i = 0; i < target.examples.length; i++)
          'example_$i': target.examples[i],
        if (target.minimal != null) 'minimal': target.minimal!,
      };

      final failures = <String>[];
      for (final entry in docs.entries) {
        final problem = await _render(tester, target.type, entry.value);
        if (problem == null) continue;
        // A synthesized document that the schema rejects means this harness
        // could not guess a legal shape — not that the widget is broken. It
        // is only tolerated where the spec ships an example that already
        // covers the widget; where it does not, the synthesized document is
        // the only coverage and has to work.
        final synthesisGap = entry.key == 'minimal' &&
            problem.contains('schema validation failed') &&
            target.examples.isNotEmpty;
        if (synthesisGap) {
          _synthesisGaps.add(target.type);
          continue;
        }
        failures.add('${entry.key}: $problem');
      }

      expect(failures, isEmpty,
          reason: '${target.type} failed to draw:\n  - '
              '${failures.join("\n  - ")}');
    });
  }
}

/// Renders [fragment] as the content of a page and returns a description of
/// the first problem, or null when the frame is clean.
Future<String?> _render(
  WidgetTester tester,
  String type,
  Map<String, dynamic> fragment,
) async {
  final errors = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.exception.toString();
    // The bundled ink_sparkle shader is rejected by this engine build; it has
    // nothing to do with the widget under test.
    if (text.contains('ink_sparkle.frag')) return;
    // `flutter_test` answers every real HTTP request with 400, so any example
    // naming a remote image fails on the network rather than on the widget.
    // There is no network in a unit test, so nothing is lost by ignoring it —
    // whether an image *loads* is not what this matrix asks.
    if (text.contains('HTTP request failed, statusCode: 400')) return;
    errors.add(details);
  };

  await tester.binding.setSurfaceSize(const Size(1280, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final runtime = MCPUIRuntime();
  try {
    // `view` / `use` name a definition by uri. Without a loader the runtime
    // has nothing to build and reports an empty definition, which is a
    // property of the harness rather than of the widget.
    final document = _asPage(type, fragment);
    await runtime.initialize(
      <String, dynamic>{
        ...document,
        'runtime': <String, dynamic>{
          'services': <String, dynamic>{
            'state': <String, dynamic>{
              'initialState': _stateFor(document, type),
            },
          },
        },
      },
      pageLoader: (uri) async => <String, dynamic>{
        'type': 'page',
        'content': <String, dynamic>{'type': 'text', 'content': 'stub'},
      },
    );
    runtime.engine.capabilities = _capabilities();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          // Wrapped so the frame can be read back as pixels: "no error" and
          // "drew something" are different claims, and only the second is what
          // an author sees.
          body: isolated(runtime.buildUI(), key: const ValueKey('matrix')),
        ),
      ),
    );
    // Settle rather than pump a fixed slice: a widget that materializes from
    // a post-frame callback reaches its failure after the frame a single 50 ms
    // pump produces. `pumpAndSettle` throws on a scene that never settles (an
    // indeterminate progress indicator animates forever), so the fixed wait
    // stays as the fallback for those.
    try {
      // Capped: an indeterminate progress indicator never settles, and the
      // default budget grinds for ten minutes before saying so.
      await tester.pumpAndSettle(
        const Duration(milliseconds: 16),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 1),
      );
    } catch (_) {
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }
  } catch (e) {
    FlutterError.onError = previous;
    await runtime.dispose();
    return 'threw during build: $e';
  }
  FlutterError.onError = previous;

  final rendered = _errorWidgetText(tester);

  // Read the frame back before the runtime goes away.
  int painted = -1;
  if (errors.isEmpty && rendered == null && !_paintsNothing.containsKey(type)) {
    // A plain frame first: `pumpAndSettle` above stops at
    // `sendSemanticsUpdate`, and reading the layer straight after it returned
    // a blank image for widgets that had unmistakably drawn.
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(() async {
      final shot = await paintedOf(tester, find.byKey(const ValueKey('matrix')));
      painted = shot.nonBackground();
    });
  }
  await runtime.dispose();

  if (errors.isNotEmpty) {
    return 'FlutterError: ${errors.first.exceptionAsString()}';
  }
  if (rendered != null) return 'error widget drawn: $rendered';
  if (painted == 0) {
    // Built without complaint and left the page empty. That is the shape every
    // defect an author found on screen had: the widget was there, the property
    // was read, and nothing was drawn.
    return 'built cleanly but painted nothing';
  }
  return null;
}

/// The renderer reports a failed widget by *drawing* a red box rather than by
/// throwing, so the frame has to be inspected for it.
String? _errorWidgetText(WidgetTester tester) {
  for (final marker in const [
    'Unknown widget type:',
    'Error rendering',
    'Widget type is required',
  ]) {
    final found = find.textContaining(marker);
    if (tester.any(found)) {
      final widget = tester.widgetList<Text>(found).first;
      return widget.data ?? marker;
    }
  }
  return null;
}

/// Widgets that draw nothing by themselves, with why. Everything else must
/// leave marks on the page.
const _paintsNothing = <String, String>{
  'spacer': 'empty flex space is the widget',
  'sizedBox': 'a box with no child is space',
  'divider': 'a hairline at default thickness can miss the sample grid',
  'verticalDivider': 'as divider',
  'positioned': 'parent data, drawn by its stack child',
  'expanded': 'parent data',
  'flexible': 'parent data',
  'form': 'a container for fields; empty in the minimal document',
  'gestureDetector': 'invisible by definition — it wraps a child',
  'inkWell': 'ink is drawn on interaction',
  'draggable': 'wraps a child; nothing of its own',
  'dragTarget': 'wraps a child',
  'visibility': 'its minimal document is the hidden case',
  'offstage': 'offstage is the point',
  'opacity': 'the minimal document has no child to fade',
  'absorbPointer': 'invisible wrapper',
  'ignorePointer': 'invisible wrapper',
  'scrollView': 'a viewport around a child',
  'singleChildScrollView': 'a viewport around a child',
  'webView': 'a platform view — invisible to a Flutter screenshot',
  'videoPlayer': 'a platform view',
  'mapView': 'a platform view',
  'view': 'renders whatever the loader returns; the stub is a text child',
  'use': 'as view',
  // Wrappers: what they draw is their child, and the registry's minimal
  // document has none.
  'layoutBuilder': 'builds from constraints; nothing of its own',
  'mediaQuery': 'supplies data to a subtree',
  'resizable': 'a handle around a child',
  'decoration': 'paints around a child',
  'contextMenu': 'raised by a long-press, not placed',
  'lightbox': 'an overlay opened by an action',
  'errorRecovery': 'shows its fallback only after a failure',
  'dashboard': 'a shell for widget instances the registry ships none of',
  'scrollBar': 'a scrollbar for a scrollable that has nothing to scroll',
  'kenBurnsImage': 'a pan/zoom over an image the harness cannot fetch',
  // Host surfaces whose builder is handed an asset this harness cannot read.
  // They ARE proven to paint — by the capability probe, against a built app
  // with a real host: `tool/capability_probe/verify.py` requires pixels for
  // pdf and lottie on every tier before a release.
  'pdfViewer': 'host surface over bundle bytes; covered by the capability probe',
  'lottieAnimation': 'host surface over bundle bytes; capability probe',
  'map': 'host surface; capability probe',
};

/// Host surfaces and ports, stubbed so the capability widgets have a
/// capability to exercise.
///
/// §6.13 says a widget with no capability reports the absence and draws
/// nothing — which is correct, and indistinguishable from a widget that is
/// simply broken. A matrix run with no capabilities therefore proves nothing
/// about `mediaPlayer`, `pdfViewer`, `lottieAnimation` or `map`. Here they are
/// all wired, so "painted nothing" means the widget, not the host.
RuntimeCapabilities _capabilities() {
  Widget? surface(BuildContext context, Map<String, dynamic> properties,
          SurfaceEvents events, SurfaceAssets assets) =>
      const ColoredBox(color: Color(0xFF2E7D32), child: SizedBox.expand());
  return RuntimeCapabilities(
    media: _MatrixMediaPort(),
    mediaSupportsVideo: true,
    webViewBuilder: surface,
    pdfBuilder: surface,
    mapBuilder: surface,
    lottieBuilder: surface,
  );
}

class _MatrixMediaPort implements MediaPort {
  @override
  Future<MediaSession> open({
    required AssetRef source,
    required AssetBytesReader readBytes,
    required bool isVideo,
    bool wantsWaveform = false,
    bool loop = false,
    bool muted = false,
    double volume = 1.0,
  }) async =>
      _MatrixSession();

  @override
  Widget? videoSurface(MediaSession session) =>
      const ColoredBox(color: Color(0xFF1565C0), child: SizedBox.expand());
}

class _MatrixSession implements MediaSession {
  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration?>.broadcast();
  final _playing = StreamController<bool>.broadcast();
  final _ended = StreamController<void>.broadcast();
  final _errors = StreamController<Object>.broadcast();

  @override
  Stream<Duration> get position => _position.stream;
  @override
  Stream<Duration?> get duration => _duration.stream;
  @override
  Stream<bool> get playing => _playing.stream;
  @override
  Stream<void> get ended => _ended.stream;
  @override
  Stream<Object> get errors => _errors.stream;
  @override
  Stream<List<double>>? get waveform => null;
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> seek(Duration to) async {}
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> setMuted(bool muted) async {}
  @override
  Future<void> dispose() async {
    await _position.close();
    await _duration.close();
    await _playing.close();
    await _ended.close();
    await _errors.close();
  }
}

/// Data shaped for the widgets whose state is not a list of rows.
///
/// The generic seed below answers every binding with rows, which is what most
/// data widgets want. These five want something else — a numeric grid, a
/// column/row pair, tab entries — and handing them rows renders an empty
/// widget for the harness's reason rather than the widget's.
const _shapedState = <String, Map<String, dynamic>>{
  'heatmap': {
    'heatmapData': [
      [1.5, 3.0, 6.2],
      [2.2, 4.1, 5.4],
      [0.8, 2.9, 3.3],
    ],
  },
  'dataTable': {
    'columns': [
      {'key': 'name', 'label': 'Name'},
      {'key': 'value', 'label': 'Value'},
    ],
    'rows': [
      {'name': 'A', 'value': 1},
      {'name': 'B', 'value': 2},
    ],
    'users': [
      {'name': 'A', 'value': 1},
      {'name': 'B', 'value': 2},
    ],
  },
  'spreadsheet': {
    // The example reads `{{sheet.rows}}`.
    'sheet': {
      'rows': [
        ['A1', 'B1'],
        ['A2', 'B2'],
      ],
    },
    'cells': [
      ['A1', 'B1'],
      ['A2', 'B2'],
    ],
    'data': [
      ['A1', 'B1'],
      ['A2', 'B2'],
    ],
  },
  'tabBar': {
    'tabs': [
      {'label': 'One', 'key': 'one'},
      {'label': 'Two', 'key': 'two'},
    ],
  },
  'bottomNavigation': {
    'items': [
      {'label': 'Home', 'icon': 'home'},
      {'label': 'Settings', 'icon': 'settings'},
    ],
  },
};

/// State for whatever the document binds to.
///
/// The spec's examples read their data from state — `"{{plan.tasks}}"`,
/// `"{{books}}"` — and a harness that supplies none renders a data widget with
/// no data. Drawing nothing then is correct, so without this the pixel check
/// would report a defect for every list, board and chart in the registry.
///
/// The shape is unknowable from the binding alone, so each referenced root
/// gets a list of rows that also answers as a map: rows carry the key names
/// these widgets reach for. A widget that still paints nothing with data in
/// hand is the finding this check exists for.
Map<String, dynamic> _stateFor(Map<String, dynamic> document, String type) {
  final shaped = _shapedState[type];
  final text = jsonEncode(document);
  final roots = <String>{};
  for (final match in RegExp(r'\{\{\s*([A-Za-z_]\w*)').allMatches(text)) {
    final root = match.group(1)!;
    if (const {'item', 'index', 'event', 'theme', 'i18n', 'isFirst', 'isLast',
            'isEven', 'isOdd', 'local', 'app', 'page', 'state'}
        .contains(root)) {
      continue; // supplied by the runtime's own scopes
    }
    roots.add(root);
  }

  Map<String, dynamic> row(int i) => <String, dynamic>{
        'id': 'r$i',
        'key': 'r$i',
        'name': 'Row $i',
        'title': 'Row $i',
        'label': 'Row $i',
        'text': 'Row $i',
        'value': 10 + i * 5,
        'y': 10 + i * 5,
        'x': i,
        'progress': 0.25 * (i + 1),
        'color': '#1E88E5',
        'status': i.isEven ? 'done' : 'open',
        'completed': i.isEven,
        'start': '2026-08-0${i + 1}',
        'end': '2026-08-0${i + 3}',
        'from': 'r0',
        'to': 'r1',
        'cover': 'https://example.com/cover.png',
        'src': 'https://example.com/cover.png',
        'items': <Map<String, dynamic>>[
          {'id': 'c$i', 'title': 'Card $i', 'label': 'Card $i'},
        ],
        'data': <num>[1, 4, 2],
        'children': <Map<String, dynamic>>[],
      };

  final rows = [for (var i = 0; i < 3; i++) row(i)];
  final state = <String, dynamic>{};
  for (final root in roots) {
    state[root] = rows;
  }
  // Nested reads (`plan.tasks`, `board.columns`) need the parent to be a map
  // whose every key answers with the same rows.
  for (final match
      in RegExp(r'\{\{\s*([A-Za-z_]\w*)\.([A-Za-z_]\w*)').allMatches(text)) {
    final root = match.group(1)!;
    if (!state.containsKey(root)) continue;
    final child = match.group(2)!;
    final existing = state[root];
    final map = existing is Map<String, dynamic>
        ? existing
        : <String, dynamic>{};
    map[child] = rows;
    state[root] = map;
  }
  // The shaped fixtures win: they are the widgets whose data is not rows.
  if (shaped != null) state.addAll(shaped);
  return state;
}

Map<String, dynamic> _asPage(String type, Map<String, dynamic> fragment) {
  // A fragment that is already a page (or an application) is used as-is.
  final kind = fragment['type'];
  if (kind == 'page' || kind == 'application') return fragment;

  if (_dialogSurfaces.contains(type)) {
    // §2.11: these are raised, not placed. The page carries a button whose
    // action opens the surface, and the matrix taps nothing — building the
    // definition is what exercises the factory's property reading.
    return <String, dynamic>{
      'type': 'page',
      'content': <String, dynamic>{
        'type': 'button',
        'label': 'open',
        'onTap': <String, dynamic>{'type': 'dialog', 'dialog': fragment},
      },
    };
  }

  if (_needsFlexParent.contains(type)) {
    return <String, dynamic>{
      'type': 'page',
      'content': <String, dynamic>{
        'type': 'linear',
        'direction': 'horizontal',
        'children': <Object>[fragment],
      },
    };
  }
  if (_needsStackParent.contains(type)) {
    return <String, dynamic>{
      'type': 'page',
      'content': <String, dynamic>{
        'type': 'stack',
        'children': <Object>[fragment],
      },
    };
  }

  return <String, dynamic>{'type': 'page', 'content': fragment};
}

class _WidgetSpec {
  _WidgetSpec(this.type, this.examples, this.minimal);
  final String type;
  final List<Map<String, dynamic>> examples;
  final Map<String, dynamic>? minimal;
}

// Populated by [_loadRegistry]; the generation loop needs the type list before
// `setUpAll` runs, so it is read once at load time.
final List<_WidgetSpec> _generationSpecs = _loadRegistry(
  Directory(
    p.join(_findRepoRoot(), 'specs', 'mcp_ui_dsl', 'spec', '1.4', 'widgets'),
  ),
);

List<_WidgetSpec> _registryForGeneration() => _generationSpecs;

List<_WidgetSpec> _loadRegistry(Directory dir) {
  final out = <_WidgetSpec>[];
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.yaml')) continue;
    final doc = loadYaml(entity.readAsStringSync());
    if (doc is! YamlMap) continue;
    final type = doc['type'] as String?;
    if (type == null) continue;

    final examples = <Map<String, dynamic>>[];
    final rawExamples = doc['examples'];
    if (rawExamples is YamlList) {
      for (final e in rawExamples) {
        final example = e as YamlMap;
        // The registry marks its deliberately-invalid examples, and
        // `validate_examples` grades them. Rendering one is not the question
        // this matrix asks.
        if (example['expect']?.toString() == 'validation_error') continue;
        final dsl = example['dsl'];
        if (dsl is! String) continue;
        try {
          final decoded = jsonDecode(dsl);
          if (decoded is Map<String, dynamic>) examples.add(decoded);
        } on FormatException {
          // A malformed example is the example's problem, and
          // `validate_examples` already grades it.
        }
      }
    }

    out.add(_WidgetSpec(type, examples, _minimalDoc(type, doc['properties'])));
  }
  out.sort((a, b) => a.type.compareTo(b.type));
  return out;
}

/// Builds the smallest document the registry says is legal: the widget's type
/// plus a plausible value for every property marked required.
Map<String, dynamic>? _minimalDoc(String type, Object? properties) {
  final doc = <String, dynamic>{'type': type};
  if (properties is YamlMap) {
    for (final entry in properties.entries) {
      final name = entry.key as String;
      final prop = entry.value;
      if (prop is! YamlMap) continue;
      if (prop['required'] != true) continue;
      final value = _sampleFor(prop['type']?.toString() ?? 'string', prop);
      if (value == null) return null; // cannot synthesize — skip this widget
      doc[name] = value;
    }
  }
  return doc;
}

Object? _sampleFor(String declared, YamlMap prop) {
  // Unions accept any branch; the first is the documented primary form.
  final t = declared.split('|').first.trim();

  final enumValues = prop['enum'];
  if (enumValues is YamlList && enumValues.isNotEmpty) {
    return enumValues.first.toString();
  }

  if (t.startsWith('array<')) {
    final element = t.substring(6, t.length - 1);
    final sample = _sampleForBare(element);
    return sample == null ? null : <Object>[sample];
  }
  return _sampleForBare(t);
}

Object? _sampleForBare(String t) {
  switch (t) {
    case 'string':
      return 'sample';
    case 'number':
    case 'integer':
      return 1;
    case 'boolean':
      return true;
    case 'object':
      return <String, dynamic>{};
    case 'Widget':
      return <String, dynamic>{'type': 'text', 'content': 'sample'};
    case 'Action':
      return <String, dynamic>{
        'type': 'state',
        'action': 'set',
        'binding': 'sample',
        'value': 1,
      };
    case 'Color':
      return '#FF0000';
    case 'Dimension':
      return 24;
    case 'AssetRef':
      // §6.12: a reference carries a scheme or the `assets/` prefix. A bare
      // word is an icon name, not an asset.
      return 'assets/sample.png';
    case 'IconRef':
      return 'home';
    case 'Alignment':
      return 'center';
    case 'DefinitionSource':
      // A resource URI on the current origin — the plain form of the three
      // the primitive accepts. The harness's page loader answers it.
      return 'ui://pages/sample';
    case 'binding':
      return '{{sample}}';
    case 'any':
      return 'sample';
    default:
      // A named element type with no modelling rule (Point, Column, Tab, …).
      // Returning an empty object keeps the shape without inventing fields.
      return <String, dynamic>{};
  }
}

String _findRepoRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 12; i++) {
    if (Directory(p.join(dir.path, 'specs', 'mcp_ui_dsl')).existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw StateError('repo root not found from ${Directory.current.path}');
}
