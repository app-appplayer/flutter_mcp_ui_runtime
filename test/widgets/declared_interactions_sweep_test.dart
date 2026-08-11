// Gestures a document declares that nothing had performed.
//
// A hover that ends, a right-click, a tap on a row, a button in a banner —
// each is wired in a factory and each had never been driven, so the wiring was
// a claim rather than an observation. The failure mode is uniform and quiet:
// the widget draws correctly, the user acts, and nothing happens.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
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

  /// A `state.set` the tests can watch.
  Map<String, dynamic> setAction(String binding, dynamic value) =>
      <String, dynamic>{
        'type': 'state',
        'action': 'set',
        'binding': binding,
        'value': value,
      };

  group('a table row that is not selectable', () {
    testWidgets('still fires its declared onRowTap, with the row attached',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'dataTable',
        'columns': <dynamic>[
          <String, dynamic>{'key': 'name', 'label': 'Name'},
        ],
        'rows': <dynamic>[
          <String, dynamic>{'name': 'Ada', 'id': 7},
        ],
        'onRowTap': setAction('openedId', '{{event.row.id}}'),
      });

      await tester.tap(find.text('Ada'));
      await tester.pumpAndSettle();

      expect(stateManager.get('openedId'), 7,
          reason: 'the spec\'s own example reads `{{event.row.id}}`; a tap '
              'that fires without the row makes every such document read '
              'null, and gating on `selectable` makes it fire not at all');
    });
  });

  group('a link', () {
    testWidgets('drops its hover underline when the pointer leaves',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'link',
        'label': 'Docs',
        'underline': 'hover',
      });

      TextDecoration? decorationOf() =>
          tester.widget<Text>(find.text('Docs')).style?.decoration;

      final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await pointer.addPointer(location: Offset.zero);
      addTearDown(pointer.removePointer);

      await pointer.moveTo(tester.getCenter(find.text('Docs')));
      await tester.pump();
      expect(decorationOf(), TextDecoration.underline);

      await pointer.moveTo(const Offset(500, 500));
      await tester.pump();

      expect(decorationOf(), isNot(TextDecoration.underline),
          reason: 'an underline that never comes off leaves every link the '
              'pointer has ever crossed looking hovered');
    });
  });

  group('a context menu', () {
    testWidgets('opens on a secondary tap and reports the chosen key',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'contextMenu',
        'items': <dynamic>[
          <String, dynamic>{'key': 'copy', 'label': 'Copy'},
          <String, dynamic>{'divider': true},
          <String, dynamic>{'key': 'delete', 'label': 'Delete'},
        ],
        'onSelect': setAction('chosen', '{{event.value}}'),
        'child': <String, dynamic>{'type': 'text', 'content': 'target'},
      });

      final gesture =
          await tester.startGesture(tester.getCenter(find.text('target')),
              kind: PointerDeviceKind.mouse, buttons: kSecondaryButton);
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('Delete'), findsOneWidget,
          reason: 'right-click is the gesture this widget exists for');
      expect(find.byType(PopupMenuDivider), findsOneWidget,
          reason: 'a declared divider that renders as an item makes the menu '
              'read as one undivided list');

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(stateManager.get('chosen'), 'delete');
    });
  });

  group('a banner action', () {
    testWidgets('fires the declared click', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'banner',
        'content': 'Update available',
        'actions': <dynamic>[
          <String, dynamic>{
            'label': 'Install',
            'click': setAction('installed', true),
          },
          <String, dynamic>{'label': 'Later'},
        ],
      });

      await tester.tap(find.text('Install'));
      await tester.pump();

      expect(stateManager.get('installed'), isTrue);
      expect(
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, 'Later'))
              .onPressed,
          isNull,
          reason: 'an action with nothing declared behind it is disabled, not '
              'a button that silently does nothing when pressed');
    });
  });

  group('a segmented control drawn as buttons', () {
    testWidgets('selects through either kind of button', (tester) async {
      stateManager.set('view', 'list');

      await pump(tester, <String, dynamic>{
        'type': 'segmentedControl',
        'variant': 'buttons',
        'value': '{{view}}',
        'binding': 'view',
        'options': <dynamic>[
          <String, dynamic>{'value': 'list', 'label': 'List'},
          <String, dynamic>{'value': 'grid', 'label': 'Grid'},
        ],
      });

      // The selected key is a FilledButton, the rest are OutlinedButtons —
      // two constructors, and only one of them had ever been pressed.
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);

      await tester.tap(find.text('Grid'));
      await tester.pumpAndSettle();
      expect(stateManager.get('view'), 'grid');

      await tester.tap(find.text('Grid'));
      await tester.pumpAndSettle();
      expect(stateManager.get('view'), 'grid',
          reason: 'pressing the already-selected segment is the other '
              'constructor; it must not toggle the choice off');
    });
  });

  group('a disabled radio group', () {
    testWidgets('leaves the bound value alone when tapped', (tester) async {
      stateManager.set('plan', 'basic');

      await pump(tester, <String, dynamic>{
        'type': 'radioGroup',
        'value': '{{plan}}',
        'binding': 'plan',
        'enabled': false,
        'options': <dynamic>[
          <String, dynamic>{'value': 'basic', 'label': 'Basic'},
          <String, dynamic>{'value': 'pro', 'label': 'Pro'},
        ],
      });

      await tester.tap(find.text('Pro'));
      await tester.pumpAndSettle();

      expect(stateManager.get('plan'), 'basic',
          reason: 'a disabled group that still writes is a control the '
              'document declared unusable and the user can change anyway');
    });
  });
}
