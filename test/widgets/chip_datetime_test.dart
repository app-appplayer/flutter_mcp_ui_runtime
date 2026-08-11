// `chip` in both variants, and `dateTimePicker` — the widget that exists so an
// author does not have to recombine a date and a time themselves.
//
// The recombination is where a time zone gets lost, so what the picker writes
// back is the whole point: one instant, one binding, in a shape a server can
// parse.

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
    await tester.pumpAndSettle();
  }

  group('chip', () {
    testWidgets('a tap and a delete each reach their action', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'chip',
        'label': 'Urgent',
        'deleteIcon': 'close',
        'onPressed': <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'pressed',
          'value': true,
        },
        'onDeleted': <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'deleted',
          'value': true,
        },
      });

      await tester.tap(find.text('Urgent'));
      await tester.pumpAndSettle();
      expect(stateManager.get('pressed'), isTrue);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(stateManager.get('deleted'), isTrue,
          reason: 'the delete affordance is the only way a user removes a '
              'filter chip; a handler that never fires leaves it stuck');
    });

    testWidgets('the outlined variant carries a border and no fill',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'chip',
        'label': 'Urgent',
        'variant': 'outlined',
        'side': <String, dynamic>{'color': '#FF0000', 'width': 2},
        'onPressed': <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'pressed',
          'value': true,
        },
      });

      final chip = tester.widget<RawChip>(find.byType(RawChip));
      expect(chip.backgroundColor, Colors.transparent);
      expect(chip.side!.color, const Color(0xFFFF0000));
      expect(chip.side!.width, 2);

      await tester.tap(find.text('Urgent'));
      await tester.pumpAndSettle();
      expect(stateManager.get('pressed'), isTrue);
    });

    testWidgets('an outlined chip with no side declared still has one',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'chip',
        'label': 'Urgent',
        'variant': 'outlined',
      });

      expect(tester.widget<RawChip>(find.byType(RawChip)).side, isNotNull,
          reason: 'an outlined chip with no outline is a filled chip');
    });

    testWidgets('an avatar may be an initial, an icon or an image',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'chip',
        'label': 'Ada',
        'avatar': <String, dynamic>{'text': 'ada'},
      });
      expect(find.text('A'), findsOneWidget,
          reason: 'the initial is upper-cased, which is what an avatar reads '
              'like everywhere else');

      await pump(tester, <String, dynamic>{
        'type': 'chip',
        'label': 'Home',
        'avatar': <String, dynamic>{'icon': 'home'},
      });
      expect(find.byIcon(Icons.home), findsOneWidget,
          reason: 'the local icon table answered `close` for every name it '
              'did not know, so an avatar icon drew a ✕');

    });

    testWidgets('an avatar image is loaded from its url', (tester) async {
      // `flutter_test` answers every network request with a 400, so the load
      // failure is expected here and says nothing about the widget — what is
      // being read is which provider the avatar was given.
      final imageErrors = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = imageErrors.add;
      addTearDown(() => FlutterError.onError = previous);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: context.renderer.renderWidget(<String, dynamic>{
            'type': 'chip',
            'label': 'Ada',
            'avatar': <String, dynamic>{
              'image': 'https://example.com/a.png',
            },
          }, context),
        ),
      ));

      final avatar =
          tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect((avatar.backgroundImage! as NetworkImage).url,
          'https://example.com/a.png');
    });

    testWidgets('an avatar with none of the three draws nothing',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'chip',
        'label': 'Ada',
        'avatar': <String, dynamic>{'colour': 'red'},
      });

      expect(find.byType(CircleAvatar), findsNothing);
    });

    testWidgets('each declared shape is built', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'chip',
        'label': 'Urgent',
        'shape': <String, dynamic>{'type': 'stadium'},
      });
      expect(tester.widget<RawChip>(find.byType(RawChip)).shape,
          isA<StadiumBorder>());

      await pump(tester, <String, dynamic>{
        'type': 'chip',
        'label': 'Urgent',
        'shape': <String, dynamic>{'type': 'rounded', 'radius': 10},
      });
      expect(tester.widget<RawChip>(find.byType(RawChip)).shape,
          isA<RoundedRectangleBorder>());

      await pump(tester, <String, dynamic>{
        'type': 'chip',
        'label': 'Urgent',
        'shape': <String, dynamic>{'type': 'beveled'},
      });
      expect(tester.widget<RawChip>(find.byType(RawChip)).shape, isNull);
    });

    testWidgets('a selected chip takes a tint even with no colour declared',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'chip',
        'label': 'Urgent',
        'selected': true,
      });

      expect(tester.widget<RawChip>(find.byType(RawChip)).selectedColor,
          isNotNull,
          reason: 'a selected chip that looks identical to an unselected one '
              'tells the user nothing about what is filtered');
    });
  });

  group('dateTimePicker', () {
    Map<String, dynamic> picker({Map<String, dynamic> extra = const {}}) =>
        <String, dynamic>{
          'type': 'dateTimePicker',
          'binding': 'startsAt',
          'label': 'Starts at',
          ...extra,
        };

    testWidgets('shows the bound instant, and the label', (tester) async {
      stateManager.set('startsAt', '2026-03-15T09:30:00');
      await pump(tester, picker());

      expect(find.text('Starts at'), findsOneWidget);
      expect(find.text('2026-03-15 09:30'), findsOneWidget);
    });

    testWidgets('with nothing bound it shows nothing rather than today',
        (tester) async {
      await pump(tester, picker());

      expect(find.text(''), findsWidgets,
          reason: 'showing today for an unset field makes the user believe a '
              'value was chosen');
    });

    testWidgets('an unparseable value is treated as unset', (tester) async {
      stateManager.set('startsAt', 'next Tuesday');
      await pump(tester, picker());

      expect(tester.takeException(), isNull);
    });

    testWidgets('the declared display patterns are applied', (tester) async {
      stateManager.set('startsAt', '2026-03-15T13:45:07');
      await pump(tester, picker(extra: <String, dynamic>{
        'dateFormat': 'dd/MM/yyyy',
        'timeFormat': 'hh:mm:ss a',
      }));

      expect(find.text('15/03/2026 01:45:07 PM'), findsOneWidget,
          reason: 'the patterns change only what the closed field shows; the '
              'bound value stays ISO-8601 either way');
    });

    testWidgets('a declared time zone is labelled, not converted',
        (tester) async {
      stateManager.set('startsAt', '2026-03-15T09:30:00');
      await pump(tester, picker(extra: <String, dynamic>{
        'timeZone': 'Asia/Seoul',
      }));

      expect(find.text('2026-03-15 09:30 (Asia/Seoul)'), findsOneWidget,
          reason: 'converting would need a tz database this runtime does not '
              'carry, and a silently shifted time is worse than a labelled '
              'one');
    });

    testWidgets('choosing a date and a time writes one instant back',
        (tester) async {
      stateManager.set('startsAt', '2026-03-15T09:30:00');
      await pump(tester, picker(extra: <String, dynamic>{
        'min': '2026-03-01T00:00:00',
        'max': '2026-03-31T00:00:00',
        'onChange': <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'reported',
          'value': '{{event.value}}',
        },
      }));

      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();
      await tester.tap(find.text('20'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // The time picker follows immediately, on the same instant.
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(stateManager.get<String>('startsAt'), startsWith('2026-03-20T'),
          reason: 'the date and the time are reassembled here rather than by '
              'the author — that recombination is what the widget is for');
      expect(stateManager.get('reported'), stateManager.get('startsAt'));
    });

    testWidgets('cancelling the date leaves the value alone', (tester) async {
      stateManager.set('startsAt', '2026-03-15T09:30:00');
      await pump(tester, picker());

      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(stateManager.get('startsAt'), '2026-03-15T09:30:00');
    });

    testWidgets('cancelling the time leaves the value alone', (tester) async {
      stateManager.set('startsAt', '2026-03-15T09:30:00');
      await pump(tester, picker());

      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(stateManager.get('startsAt'), '2026-03-15T09:30:00',
          reason: 'a half-chosen instant is not an instant; writing the date '
              'alone would move the appointment to midnight');
    });

    testWidgets('a minute interval snaps the chosen time down',
        (tester) async {
      stateManager.set('startsAt', '2026-03-15T09:07:00');
      await pump(tester, picker(extra: <String, dynamic>{
        'minuteInterval': 15,
      }));

      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(stateManager.get<String>('startsAt'), contains('T09:00'),
          reason: 'a declared interval that is not applied lets a booking '
              'land between the slots the server accepts');
    });

    testWidgets('a disabled picker does not open', (tester) async {
      await pump(tester, picker(extra: <String, dynamic>{'enabled': false}));

      await tester.tap(find.byType(InkWell), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('OK'), findsNothing);
    });

    testWidgets('a value declared inline is read when there is no binding',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'dateTimePicker',
        'value': '2026-03-15T09:30:00',
      });

      expect(find.text('2026-03-15 09:30'), findsOneWidget);
    });
  });
}
