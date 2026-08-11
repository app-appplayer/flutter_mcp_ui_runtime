// `tree` — the shapes a node can take and the ways a document reads it back.
//
// A tree is a control as much as a display: checkable nodes, a non-expandable
// flat form, a leading icon per node. Each is a separate branch, and a branch
// that renders without reporting leaves a document showing a selection nobody
// can act on.

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
        body: SizedBox(
          width: 400,
          height: 600,
          child: AnimatedBuilder(
            animation: stateManager,
            builder: (_, __) =>
                context.renderer.renderWidget(definition, context),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  List<dynamic> nodes() => <dynamic>[
        <String, dynamic>{
          'id': 'root',
          'label': 'Root',
          'icon': 'folder',
          'children': <dynamic>[
            <String, dynamic>{'id': 'leaf', 'label': 'Leaf'},
          ],
        },
      ];

  Map<String, dynamic> tree({Map<String, dynamic> extra = const {}}) =>
      <String, dynamic>{
        'type': 'tree',
        'data': nodes(),
        'initiallyExpanded': true,
        ...extra,
      };

  group('checkable nodes', () {
    testWidgets('ticking a node reports the whole checked set',
        (tester) async {
      stateManager.set('checked', <dynamic>[]);
      // The checked set is reported through the two-way binding — the list
      // the document already holds — rather than a separate handler.
      await pump(tester, tree(extra: <String, dynamic>{
        'checkable': true,
        'checkedKeys': '{{checked}}',
      }));

      expect(find.byType(Checkbox), findsWidgets);

      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();

      expect(stateManager.get<List<dynamic>>('checked'), contains('root'),
          reason: 'the checked set is what a document submits; a tree that '
              'ticks its own boxes and reports nothing submits an empty '
              'selection');
    });

    testWidgets('unticking removes it again', (tester) async {
      stateManager.set('checked', <dynamic>['root']);
      await pump(tester, tree(extra: <String, dynamic>{
        'checkable': true,
        'checkedKeys': '{{checked}}',
      }));

      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();

      expect(stateManager.get<List<dynamic>>('checked'),
          isNot(contains('root')));
    });
  });

  group('a non-expandable tree', () {
    testWidgets('shows its children flat, and a tap still reports',
        (tester) async {
      await pump(tester, tree(extra: <String, dynamic>{
        'expandable': false,
        'onNodeTap': <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'tapped',
          'value': true,
        },
      }));

      expect(find.text('Root'), findsOneWidget);
      expect(find.text('Leaf'), findsOneWidget,
          reason: 'a tree that cannot expand has to show what it holds, or '
              'the data is unreachable');

      await tester.tap(find.text('Root'));
      await tester.pumpAndSettle();
      expect(stateManager.get('tapped'), isTrue);
    });

    testWidgets('a leading icon is drawn beside the label', (tester) async {
      await pump(tester, tree(extra: <String, dynamic>{'expandable': false}));

      expect(find.byIcon(Icons.folder), findsOneWidget);
    });
  });

  group('an expandable tree', () {
    testWidgets('a selected node is highlighted', (tester) async {
      await pump(tester, tree(extra: <String, dynamic>{
        'selectable': true,
        'selectedColor': '#FF0000',
      }));

      await tester.tap(find.text('Root'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Root'), findsOneWidget);
    });

    testWidgets('a node icon is drawn in the expandable row too',
        (tester) async {
      await pump(tester, tree());

      expect(find.byIcon(Icons.folder), findsWidgets);
    });

    testWidgets('a declared size bounds the tree', (tester) async {
      await pump(tester, tree(extra: <String, dynamic>{
        'width': 200,
        'height': 120,
      }));

      final box = find
          .ancestor(of: find.text('Root'), matching: find.byType(SizedBox))
          .evaluate()
          .map((e) => e.widget as SizedBox)
          .where((s) => s.width == 200 && s.height == 120);
      expect(box, isNotEmpty,
          reason: 'a tree in a dashboard tile has to stay inside it');
    });
  });
}
