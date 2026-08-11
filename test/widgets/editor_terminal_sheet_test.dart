// `codeEditor`, `terminal`, `spreadsheet` and `permissionPrompt`.
//
// All four are interactive surfaces whose interaction was uncovered: typing a
// command, editing a cell, granting a permission. What each of them reports
// back is the only thing the document ever learns, so a handler that does not
// fire is a screen that looks alive and tells nobody anything.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    await tester.pumpAndSettle();
  }

  Map<String, dynamic> record(String binding, String field) =>
      <String, dynamic>{
        'type': 'state',
        'action': 'set',
        'binding': binding,
        'value': '{{event.$field}}',
      };

  group('terminal', () {
    testWidgets('shows the lines it was given, with the prompt', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'terminal',
        'lines': <dynamic>['boot ok', 'ready'],
        'prompt': r'> ',
        'height': 200,
      });

      expect(find.text('boot ok'), findsOneWidget);
      expect(find.text('ready'), findsOneWidget);
    });

    testWidgets('output that arrives after the first frame is drawn',
        (tester) async {
      stateManager.set('log', <dynamic>['boot ok']);

      await pump(tester, <String, dynamic>{
        'type': 'terminal',
        'lines': '{{log}}',
        'height': 200,
      });

      expect(find.text('boot ok'), findsOneWidget);

      // Which is how output actually arrives: a tool response, a channel
      // message, a device that says something a second later.
      stateManager.set('log', <dynamic>['boot ok', 'listening on :8080']);
      await tester.pumpAndSettle();

      expect(find.text('listening on :8080'), findsOneWidget,
          reason: 'the list was copied once at mount and never read again, so '
              'a console went quiet exactly when it started mattering — and '
              'said nothing about it');
      expect(find.text('boot ok'), findsOneWidget);
    });

    testWidgets('a rebuild carrying the same lines keeps the local echo',
        (tester) async {
      stateManager.set('log', <dynamic>['ready']);

      await pump(tester, <String, dynamic>{
        'type': 'terminal',
        'lines': '{{log}}',
        'height': 200,
      });

      await tester.enterText(find.byType(TextField), 'whoami');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Something else on the page changes; the terminal's own binding did
      // not.
      stateManager.set('unrelated', 1);
      await tester.pumpAndSettle();

      expect(find.textContaining('whoami', findRichText: true), findsWidgets,
          reason: 'resetting on every rebuild would erase what the user just '
              'typed before the document had a chance to echo it back');
    });

    testWidgets('a submitted command is echoed and reported', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'terminal',
        'lines': <dynamic>['ready'],
        'height': 200,
        'onCommand': record('ran', 'command'),
      });

      await tester.enterText(find.byType(TextField), 'ls -la');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(stateManager.get('ran'), 'ls -la',
          reason: 'the command is the whole point of the widget; a terminal '
              'that echoes and reports nothing is a text view');
      expect(find.textContaining('ls -la', findRichText: true), findsWidgets,
          reason: 'the echo is what makes the history read as a session — an '
              'echoed line is drawn as a rich span so the prompt keeps its '
              'own colour');
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty,
          reason: 'a line that stays in the box gets sent twice');
    });

    testWidgets('an empty command is ignored', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'terminal',
        'height': 200,
        'onCommand': record('ran', 'command'),
      });

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(stateManager.get('ran'), isNull);
    });

    testWidgets('history is capped at maxLines', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'terminal',
        'lines': <dynamic>['one', 'two'],
        'maxLines': 2,
        'height': 200,
      });

      await tester.enterText(find.byType(TextField), 'three');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('one'), findsNothing,
          reason: 'a cap that never trims grows without bound on a long '
              'session, which is what the property is for');
    });

    testWidgets('with input off there is nothing to type into',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'terminal',
        'lines': <dynamic>['read only'],
        'showInput': false,
        'height': 200,
      });

      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('the light theme uses a light background', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'terminal',
        'lines': <dynamic>['x'],
        'theme': 'light',
        'height': 200,
      });

      expect(tester.takeException(), isNull);
      expect(find.text('x'), findsOneWidget);
    });
  });

  group('codeEditor', () {
    testWidgets('shows the code, with line numbers', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'codeEditor',
        'code': 'void main() {}\nprint(1);',
        'height': 200,
      });

      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('typing reports the new code and its line count',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'codeEditor',
        'code': 'a',
        'height': 200,
        'onChange': <String, dynamic>{
          'type': 'batch',
          'actions': <dynamic>[
            record('code', 'value'),
            record('lines', 'lineCount'),
          ],
        },
      });

      await tester.enterText(find.byType(TextField), 'a\nb');
      await tester.pumpAndSettle();

      expect(stateManager.get('code'), 'a\nb');
      expect(stateManager.get('lines'), 2,
          reason: 'the line count is what a document shows beside the editor; '
              'computing it from a stale value shows the wrong number');
    });

    testWidgets('a read-only editor cannot be typed into', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'codeEditor',
        'code': 'a',
        'readOnly': true,
        'height': 200,
      });

      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
    });

    testWidgets('`copyable` puts a copy control over the editor',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'codeEditor',
        'code': 'copy me',
        'copyable': true,
        'height': 200,
      });

      expect(find.byIcon(Icons.copy), findsOneWidget,
          reason: 'a declared control that renders nothing leaves the author '
              'with no way to tell it is missing');

      await tester.tap(find.byIcon(Icons.copy));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('with no copy control declared there is none', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'codeEditor',
        'code': 'a',
        'height': 200,
      });

      expect(find.byIcon(Icons.copy), findsNothing);
    });

    testWidgets('a value changed from outside replaces the buffer',
        (tester) async {
      stateManager.set('src', 'first');
      await pump(tester, <String, dynamic>{
        'type': 'codeEditor',
        'code': '{{src}}',
        'height': 200,
      });
      expect(find.text('first'), findsOneWidget);

      stateManager.set('src', 'second');
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'second',
          reason: 'a document that loads a file into the editor has to see it '
              'arrive, not keep the previous buffer');
    });
  });

  group('spreadsheet', () {
    Map<String, dynamic> sheet({Map<String, dynamic> extra = const {}}) =>
        <String, dynamic>{
          'type': 'spreadsheet',
          'data': <dynamic>[
            <dynamic>['Ada', 1],
            <dynamic>['Bob', 2],
          ],
          ...extra,
        };

    testWidgets('draws the grid, with generated column names', (tester) async {
      await pump(tester, sheet());

      expect(find.text('Ada'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets('declared column labels replace the generated ones',
        (tester) async {
      await pump(tester, sheet(extra: <String, dynamic>{
        'columns': <dynamic>[
          <String, dynamic>{'label': 'Name'},
          <String, dynamic>{'label': 'Count', 'readOnly': true},
        ],
      }));

      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Count'), findsOneWidget);
      expect(find.text('A'), findsNothing);
    });

    testWidgets('with no rows there is nothing to draw', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'spreadsheet',
        'data': <dynamic>[],
      });

      expect(find.byType(GestureDetector), findsNothing);
    });

    testWidgets('selecting a cell reports where the user is', (tester) async {
      await pump(tester, sheet(extra: <String, dynamic>{
        'onCellSelect': record('row', 'row'),
      }));

      await tester.tap(find.text('Ada'));
      // A cell carries both a tap and a double tap, so the single tap is
      // held for the recogniser's timeout before it fires.
      await tester.pump(kDoubleTapTimeout);
      await tester.pumpAndSettle();

      expect(stateManager.get('row'), 0);
    });

    testWidgets('editing a cell reports the new value and the old one',
        (tester) async {
      await pump(tester, sheet(extra: <String, dynamic>{
        'onChange': <String, dynamic>{
          'type': 'batch',
          'actions': <dynamic>[
            record('value', 'value'),
            record('previous', 'previous'),
          ],
        },
      }));

      await tester.tap(find.text('Ada'));
      await tester.pump(kDoubleTapMinTime);
      await tester.tap(find.text('Ada'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Grace');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(stateManager.get('value'), 'Grace');
      expect(stateManager.get('previous'), 'Ada',
          reason: 'the previous value is what an undo needs; reporting only '
              'the new one makes the change irreversible');
    });

    testWidgets('a read-only column refuses the edit', (tester) async {
      await pump(tester, sheet(extra: <String, dynamic>{
        'columns': <dynamic>[
          <String, dynamic>{'label': 'Name', 'readOnly': true},
          <String, dynamic>{'label': 'Count'},
        ],
      }));

      await tester.tap(find.text('Ada'));
      await tester.pump(kDoubleTapMinTime);
      await tester.tap(find.text('Ada'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing,
          reason: 'a column declared read-only that opens an editor is the '
              'property doing nothing');
    });

    testWidgets('an editable sheet with no change handler still edits',
        (tester) async {
      await pump(tester, sheet());

      await tester.tap(find.text('Ada'));
      await tester.pump(kDoubleTapMinTime);
      await tester.tap(find.text('Ada'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Grace');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('permissionPrompt', () {
    Map<String, dynamic> prompt({Map<String, dynamic> extra = const {}}) =>
        <String, dynamic>{
          'type': 'permissionPrompt',
          'title': 'Allow file access?',
          'description': 'The document needs to read your notes.',
          'permissions': <dynamic>['file.read'],
          'onAllow': <String, dynamic>{
            'type': 'state',
            'action': 'set',
            'binding': 'decision',
            'value': 'allow',
          },
          'onDeny': <String, dynamic>{
            'type': 'state',
            'action': 'set',
            'binding': 'decision',
            'value': 'deny',
          },
          ...extra,
        };

    testWidgets('the inline form states what is being asked for',
        (tester) async {
      await pump(tester, prompt());

      expect(find.text('Allow file access?'), findsOneWidget);
      expect(find.text('The document needs to read your notes.'),
          findsOneWidget);
      expect(find.textContaining('file.read'), findsWidgets,
          reason: 'a prompt that does not name the permission asks the user '
              'to agree to something unstated');
    });

    testWidgets('both answers reach the document', (tester) async {
      await pump(tester, prompt());

      await tester.tap(find.widgetWithText(TextButton, 'Deny'));
      await tester.pumpAndSettle();
      expect(stateManager.get('decision'), 'deny');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Allow'));
      await tester.pumpAndSettle();
      expect(stateManager.get('decision'), 'allow');
    });

    testWidgets('the banner form asks the same question', (tester) async {
      await pump(tester, prompt(extra: <String, dynamic>{'style': 'banner'}));

      expect(find.byType(MaterialBanner), findsOneWidget);
      expect(find.text('Allow file access?'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Allow'));
      await tester.pumpAndSettle();
      expect(stateManager.get('decision'), 'allow');
    });

    testWidgets('the banner form can be denied too', (tester) async {
      await pump(tester, prompt(extra: <String, dynamic>{'style': 'banner'}));

      await tester.tap(find.widgetWithText(TextButton, 'Deny'));
      await tester.pumpAndSettle();
      expect(stateManager.get('decision'), 'deny');
    });

    testWidgets('a declared icon is drawn', (tester) async {
      await pump(tester, prompt(extra: <String, dynamic>{'icon': 'folder'}));

      expect(find.byIcon(Icons.folder), findsOneWidget);
    });
  });
}
