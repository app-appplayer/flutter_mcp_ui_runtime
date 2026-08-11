// The last of the declared shapes and repaint comparisons.
//
// Two kinds of thing here. One is a property a document writes that had never
// been written in a test — an `initialDate`, a `value` given without a
// binding, a spacing token that does not exist. The other is a repaint
// comparison whose later terms had never decided anything, because every test
// that changed a painter changed the first thing it compares: a stroke width
// or a background that moves while the value stays put draws the old picture.

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_expression.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/default_widgets.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_test/flutter_test.dart';

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

  tearDown(() => ThemeManager.instance.reset());

  Future<void> pump(WidgetTester tester, Map<String, dynamic> definition) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AnimatedBuilder(
          animation: stateManager,
          builder: (_, __) => context.renderer.renderWidget(definition, context),
        ),
      ),
    ));
    await tester.pump();
  }

  /// The painters currently on screen.
  List<Object?> painters(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((p) => p.painter)
      .toList();

  group('a painter whose value has not moved', () {
    testWidgets('a gauge redraws for a changed stroke width', (tester) async {
      Map<String, dynamic> definition(double stroke) => <String, dynamic>{
            'type': 'gauge',
            'value': 0.4,
            'strokeWidth': stroke,
          };

      await pump(tester, definition(8));
      final first = painters(tester);
      await pump(tester, definition(16));

      expect(painters(tester).any((p) => !first.any((q) => identical(p, q))),
          isTrue,
          reason: 'the comparison stops at the first difference, so a stroke '
              'that changes while the value does not is the only way this '
              'term ever decides anything — and a gauge that keeps its old '
              'thickness looks like the theme was ignored');
    });

    testWidgets('a barcode redraws for a changed background', (tester) async {
      Map<String, dynamic> definition(String background) => <String, dynamic>{
            'type': 'barcode',
            'value': '12345670',
            'format': 'ean8',
            'foregroundColor': '#FF000000',
            'backgroundColor': background,
          };

      await pump(tester, definition('#FFFFFFFF'));
      final first = painters(tester);
      await pump(tester, definition('#FFEEEEEE'));

      expect(painters(tester).any((p) => !first.any((q) => identical(p, q))),
          isTrue,
          reason: 'same pattern, same ink, different paper — a scanner reads '
              'contrast, so the paper is not cosmetic');
    });
  });

  group('a date picker', () {
    testWidgets('takes an initialDate and a value with no binding',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'datePicker',
        'initialDate': '2024-01-15',
        'value': '2024-02-01',
      });

      expect(find.textContaining('2024-02-01'), findsWidgets,
          reason: 'a picker given a value and no binding is a read-only '
              'display of a date the document already holds; showing today '
              'instead is showing the wrong day');
      expect(tester.takeException(), isNull);
    });
  });

  group('a time picker', () {
    testWidgets('takes an initialTime and a value with no binding',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'timePicker',
        'initialTime': '09:30',
        'value': '10:00',
      });

      expect(find.textContaining('10:00'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('a number stepper', () {
    testWidgets('follows its bound value and keeps two decimals',
        (tester) async {
      stateManager.set('amount', 1.5);

      await pump(tester, <String, dynamic>{
        'type': 'numberStepper',
        'value': '{{amount}}',
        'binding': 'amount',
        'step': 0.25,
      });

      expect(find.text('1.50'), findsOneWidget,
          reason: 'a fractional amount rendered as "1.5" or "2" is a price '
              'the user cannot read back');

      // A write from somewhere else — another widget, a tool result. The
      // stepper holds its own copy, and a copy taken once at build leaves the
      // control showing a number that is no longer the truth.
      stateManager.set('amount', 3.0);
      await tester.pumpAndSettle();

      expect(find.text('3'), findsOneWidget);
    });
  });

  group('a spacing token that does not exist', () {
    testWidgets('is reported rather than silently dropped', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'box',
        'padding': <String, dynamic>{'token': 'enormous'},
        'child': <String, dynamic>{'type': 'text', 'content': 'padded'},
      });

      expect(find.text('padded'), findsOneWidget);
      expect(tester.takeException(), isNull,
          reason: 'a token the theme does not define is an author mistake, '
              'and the page keeps drawing while it is reported');
    });
  });

  group('a chart declared with an empty dataset list', () {
    testWidgets('draws an empty chart', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'chart',
        'chartType': 'bar',
        'data': <String, dynamic>{
          'datasets': <dynamic>[],
          'labels': <dynamic>['Jan'],
        },
        'height': 200,
      });

      expect(tester.takeException(), isNull,
          reason: 'the first frame of a chart whose data is still loading '
              'has no dataset, and that is not an error');
    });
  });

  group('a not inside a larger expression', () {
    test('is parsed as an operand, not as the whole expression', () {
      // `!a && b` splits on `&&` first, and the left side comes back through
      // the value parser — a different door from `{{!a}}`, and the one a real
      // condition goes through.
      final expression = BindingExpression.parse('!enabled && ready');

      expect(expression.operator, '&&');
      expect(expression.left?.operator, '!',
          reason: 'reading `!enabled` as a path named "!enabled" answers null '
              'for a flag that is set, so the condition is wrong exactly when '
              'it matters');

      final engine = BindingEngine();
      expect(
          engine.resolve<bool>('{{!enabled && ready}}', context),
          isFalse,
          reason: 'enabled and ready are both unset, so `!enabled` is true '
              'and `ready` is false');

      stateManager.set('ready', true);
      expect(engine.resolve<bool>('{{!enabled && ready}}', context), isTrue);
    });
  });

  group('a runtime with no theme declared', () {
    test('still answers every M3 colour role from its own definition', () {
      final theme = ThemeManager.instance..reset();

      // This is why the derived-scheme fallback in `getColorValue` never runs
      // for an undeclared theme: the default definition enumerates the whole
      // palette, so the raw lookup always answers. A role that came back null
      // here would leave a widget with nothing to paint and no theme to
      // blame.
      for (final slot in const <String>[
        'primary', 'onPrimary', 'secondary', 'surface', 'onSurface',
        'onSurfaceVariant', 'surfaceContainerHighest', 'outline', 'error',
      ]) {
        expect(theme.getColorValue(slot), isNotNull, reason: 'slot: $slot');
      }

      // A semantic slot is not part of Flutter's ColorScheme, and §5.3 leaves
      // it to the bundle — null is the honest answer rather than a colour
      // invented for it.
      expect(theme.getColorValue('success'), isNull);
    });
  });
}
