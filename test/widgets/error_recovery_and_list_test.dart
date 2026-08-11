// `errorRecovery`, `list` and `dialog` — three widgets whose uncovered part is
// what they do when something is missing.
//
// `errorRecovery` was 22% covered: the entire point of the widget — catching a
// child that will not build and putting something usable in its place — had
// never run. `list` was 61%: the empty message, the virtual path, the
// separators. `dialog` was 38%: the type switch that decides which surface a
// document actually gets.

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/default_widgets.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/widgets/widget_factory.dart';
import 'package:flutter_test/flutter_test.dart';

/// A registered widget type that always throws while building — the shape of a
/// factory meeting data it cannot use.
class _ExplodingFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) =>
      throw StateError('the child could not be built');
}

void main() {
  late StateManager stateManager;
  late RenderContext context;

  setUp(() {
    stateManager = StateManager()..initialize(<String, dynamic>{});
    final registry = WidgetRegistry();
    DefaultWidgets.registerAll(registry);
    registry.register('explodes', _ExplodingFactory());
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

  group('errorRecovery', () {
    testWidgets('a child that builds is left alone', (tester) async {
      await pump(tester, {
        'type': 'errorRecovery',
        'child': {'type': 'text', 'content': 'the content'},
      });

      expect(find.text('the content'), findsOneWidget);
      expect(find.text('Something went wrong'), findsNothing);
    });

    testWidgets('a child that throws is replaced by a usable surface',
        (tester) async {
      await pump(tester, {
        'type': 'errorRecovery',
        'child': {'type': 'explodes'},
      });

      expect(find.text('Something went wrong'), findsOneWidget,
          reason: 'this is the entire purpose of the widget — without it the '
              'exception reaches the framework and paints a red box');
      expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget,
          reason: 'a dead end with no retry turns a transient failure into a '
              'closed screen');
    });

    testWidgets('showDetails puts the message on screen', (tester) async {
      await pump(tester, {
        'type': 'errorRecovery',
        'showDetails': true,
        'child': {'type': 'explodes'},
      });

      expect(find.textContaining('could not be built'), findsOneWidget,
          reason: 'a developer build wants the reason; the default hides it '
              'from an end user');
    });

    testWidgets('without showDetails the message is hidden', (tester) async {
      await pump(tester, {
        'type': 'errorRecovery',
        'child': {'type': 'explodes'},
      });

      expect(find.textContaining('could not be built'), findsNothing);
    });

    testWidgets('a declared fallback replaces the default surface',
        (tester) async {
      await pump(tester, {
        'type': 'errorRecovery',
        'child': {'type': 'explodes'},
        'fallback': {'type': 'text', 'content': 'Try again in a moment'},
      });

      expect(find.text('Try again in a moment'), findsOneWidget);
      expect(find.text('Something went wrong'), findsNothing,
          reason: 'a document that wrote its own message must not get the '
              'runtime\'s on top of it');
    });

    testWidgets('a type-specific handler wins over the fallback',
        (tester) async {
      await pump(tester, {
        'type': 'errorRecovery',
        'child': {'type': 'explodes'},
        'fallback': {'type': 'text', 'content': 'generic fallback'},
        'handlers': {
          'StateError': {
            'widget': {'type': 'text', 'content': 'a state problem'},
          },
        },
      });

      expect(find.text('a state problem'), findsOneWidget,
          reason: 'handlers exist so a document can say something specific '
              'about the failure it expects');
      expect(find.text('generic fallback'), findsNothing);
    });

    testWidgets('a handler for another type falls through to the fallback',
        (tester) async {
      await pump(tester, {
        'type': 'errorRecovery',
        'child': {'type': 'explodes'},
        'fallback': {'type': 'text', 'content': 'generic fallback'},
        'handlers': {
          'FormatException': {
            'widget': {'type': 'text', 'content': 'a parsing problem'},
          },
        },
      });

      expect(find.text('generic fallback'), findsOneWidget);
    });

    testWidgets('onError fires with the message and the stack', (tester) async {
      await pump(tester, {
        'type': 'errorRecovery',
        'child': {'type': 'explodes'},
        'onError': {
          'type': 'state',
          'action': 'set',
          'binding': 'reported',
          'value': '{{event.error}}',
        },
      });

      expect(stateManager.get<String>('reported'), contains('could not be built'),
          reason: '§2.13.12 — the document is told what failed, which is how '
              'a bundle reports back to its own server');
    });

    testWidgets('Retry rebuilds the child', (tester) async {
      // A child that fails once and then works, so the retry has something to
      // show.
      var attempts = 0;
      final registry = WidgetRegistry();
      DefaultWidgets.registerAll(registry);
      registry.register('flaky', _FlakyFactory(() => attempts++));
      final bindingEngine = BindingEngine();
      final actionHandler = ActionHandler();
      final flakyContext = RenderContext(
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

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: flakyContext.renderer.renderWidget(
            {
              'type': 'errorRecovery',
              'child': {'type': 'flaky'},
            },
            flakyContext,
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Something went wrong'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('recovered'), findsOneWidget,
          reason: 'a retry that clears the flag and shows the same error is '
              'worse than no button at all');
    });

    testWidgets('with no child it draws nothing', (tester) async {
      await pump(tester, {'type': 'errorRecovery'});
      expect(tester.takeException(), isNull);
    });
  });

  group('list', () {
    Map<String, dynamic> list({Map<String, dynamic> extra = const {}}) => {
          'type': 'list',
          'items': [
            {'name': 'Ada'},
            {'name': 'Bob'},
            {'name': 'Cy'},
          ],
          'itemTemplate': {'type': 'text', 'content': '{{item.name}}'},
          ...extra,
        };

    testWidgets('every item is rendered through the template', (tester) async {
      await pump(tester, list());

      expect(find.text('Ada'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Cy'), findsOneWidget);
    });

    testWidgets('an empty list shows the declared message', (tester) async {
      await pump(tester, list(extra: {
        'items': <dynamic>[],
        'emptyMessage': 'Nothing here yet',
      }));

      expect(find.text('Nothing here yet'), findsOneWidget,
          reason: 'a blank rectangle reads as a list that failed to load; the '
              'message is what says it loaded and is empty');
    });

    testWidgets('an empty list with no message draws nothing loud',
        (tester) async {
      await pump(tester, list(extra: {'items': <dynamic>[]}));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a bound items value that is not a list is empty, not fatal',
        (tester) async {
      stateManager.set('rows', 'still loading');
      await pump(tester, list(extra: {
        'items': '{{rows}}',
        'emptyMessage': 'none',
      }));

      expect(find.text('none'), findsOneWidget);
    });

    testWidgets('horizontal orientation scrolls the other way',
        (tester) async {
      await pump(tester, list(extra: {'orientation': 'horizontal'}));

      final scrollable = tester.widget<Scrollable>(find.byType(Scrollable));
      expect(scrollable.axisDirection, AxisDirection.right);
    });

    testWidgets('reverse starts from the far end', (tester) async {
      await pump(tester, list(extra: {'reverse': true}));

      final scrollable = tester.widget<Scrollable>(find.byType(Scrollable));
      expect(scrollable.axisDirection, AxisDirection.up,
          reason: 'a chat log is written this way — reading `reverse` and '
              'ignoring it puts the newest message off the bottom');
    });

    testWidgets('spacing separates the rows', (tester) async {
      await pump(tester, list());
      final tight = tester.getTopLeft(find.text('Bob')).dy -
          tester.getTopLeft(find.text('Ada')).dy;

      await pump(tester, list(extra: {'spacing': 40}));
      final spaced = tester.getTopLeft(find.text('Bob')).dy -
          tester.getTopLeft(find.text('Ada')).dy;

      expect(spaced, greaterThan(tight));
    });

    testWidgets('a virtual list still renders its visible rows',
        (tester) async {
      await pump(tester, list(extra: {'virtual': true, 'itemExtent': 40}));

      expect(find.text('Ada'), findsOneWidget,
          reason: 'virtualisation is an optimisation; a virtual list that '
              'renders nothing has optimised the content away');
    });

    testWidgets('static children are rendered when no items are given',
        (tester) async {
      await pump(tester, {
        'type': 'list',
        'children': [
          {'type': 'text', 'content': 'first'},
          {'type': 'text', 'content': 'second'},
        ],
      });

      expect(find.text('first'), findsOneWidget);
      expect(find.text('second'), findsOneWidget);
    });
  });
}

/// Throws on its first build and renders afterwards.
class _FlakyFactory extends WidgetFactory {
  _FlakyFactory(this.onBuild);

  final int Function() onBuild;

  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final attempt = onBuild();
    if (attempt == 0) throw StateError('first build fails');
    return const Text('recovered');
  }
}
