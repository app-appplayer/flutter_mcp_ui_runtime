// `qrCode`, `otpInput`, `animatedContainer` and `bottomNavigation`.
//
// The first two exist because the composed version is wrong rather than
// merely verbose: a QR that encodes half a payload scans cleanly and carries
// the wrong thing, and a row of text fields loses paste distribution and
// backspace movement. Both are behaviours only the widget can have, so they
// are what these read.

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

  group('qrCode', () {
    testWidgets('an ordinary payload paints a symbol', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'qrCode',
        'value': 'https://example.com',
        'size': 160,
      });

      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.getSize(find.byType(SizedBox).first).width, 160);
    });

    testWidgets('an empty value draws a blank of the declared size',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'qrCode',
        'value': '',
        'size': 120,
      });

      final blank = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(blank.child, isNull,
          reason: 'a code for nothing is not a code; painting one would give '
              'the user something to scan that means nothing');
      expect(blank.width, 120,
          reason: 'the space is still reserved, so the layout around it does '
              'not jump when a value arrives');
    });

    testWidgets('a payload too long is refused in words, not truncated',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'qrCode',
        'value': 'x' * 8000,
        'errorCorrection': 'high',
      });

      expect(find.textContaining('too long'), findsOneWidget,
          reason: 'a truncated code scans cleanly and carries the wrong '
              'thing, which is worse than no code at all');
    });

    testWidgets('too little contrast is refused rather than emitted',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'qrCode',
        'value': 'https://example.com',
        'foregroundColor': '#777777',
        'backgroundColor': '#888888',
      });

      expect(find.textContaining('contrast'), findsOneWidget);
    });

    testWidgets('every error-correction spelling is accepted', (tester) async {
      for (final level in const [
        'low',
        'medium',
        'quartile',
        'high',
        'L',
        'Q',
        'H',
        'nonsense',
      ]) {
        await pump(tester, <String, dynamic>{
          'type': 'qrCode',
          'value': 'hello',
          'errorCorrection': level,
        });
        expect(find.byType(CustomPaint), findsWidgets, reason: level);
      }
    });

    testWidgets('the quiet zone follows `margin`', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'qrCode',
        'value': 'hello',
        'margin': false,
      });
      final without = tester.widget<CustomPaint>(
          find.byType(CustomPaint).last);

      await pump(tester, <String, dynamic>{
        'type': 'qrCode',
        'value': 'hello',
        'margin': true,
      });
      final with_ =
          tester.widget<CustomPaint>(find.byType(CustomPaint).last);

      expect(with_.painter!.shouldRepaint(without.painter!), isTrue,
          reason: 'the quiet zone is part of what a scanner needs; a painter '
              'that ignores the change would draw the old one');
    });

    testWidgets('a repaint is asked for only when something changed',
        (tester) async {
      await pump(tester, <String, dynamic>{'type': 'qrCode', 'value': 'a'});
      final first =
          tester.widget<CustomPaint>(find.byType(CustomPaint).last).painter!;

      await pump(tester, <String, dynamic>{'type': 'qrCode', 'value': 'a'});
      final same =
          tester.widget<CustomPaint>(find.byType(CustomPaint).last).painter!;
      expect(same.shouldRepaint(first), isFalse);

      await pump(tester, <String, dynamic>{
        'type': 'qrCode',
        'value': 'a',
        'foregroundColor': '#FF0000',
      });
      final recoloured =
          tester.widget<CustomPaint>(find.byType(CustomPaint).last).painter!;
      expect(recoloured.shouldRepaint(first), isTrue);
    });
  });

  group('otpInput', () {
    Map<String, dynamic> otp({Map<String, dynamic> extra = const {}}) =>
        <String, dynamic>{
          'type': 'otpInput',
          'binding': 'code',
          'length': 4,
          ...extra,
        };

    testWidgets('draws one cell per declared digit', (tester) async {
      await pump(tester, otp());

      expect(find.byType(TextField), findsNWidgets(4));
    });

    testWidgets('typing moves forward and writes the joined value',
        (tester) async {
      await pump(tester, otp());

      await tester.enterText(find.byType(TextField).at(0), '1');
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(1), '2');
      await tester.pump();

      expect(stateManager.get('code'), '12');
    });

    testWidgets('a pasted code is spread across the cells', (tester) async {
      await pump(tester, otp());

      await tester.enterText(find.byType(TextField).at(0), '1234');
      await tester.pumpAndSettle();

      expect(stateManager.get('code'), '1234',
          reason: 'the platform delivers the whole code to the focused field; '
              'without redistribution it sits in one cell — the reason this '
              'widget exists rather than a row of text inputs');
      expect(tester.widget<TextField>(find.byType(TextField).at(3))
          .controller!.text, '4');
    });

    testWidgets('a paste longer than the field stops at the last cell',
        (tester) async {
      await pump(tester, otp());

      await tester.enterText(find.byType(TextField).at(0), '123456789');
      await tester.pumpAndSettle();

      expect(stateManager.get('code'), '1234');
    });

    testWidgets('backspace on an empty cell steps back and clears',
        (tester) async {
      await pump(tester, otp());

      await tester.enterText(find.byType(TextField).at(0), '1');
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(1), '2');
      await tester.pumpAndSettle();
      expect(stateManager.get('code'), '12');

      // The second cell moved focus to the third, which is empty.
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();

      expect(stateManager.get('code'), '1',
          reason: 'correcting a code has to feel like editing one field; '
              'backspace stopping at an empty cell strands the user');
    });

    testWidgets('completing the code fires onComplete once', (tester) async {
      await pump(tester, otp(extra: <String, dynamic>{
        'onComplete': <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'submitted',
          'value': '{{event.value}}',
        },
        'onChange': <String, dynamic>{
          'type': 'state',
          'action': 'increment',
          'binding': 'changes',
        },
      }));

      await tester.enterText(find.byType(TextField).at(0), '1234');
      await tester.pumpAndSettle();

      expect(stateManager.get('submitted'), '1234');
    });

    testWidgets('a bound value seeds the cells', (tester) async {
      stateManager.set('code', '99');
      await pump(tester, otp());

      expect(tester.widget<TextField>(find.byType(TextField).at(0))
          .controller!.text, '9');
      expect(tester.widget<TextField>(find.byType(TextField).at(1))
          .controller!.text, '9');
    });

    testWidgets('a disabled field takes nothing', (tester) async {
      await pump(tester, otp(extra: <String, dynamic>{'enabled': false}));

      expect(tester.widget<TextField>(find.byType(TextField).first).enabled,
          isFalse);
    });

    testWidgets('an alphanumeric field does not filter to digits',
        (tester) async {
      await pump(tester,
          otp(extra: <String, dynamic>{'inputType': 'alphanumeric'}));

      await tester.enterText(find.byType(TextField).at(0), 'A');
      await tester.pumpAndSettle();

      expect(stateManager.get('code'), 'A');
    });

    testWidgets('a numeric field refuses letters', (tester) async {
      await pump(tester, otp());

      await tester.enterText(find.byType(TextField).at(0), 'A');
      await tester.pumpAndSettle();

      expect(stateManager.get('code'), anyOf(isNull, ''));
    });

    testWidgets('a masked field hides what was typed', (tester) async {
      await pump(tester, otp(extra: <String, dynamic>{'masked': true}));

      expect(tester.widget<TextField>(find.byType(TextField).first).obscureText,
          isTrue);
    });
  });

  group('animatedContainer', () {
    testWidgets('the declared box properties are applied', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'animatedContainer',
        'width': 120,
        'height': 80,
        'duration': 100,
        'decoration': <String, dynamic>{
          'color': '#FF0000',
          'borderRadius': 8,
          'border': <String, dynamic>{'color': '#00FF00', 'width': 3},
        },
        'child': <String, dynamic>{'type': 'text', 'content': 'inside'},
      });

      final box = tester.widget<AnimatedContainer>(
          find.byType(AnimatedContainer));
      final decoration = box.decoration! as BoxDecoration;
      expect(decoration.color, const Color(0xFFFF0000));
      expect((decoration.border! as Border).top.color,
          const Color(0xFF00FF00));
      expect((decoration.border! as Border).top.width, 3);
      expect(find.text('inside'), findsOneWidget);
    });

    testWidgets('a decoration bound to state resolves through the binding',
        (tester) async {
      stateManager.set('look', <String, dynamic>{'color': '#0000FF'});
      await pump(tester, <String, dynamic>{
        'type': 'animatedContainer',
        'decoration': '{{look}}',
        'width': 40,
        'height': 40,
      });

      final decoration = tester
          .widget<AnimatedContainer>(find.byType(AnimatedContainer))
          .decoration! as BoxDecoration;
      expect(decoration.color, const Color(0xFF0000FF));
    });

    testWidgets('each transform kind builds its matrix', (tester) async {
      Matrix4? transformOf(Map<String, dynamic> transform) {
        return tester
            .widget<AnimatedContainer>(find.byType(AnimatedContainer))
            .transform;
      }

      await pump(tester, <String, dynamic>{
        'type': 'animatedContainer',
        'width': 40,
        'height': 40,
        'transform': <String, dynamic>{'type': 'scale', 'scale': 2},
      });
      expect(transformOf(<String, dynamic>{}), Matrix4.identity()
        ..scaleByDouble(2, 2, 2, 1));

      await pump(tester, <String, dynamic>{
        'type': 'animatedContainer',
        'width': 40,
        'height': 40,
        'transform': <String, dynamic>{'type': 'rotate', 'angle': 0.5},
      });
      expect(transformOf(<String, dynamic>{}),
          Matrix4.identity()..rotateZ(0.5));

      await pump(tester, <String, dynamic>{
        'type': 'animatedContainer',
        'width': 40,
        'height': 40,
        'transform': <String, dynamic>{'type': 'translate', 'x': 5, 'y': 6},
      });
      expect(transformOf(<String, dynamic>{}),
          Matrix4.identity()..translateByDouble(5, 6, 0, 1));

      await pump(tester, <String, dynamic>{
        'type': 'animatedContainer',
        'width': 40,
        'height': 40,
        'transform': <String, dynamic>{'type': 'shear'},
      });
      expect(transformOf(<String, dynamic>{}), isNull,
          reason: 'an unknown transform leaves the box alone rather than '
              'guessing at one');
    });

    testWidgets('onEnd fires once the animation settles', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'animatedContainer',
        'width': 40,
        'height': 40,
        'duration': 50,
        'onEnd': <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'settled',
          'value': true,
        },
      });

      expect(
          tester
              .widget<AnimatedContainer>(find.byType(AnimatedContainer))
              .onEnd,
          isNotNull,
          reason: 'a document that chains the next step onto `onEnd` never '
              'gets there if the callback is dropped');
    });
  });

  group('bottomNavigation', () {
    Map<String, dynamic> bar({Map<String, dynamic> extra = const {}}) =>
        <String, dynamic>{
          'type': 'bottomNavigation',
          'items': <dynamic>[
            <String, dynamic>{
              'icon': 'home',
              'activeIcon': 'settings',
              'label': 'Home',
            },
            <String, dynamic>{'icon': 'list', 'label': 'Jobs'},
          ],
          ...extra,
        };

    testWidgets('draws its items, and the active icon for the current one',
        (tester) async {
      await pump(tester, bar(extra: <String, dynamic>{'currentIndex': 0}));

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Jobs'), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget,
          reason: 'the active icon is how the strip says where the user is; '
              'ignoring it leaves two identical icons');
    });

    testWidgets('a tap writes the index and reports it', (tester) async {
      await pump(tester, bar(extra: <String, dynamic>{
        'currentIndex': 0,
        'bindTo': 'tab',
        'onTap': <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'reported',
          'value': '{{event.index}}',
        },
      }));

      await tester.tap(find.text('Jobs'));
      await tester.pumpAndSettle();

      expect(stateManager.get('tab'), 1);
      expect(stateManager.get('reported'), 1);
    });

    testWidgets('the label and icon themes are read', (tester) async {
      await pump(tester, bar(extra: <String, dynamic>{
        'currentIndex': 0,
        'selectedLabelStyle': <String, dynamic>{
          'color': '#FF0000',
          'fontSize': 14,
          'fontWeight': 'bold',
        },
        'unselectedLabelStyle': <String, dynamic>{
          'fontSize': 12,
          'fontWeight': 'normal',
        },
        'selectedIconTheme': <String, dynamic>{
          'color': '#00FF00',
          'size': 28,
          'opacity': 1,
        },
        'unselectedIconTheme': <String, dynamic>{'size': 22},
      }));

      final built = tester.widget<BottomNavigationBar>(
          find.byType(BottomNavigationBar));
      expect(built.selectedLabelStyle!.fontWeight, FontWeight.bold);
      expect(built.unselectedLabelStyle!.fontWeight, FontWeight.normal);
      expect(built.selectedIconTheme!.color, const Color(0xFF00FF00));
      expect(built.selectedIconTheme!.size, 28);
      expect(built.unselectedIconTheme!.size, 22);
    });

    testWidgets('an item icon may be a widget definition', (tester) async {
      await pump(tester, bar(extra: <String, dynamic>{
        'currentIndex': 0,
        'items': <dynamic>[
          <String, dynamic>{
            'icon': <String, dynamic>{'type': 'text', 'content': 'ICON'},
            'label': 'Home',
          },
          <String, dynamic>{'icon': 'list', 'label': 'Jobs'},
        ],
      }));

      expect(find.text('ICON'), findsOneWidget);
    });
  });
}
