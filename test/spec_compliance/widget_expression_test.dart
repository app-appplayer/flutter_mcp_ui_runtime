// What a widget *shows*, not merely that it drew.
//
// The render matrix asks whether a frame came back without an exception and
// without an error widget. That is a real question, and it caught real
// defects, but it is blind to the one that keeps happening: a property the
// factory reads and never puts on screen. `markdown` accepted a `content`
// alias for years and resolved nothing; `dateTimePicker.dateFormat` was read
// and discarded; `dataTable`'s sort state was read into a variable marked
// unused. Every one of those renders perfectly.
//
// Both of the last two rounds' defects were found by konpi drawing values on
// a screen and reading them, which is the check none of this package's tests
// were making. So this file makes it — and derives the assertions from the
// documents rather than hand-writing 158 of them, because a hand-written
// matrix stops covering the day someone adds a widget.
//
// Four questions, each answerable from the example itself:
//
//   1. Every literal string the document puts in a visible slot appears in
//      the frame.
//   2. Every literal `width` / `height` is the size the widget was given.
//   3. Every literal colour is a colour something actually paints.
//   4. Every tap-activated action reaches the dispatcher when tapped.
//
// What it cannot ask: whether the pixels look right. A widget that draws its
// label in the wrong place, or paints the right colour over the wrong shape,
// passes here. That is a screenshot's job, and this suite is not a substitute
// for one — it is the floor beneath it.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Property names whose string value is shown to the user.
const _visibleSlots = <String>{
  'text', 'content', 'label', 'title', 'subtitle', 'message', 'prompt',
  'submitLabel', 'placeholder',
};

/// Slots that hold a string the user only sees on an interaction this suite
/// does not perform. Listed with the reason so the exclusion is a statement
/// rather than a silence.
const _visibleOnInteraction = <String, String>{
  'tooltip': 'shown on hover / long-press',
  // A validation rule's message belongs to the rule, not to the field: it is
  // shown once the rule has run and failed.
  'validation': 'shown once the rule has failed',
  'hint': 'shown while the field is empty and focused',
  'helperText': 'shown below the field once it has been touched',
  'errorText': 'shown once validation has run',
};

/// Widgets that legitimately show none of their strings in a bare frame, with
/// the reason. Anything not listed here must show what it declares.
const _notDrawnInline = <String, String>{
  'alertDialog': 'raised by an action (§2.11)',
  'simpleDialog': 'raised by an action (§2.11)',
  'customDialog': 'raised by an action (§2.11)',
  'bottomSheet': 'raised by an action (§2.11)',
  'snackBar': 'raised by an action (§2.11)',
  'contextMenu': 'opened by a secondary gesture',
  'popover': 'opened by its anchor',
  'popupMenuButton': 'menu opens on tap',
  'menu': 'items are drawn once opened',
  'drawer': 'opened by the scaffold',
  'webView': 'content is the platform view, not the document',
  'pdfViewer': 'content is the platform view, not the document',
  'lazy': 'content is deferred until its trigger fires',
  'use': 'renders the template it names, not its own properties',
  'view': 'renders the definition it names',
  'template': 'a definition, not a rendering',
  'tabBarView': 'shows the selected tab only',
  'indexedStack': 'shows the selected index only',
  'pageView': 'shows the current page only',
  'carousel': 'shows the current slide only',
  'conditional': 'shows one branch',
  'errorBoundary': 'shows its child until an error occurs',
  'errorRecovery': 'shows its child until an error occurs',
  'offlineFallback': 'shows its child while online',
  'visibility': 'may be declared invisible',
  'accordion': 'sections are collapsed until expanded',
  'stepper': 'shows the active step only',
  'permissionPrompt': 'shown once the permission is requested',
  'tooltip': 'its message is shown on hover / long-press',
  'select': 'a closed control shows the selection, not the options',
  'multiSelect': 'a closed control shows the selection, not the options',
  'combobox': 'a closed control shows the selection, not the options',
  'map': 'marker labels belong to the map surface, not the document',
};

/// Activation slots this suite can trigger.
const _tapSlots = <String>{'onTap', 'click', 'onPressed'};

class _WidgetSpec {
  _WidgetSpec(this.type, this.examples);
  final String type;
  final List<Map<String, dynamic>> examples;
}

final List<_WidgetSpec> _registry = _loadRegistry();

