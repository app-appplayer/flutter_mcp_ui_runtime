// A handful of small widgets whose remaining gaps are each one branch: the
// second way to declare a child, the lifecycle a template instance owns, the
// severity a banner is drawn in, the reports a resizable makes.
//
// None of these is exotic — they are the shapes a document reaches by writing
// `children` instead of `child`, or by asking for the error severity. Each
// one renders either way, which is why they went unread.

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_core/flutter_mcp_ui_core.dart'
    show TemplateDefinition;
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/default_widgets.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/templates/template_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/widgets/layout/use_template_factory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StateManager stateManager;
  late RenderContext context;
  late WidgetRegistry registry;
  late TemplateRegistry templates;

  setUp(() {
    stateManager = StateManager()..initialize(<String, dynamic>{});
    registry = WidgetRegistry();
    DefaultWidgets.registerAll(registry);
    templates = TemplateRegistry();
    registry.register('use', UseTemplateFactory(templateRegistry: templates));
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

  tearDown(() => templates.dispose());

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

  Map<String, dynamic> set(String binding, Object? value) => <String, dynamic>{
        'type': 'state',
        'action': 'set',
        'binding': binding,
        'value': value,
      };

  group('fractionallySized', () {
    testWidgets('takes its child from `children` as well as `child`',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'fractionallySized',
        'widthFactor': 0.5,
        'children': <dynamic>[
          <String, dynamic>{'type': 'text', 'content': 'inside'},
        ],
      });

      expect(find.text('inside'), findsOneWidget,
          reason: 'both spellings are in the field; reading only `child` '
              'renders an empty box for half the documents');
    });

    testWidgets('a `children` entry that is not a widget is ignored, not fatal',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'fractionallySized',
        'widthFactor': 0.5,
        'children': <dynamic>['not a widget'],
      });

      expect(tester.takeException(), isNull);
    });
  });

  group('use (template instance)', () {
    testWidgets('a template with lifecycle hooks runs them per instance',
        (tester) async {
      templates.register(TemplateDefinition.fromJson(<String, dynamic>{
        'name': 'greeting',
        // The hooks live on the template's own content — that is what the
        // instance renders, and what `LifecycleDefinition` is read from.
        'content': <String, dynamic>{
          'type': 'text',
          'content': 'hello',
          'onMount': <dynamic>[set('mounted', true)],
        },
      }));

      await pump(tester, <String, dynamic>{
        'type': 'use',
        'template': 'greeting',
      });

      expect(find.text('hello'), findsOneWidget);
      expect(stateManager.get('mounted'), isTrue,
          reason: '§9.9.1 says a template definition\'s own onMount fires once '
              'per instance; a template that declares one and never hears it '
              'renders without whatever it set up');
    });

    testWidgets('a template with no hooks is rendered without a host',
        (tester) async {
      templates.register(TemplateDefinition.fromJson(<String, dynamic>{
        'name': 'plain',
        'content': <String, dynamic>{'type': 'text', 'content': 'plain'},
      }));

      await pump(tester, <String, dynamic>{
        'type': 'use',
        'template': 'plain',
      });

      expect(find.text('plain'), findsOneWidget);
    });

    testWidgets('a template nobody registered is reported on screen',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'use',
        'template': 'nowhere',
      });

      expect(find.textContaining('nowhere'), findsOneWidget,
          reason: 'a `use` of a name that is not registered is an authoring '
              'mistake; drawing nothing sends the author looking at the '
              'template instead of the name');
    });
  });

  group('banner', () {
    testWidgets('the error severity is drawn in the error colours',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'banner',
        'severity': 'error',
        'message': 'Could not save',
      });

      final scheme = ThemeData.light().colorScheme;
      final container = tester.widgetList<Container>(find.byType(Container));
      final colours = container
          .map((c) => (c.decoration as BoxDecoration?)?.color ?? c.color)
          .toList();

      expect(colours, contains(scheme.errorContainer),
          reason: 'severity is what a user reads at a glance; one colour for '
              'every severity makes the property decorative');
    });

    testWidgets('a banner can be tapped when the document says so',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'banner',
        'message': 'Tap me',
        'click': set('tapped', true),
      });

      await tester.tap(find.text('Tap me'));
      await tester.pumpAndSettle();

      expect(stateManager.get('tapped'), isTrue);
    });
  });
}
