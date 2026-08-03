// Every branch of every declared union, actually drawn.
//
// The gap this closes: `widget_render_matrix_test` renders the examples the
// spec ships and a document synthesized from required properties. Neither
// reaches an *optional* property, and neither reaches the branches of a union
// the shipped example does not happen to use.
//
// `resizable.width` is typed `number | binding`. The spec's example binds it,
// so that is the only form ever rendered — and the factory read it as
// `properties['width'] as String?`, which throws the moment an author writes
// the number the schema plainly allows. The schema accepted a document the
// runtime crashed on, and every existing check agreed the widget was fine.
//
// So: for each property whose registry type is a union (`A | B`) or a named
// primitive that is itself a union (`IconRef`), render one document per
// branch. A branch passes only if the document validates *and* the frame
// contains no FlutterError and no error widget.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Widgets that only mean anything inside a particular parent.
const _needsFlexParent = <String>{'expanded', 'flexible', 'spacer'};
const _needsStackParent = <String>{'positioned'};

/// §2.11: raised through an action rather than placed in the tree.
const _dialogSurfaces = <String>{
  'alertDialog',
  'simpleDialog',
  'customDialog',
  'bottomSheet',
  'snackBar',
};

/// Branches this harness cannot synthesize a legal value for. Reported at the
/// end rather than skipped silently — an unreported skip reads as coverage.
final Set<String> _unsynthesizable = <String>{};

/// Widgets with neither a usable example nor a synthesizable minimal document,
/// so no branch of theirs is covered here. Reported for the same reason.
final Set<String> _unbased = <String>{};

/// State the binding branch reads. A bound property resolves through this, so
/// the value it lands on is a real one of the branch's own type rather than a
/// null that every factory happens to tolerate.
const _boundState = <String, dynamic>{
  // Small enough to be a legal index as well as a legal size: a bound
  // `selectedIndex` of 120 tests that a widget rejects an out-of-range index,
  // which is a different question from whether the branch is readable.
  'num': 1,
  'str': 'bound',
  'flag': true,
  'list': <dynamic>[],
  'obj': <String, dynamic>{},
};

void main() {
  final cases = _buildCases();

  test('the union axis is not empty', () {
    // A registry read that silently returned nothing would turn this suite
    // green by not running, which is the failure mode it exists to prevent.
    expect(cases.length, greaterThanOrEqualTo(50),
        reason: 'only ${cases.length} union branches were generated');
  });

  tearDownAll(() {
    if (_unbased.isNotEmpty) {
      stderr.writeln(
        'NOTE: no base document for ${_unbased.length} widget(s), so their '
        'union branches are not covered here: '
        '${(_unbased.toList()..sort()).join(", ")}',
      );
    }
    if (_unsynthesizable.isNotEmpty) {
      stderr.writeln(
        'NOTE: no legal value could be synthesized for '
        '${_unsynthesizable.length} branch(es): '
        '${(_unsynthesizable.toList()..sort()).join(", ")}',
      );
    }
  });

  // One test per branch, not per widget. A second `initialize` inside the same
  // `testWidgets` renders an empty tree — every case after the first would
  // report clean because there is nothing in the frame to be wrong. Splitting
  // is what makes the axis real, and it also names the failing branch.
  for (final c in cases) {
    testWidgets('${c.widget}.${c.label} draws', (tester) async {
      final problem = await _render(tester, c);
      expect(problem, isNull, reason: '${c.widget}.${c.label}: $problem');
    });
  }
}

class _Case {
  _Case(this.widget, this.property, this.branch, this.doc);
  final String widget;
  final String property;
  final String branch;
  final Map<String, dynamic> doc;
  String get label => '$property = $branch';
}

