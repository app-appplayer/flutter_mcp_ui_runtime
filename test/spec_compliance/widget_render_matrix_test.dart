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

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

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
    await runtime.initialize(
      _asPage(type, fragment),
      pageLoader: (uri) async => <String, dynamic>{
        'type': 'page',
        'content': <String, dynamic>{'type': 'text', 'content': 'stub'},
      },
    );
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: runtime.buildUI())),
    );
    await tester.pump(const Duration(milliseconds: 50));
  } catch (e) {
    FlutterError.onError = previous;
    await runtime.dispose();
    return 'threw during build: $e';
  }
  FlutterError.onError = previous;

  final rendered = _errorWidgetText(tester);
  await runtime.dispose();

  if (errors.isNotEmpty) {
    return 'FlutterError: ${errors.first.exceptionAsString()}';
  }
  if (rendered != null) return 'error widget drawn: $rendered';
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