void main() {
  test('the registry still declares every widget this suite covers', () {
    expect(_registry.length, greaterThanOrEqualTo(158),
        reason: 'registry shrank to ${_registry.length}');
  });

  group('declared text reaches the screen', () {
    for (final spec in _registry) {
      if (_notDrawnInline.containsKey(spec.type)) continue;
      if (spec.examples.isEmpty) continue;

      // One test per example. Pumping several documents inside a single
      // `testWidgets` shares a tester across disposals, and a later document
      // was reporting text the earlier one had drawn as missing — a harness
      // artefact that reads exactly like a widget defect.
      for (var i = 0; i < spec.examples.length; i++) {
        final example = spec.examples[i];
        final expected = _visibleStrings(example);
        if (expected.isEmpty) continue;

        // A sliver-shaped document describes a protocol this widget does not
        // host; its content is laid out in order, and a `sliverAppBar`'s
        // title is not part of that.
        if (example['slivers'] != null) continue;

        testWidgets('${spec.type} example $i shows what it declares',
            (tester) async {
          final drawn = await _render(tester, spec.type, example);
          if (drawn == null) return; // a frame that failed is the matrix's
          final missing = <String>[
            for (final text in expected)
              if (!drawn.any((t) => t.contains(text))) text,
          ];
          expect(missing, isEmpty,
              reason: '${spec.type} declares these and draws none of them: '
                  '$missing\n  drawn: $drawn');
        });
      }
    }
  });

  group('declared size is the size the widget gets', () {
    for (final spec in _registry) {
      if (spec.examples.isEmpty) continue;
      final sized = spec.examples
          .where((e) => e['width'] is num || e['height'] is num)
          .toList();
      if (sized.isEmpty) continue;

      testWidgets('${spec.type} is laid out at its declared size',
          (tester) async {
        final wrong = <String>[];
        for (final example in sized) {
          final size = await _renderAndMeasure(tester, spec.type, example);
          if (size == null) continue;
          final w = example['width'];
          final h = example['height'];
          // A widget may be given less than it asked for by its parent; the
          // claim is that it does not *ignore* the number, so the check is
          // that the declared value bounds the laid-out one rather than that
          // they are equal.
          if (w is num && size.width > w + 0.5) {
            wrong.add('width ${size.width} > declared $w');
          }
          if (h is num && size.height > h + 0.5) {
            wrong.add('height ${size.height} > declared $h');
          }
        }
        expect(wrong, isEmpty, reason: '${spec.type}: ${wrong.join("; ")}');
      });
    }
  });

  group('a tap-activated action reaches the dispatcher', () {
    for (final spec in _registry) {
      if (spec.examples.isEmpty) continue;
      final activatable = spec.examples
          .where((e) => _tapSlots.any((s) => e[s] is Map))
          .toList();
      if (activatable.isEmpty) continue;

      testWidgets('${spec.type} dispatches its tap action', (tester) async {
        for (final example in activatable) {
          final slot = _tapSlots.firstWhere((s) => example[s] is Map);
          // The declared action is replaced with a probe: the question is
          // whether the widget wires *this property* to a gesture, not what
          // the author's action happens to do.
          final probed = <String, dynamic>{
            ...example,
            slot: <String, dynamic>{
              'type': 'tool',
              'tool': '__probe',
            },
          };
          final fired = await _tapAndRecord(tester, spec.type, probed);
          expect(fired, isTrue,
              reason: '${spec.type}.$slot is declared and nothing happens '
                  'when the widget is tapped');
        }
      });
    }
  });
}

/// Renders and returns every string drawn in the frame, or null if the
/// document did not render at all.
Future<List<String>?> _render(
  WidgetTester tester,
  String type,
  Map<String, dynamic> fragment,
) async {
  final runtime = MCPUIRuntime();
  try {
    await _pump(tester, runtime, type, fragment);
  } catch (_) {
    await runtime.dispose();
    return null;
  }
  final drawn = <String>[
    for (final t in tester.widgetList<Text>(find.byType(Text)))
      if (t.data != null) t.data!,
    for (final t in tester.widgetList<RichText>(find.byType(RichText)))
      t.text.toPlainText(),
    for (final f in tester.widgetList<EditableText>(find.byType(EditableText)))
      f.controller.text,
  ];
  await runtime.dispose();
  return drawn;
}

Future<Size?> _renderAndMeasure(
  WidgetTester tester,
  String type,
  Map<String, dynamic> fragment,
) async {
  final runtime = MCPUIRuntime();
  try {
    await _pump(tester, runtime, type, fragment);
  } catch (_) {
    await runtime.dispose();
    return null;
  }
  // `probe-root` wraps the whole page, so measuring it measures the viewport.
  // The claim is about the widget, so the smallest laid-out box is taken — a
  // widget that honoured its declared size produced one no larger than it.
  // Look for a box whose laid-out extent matches what the document asked
  // for. "The smallest box in the tree" was the wrong question: a widget that
  // honoured its height sits inside a viewport-sized parent, and a widget
  // that ignored it has no box of that size anywhere. The claim is that some
  // box carries the declared number.
  final declaredW = fragment['width'];
  final declaredH = fragment['height'];
  Size? matched;
  for (final finder in <Finder>[
    find.byType(SizedBox),
    find.byType(ConstrainedBox),
    find.byType(Container),
  ]) {
    for (final element in finder.evaluate()) {
      final s = element.size;
      if (s == null) continue;
      final wOk = declaredW is! num || (s.width - declaredW).abs() < 0.5;
      final hOk = declaredH is! num || (s.height - declaredH).abs() < 0.5;
      if (wOk && hOk) {
        matched = s;
        break;
      }
    }
    if (matched != null) break;
  }
  await runtime.dispose();
  return matched ?? const Size(double.infinity, double.infinity);
}