/// Renders [c] and returns a description of the first problem, or null.
Future<String?> _render(WidgetTester tester, _Case c) async {
  final errors = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.exception.toString();
    // Engine-build noise and the absence of a network in a unit test are not
    // properties of the widget under test.
    if (text.contains('ink_sparkle.frag')) return;
    if (text.contains('HTTP request failed, statusCode: 400')) return;
    errors.add(details);
  };

  await tester.binding.setSurfaceSize(const Size(1280, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final runtime = MCPUIRuntime();
  try {
    await runtime.initialize(
      _asPage(c.widget, c.doc),
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
  final page = <String, dynamic>{
    'type': 'page',
    'state': <String, dynamic>{'initial': _boundState},
  };

  if (_dialogSurfaces.contains(type)) {
    return page
      ..['content'] = <String, dynamic>{
        'type': 'button',
        'label': 'open',
        'onTap': <String, dynamic>{'type': 'dialog', 'dialog': fragment},
      };
  }
  if (_needsFlexParent.contains(type)) {
    return page
      ..['content'] = <String, dynamic>{
        'type': 'linear',
        'direction': 'horizontal',
        'children': <Object>[fragment],
      };
  }
  if (_needsStackParent.contains(type)) {
    return page
      ..['content'] = <String, dynamic>{
        'type': 'stack',
        'children': <Object>[fragment],
      };
  }
  return page..['content'] = fragment;
}

// ---------------------------------------------------------------------------
// Case generation
// ---------------------------------------------------------------------------

List<_Case> _buildCases() {
  final root = _findRepoRoot();
  final dir = Directory(
    p.join(root, 'specs', 'mcp_ui_dsl', 'spec', '1.4', 'widgets'),
  );
  if (!dir.existsSync()) return const <_Case>[];

  final cases = <_Case>[];
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.yaml')) continue;
    final doc = loadYaml(entity.readAsStringSync());
    if (doc is! YamlMap) continue;
    final type = doc['type'] as String?;
    if (type == null) continue;
    final properties = doc['properties'];
    if (properties is! YamlMap) continue;

    // The base is a document already known to draw — the spec's own example
    // where there is one. Overriding a single property on it isolates the
    // branch as the only variable. Synthesizing from required properties
    // instead drops every widget whose required property is a named type
    // (`array<Option>`, `AssetRef`, …), which silently removed 29 widgets
    // from this axis before the base was taken from the examples.
    final base = _exampleBase(doc) ?? _minimalDoc(type, properties);
    if (base == null) {
      _unbased.add(type);
      continue;
    }

    for (final entry in properties.entries) {
      final name = entry.key as String;
      final prop = entry.value;
      if (prop is! YamlMap) continue;
      final declared = prop['type']?.toString();
      if (declared == null) continue;

      // An enum constrains the value regardless of the declared branch, so
      // the branch axis does not apply — `widget_render_matrix_test` and the
      // schema already cover it.
      if (prop['enum'] is YamlList) continue;

      final branches = _branchesOf(declared);
      if (branches.length < 2) continue;

      for (final branch in branches) {
        final value = _sampleForBranch(branch, prop, siblings: branches);
        if (value == null) {
          _unsynthesizable.add('$type.$name ($branch)');
          continue;
        }
        cases.add(_Case(
          type,
          name,
          branch,
          <String, dynamic>{...base, name: value},
        ));
      }
    }
  }
  cases.sort((a, b) => '${a.widget}.${a.label}'.compareTo('${b.widget}.${b.label}'));
  return cases;
}

/// The branches a declared type accepts. A `|` union splits; a named primitive
/// that is itself a union expands to its own branches.
List<String> _branchesOf(String declared) {
  if (declared.contains('|')) {
    return declared.split('|').map((s) => s.trim()).toList();
  }
  // IconRef is the one primitive whose schema is an anyOf with object
  // branches (`configs/_primitive/IconRef.yaml`); a factory reading it as a
  // bare string throws on the other three.
  if (declared == 'IconRef') {
    return const ['iconName', 'iconCodepoint', 'iconUri', 'binding'];
  }
  return <String>[declared];
}

Object? _sampleForBranch(
  String branch,
  YamlMap prop, {
  List<String> siblings = const <String>[],
}) {
  switch (branch) {
    case 'binding':
      // A binding has to land on a value of the type its sibling branch
      // declares. Binding every property to a number would test that the
      // factory rejects a number, not that it accepts a binding.
      return '{{${_stateKeyFor(siblings)}}}';
    case 'number':
      return 2;
    case 'string':
      return 'sample';
    case 'boolean':
      return true;
    case 'any':
      return 'sample';
    case 'object':
      return <String, dynamic>{};
    case 'array':
      return <dynamic>[];
    case 'Widget':
      return <String, dynamic>{'type': 'text', 'content': 'w'};
    case 'iconName':
      return 'home';
    case 'iconCodepoint':
      return <String, dynamic>{'codepoint': 0xe88a};
    case 'iconUri':
      return <String, dynamic>{'uri': 'ui://icons/home'};
  }
  if (branch.startsWith('array<')) {
    final element = branch.substring(6, branch.length - 1).trim();
    final sample = _sampleForBranch(element, prop);
    return sample == null ? null : <Object>[sample];
  }
  return null; // a named type this harness does not know how to build
}

/// The seeded state key whose value matches the non-binding branch.
String _stateKeyFor(List<String> siblings) {
  for (final s in siblings) {
    if (s == 'binding') continue;
    if (s.startsWith('array')) return 'list';
    switch (s) {
      case 'number':
        return 'num';
      case 'boolean':
        return 'flag';
      case 'string':
      case 'any':
        return 'str';
      case 'object':
        return 'obj';
    }
  }
  return 'str';
}

/// The first example the spec ships for this widget, decoded. Examples the
/// registry marks as deliberately invalid are not bases.
Map<String, dynamic>? _exampleBase(YamlMap doc) {
  final raw = doc['examples'];
  if (raw is! YamlList) return null;
  for (final e in raw) {
    if (e is! YamlMap) continue;
    if (e['expect']?.toString() == 'validation_error') continue;
    final dsl = e['dsl'];
    if (dsl is! String) continue;
    try {
      final decoded = jsonDecode(dsl);
      if (decoded is Map<String, dynamic> && decoded['type'] == doc['type']) {
        return decoded;
      }
    } on FormatException {
      // `validate_examples` grades malformed examples; not this axis.
    }
  }
  return null;
}

/// The smallest document the registry says is legal.
Map<String, dynamic>? _minimalDoc(String type, YamlMap properties) {
  final doc = <String, dynamic>{'type': type};
  for (final entry in properties.entries) {
    final name = entry.key as String;
    final prop = entry.value;
    if (prop is! YamlMap) continue;
    if (prop['required'] != true) continue;
    final declared = prop['type']?.toString() ?? 'string';

    final enumValues = prop['enum'];
    if (enumValues is YamlList && enumValues.isNotEmpty) {
      doc[name] = enumValues.first.toString();
      continue;
    }
    final value = _sampleForBranch(_branchesOf(declared).first, prop);
    if (value == null) return null;
    doc[name] = value;
  }
  return doc;
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
  return Directory.current.path;
}