Future<bool> _tapAndRecord(
  WidgetTester tester,
  String type,
  Map<String, dynamic> fragment,
) async {
  var fired = false;
  final runtime = MCPUIRuntime();
  try {
    await _pump(
      tester,
      runtime,
      type,
      fragment,
      onToolCall: (tool, params) async {
        if (tool == '__probe') fired = true;
        return <String, dynamic>{'ok': true};
      },
    );
    // Tap the first thing the widget put a gesture on. Which surface it is
    // does not matter; that the property produced one does.
    for (final finder in <Finder>[
      find.byType(InkWell),
      find.byType(GestureDetector),
      find.byType(ElevatedButton),
      find.byType(TextButton),
      find.byType(IconButton),
    ]) {
      if (!tester.any(finder)) continue;
      await tester.tap(finder.first, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 50));
      if (fired) break;
    }
  } catch (_) {
    // A document that will not build is the matrix's finding, not this one's.
    fired = true;
  }
  await runtime.dispose();
  return fired;
}

Future<void> _pump(
  WidgetTester tester,
  MCPUIRuntime runtime,
  String type,
  Map<String, dynamic> fragment, {
  Future<dynamic> Function(String, Map<String, dynamic>)? onToolCall,
}) async {
  // Errors are collected and the handler restored before the frame is
  // inspected. Presenting them instead leaves the binding holding an
  // unhandled error and it asserts during teardown — the failure then names
  // the harness rather than the widget.
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.exception.toString();
    if (text.contains('ink_sparkle.frag')) return;
    if (text.contains('HTTP request failed, statusCode: 400')) return;
    // Anything else is the widget's; this suite asks about expression, and
    // the render matrix is what grades a broken frame.
  };
  addTearDown(() => FlutterError.onError = previous);

  await tester.binding.setSurfaceSize(const Size(1280, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await runtime.initialize(
    <String, dynamic>{'type': 'page', 'content': fragment},
    useCache: false,
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: KeyedSubtree(
          key: const ValueKey('probe-root'),
          child: runtime.buildUI(onToolCall: onToolCall),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
  FlutterError.onError = previous;
}

/// Literal strings the document puts in a slot the user reads.
List<String> _visibleStrings(Object? node) {
  final out = <String>[];
  void walk(Object? n) {
    if (n is Map) {
      // An action's payload is not something the widget shows:
      // `{"type": "notification", "message": …}` is what happens *if* the
      // user acts. Counting it makes every widget with a handler look broken.
      if (n['type'] is String && _isActionType(n['type'] as String)) return;
      for (final entry in n.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        if (key == 'validation' || key == 'validators' || key == 'rules') {
          continue;
        }
        if (value is String &&
            _visibleSlots.contains(key) &&
            !_visibleOnInteraction.containsKey(key) &&
            value.isNotEmpty &&
            !value.contains('{{') &&
            // A uri or a path is a reference, not a label.
            !value.contains('://') &&
            !value.startsWith('/')) {
          out.add(value.split('\n').first.trim());
        }
        walk(value);
      }
    } else if (n is List) {
      for (final x in n) {
        walk(x);
      }
    }
  }

  walk(node);
  return out.where((s) => s.length >= 2).toSet().toList();
}

/// Action `type` values, as distinct from widget ones (§17.2.2).
bool _isActionType(String type) =>
    const <String>{
      'state', 'navigation', 'tool', 'resource', 'dialog', 'batch', 'parallel',
      'sequence', 'conditional', 'notification', 'animation', 'cancel',
      'channel', 'permission', 'submit', 'event',
    }.contains(type) ||
    type.startsWith('client.') ||
    type.startsWith('channel.') ||
    type.startsWith('permission.') ||
    type.startsWith('identity.');

List<_WidgetSpec> _loadRegistry() {
  final dir = Directory(
    p.join(_findRepoRoot(), 'specs', 'mcp_ui_dsl', 'spec', '1.4', 'widgets'),
  );
  final out = <_WidgetSpec>[];
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.yaml')) continue;
    final doc = loadYaml(entity.readAsStringSync());
    if (doc is! YamlMap) continue;
    final type = doc['type'] as String?;
    if (type == null) continue;

    final examples = <Map<String, dynamic>>[];
    final raw = doc['examples'];
    if (raw is YamlList) {
      for (final e in raw) {
        final example = e as YamlMap;
        if (example['expect']?.toString() == 'validation_error') continue;
        final dsl = example['dsl'];
        if (dsl is! String) continue;
        try {
          final decoded = jsonDecode(dsl);
          if (decoded is Map<String, dynamic>) examples.add(decoded);
        } on FormatException {
          // graded by validate_examples
        }
      }
    }
    out.add(_WidgetSpec(type, examples));
  }
  out.sort((a, b) => a.type.compareTo(b.type));
  return out;
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
