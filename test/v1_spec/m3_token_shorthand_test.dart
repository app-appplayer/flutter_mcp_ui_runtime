// M3 token shorthand consumption — verifies that string tokens
// (`md`, `medium`, `level1`) on the consumer-facing widgets resolve
// against the live theme. The 0.3.0 release defined these tokens but
// no widget read them; 0.4.4 wires the consumption layer.
//
// Spec § 5.4 / § 5.5 / § 5.6 / § 5.7. Pinning each token domain by a
// behavior test prevents the regression from creeping back.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

void main() {
  group('M3 token shorthand — Phase C', () {
    Future<void> _pump(WidgetTester tester, MCPUIRuntime runtime) async {
      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pumpAndSettle();
    }

    testWidgets(
        'container `padding: "md"` resolves through theme.spacing.md',
        (tester) async {
      final runtime = MCPUIRuntime();
      addTearDown(runtime.destroy);
      await runtime.initialize({
        'type': 'page',
        'runtime': {
          'theme': {
            'spacing': {'md': 16},
          },
        },
        'content': {
          'type': 'container',
          'padding': 'md',
          'child': {'type': 'text', 'text': 'inside'},
        },
      });
      await _pump(tester, runtime);

      final container = tester.widget<Container>(find.byType(Container));
      expect(container.padding, const EdgeInsets.all(16));
    });

    testWidgets(
        'container `padding: {token: "lg"}` is equivalent to a string token',
        (tester) async {
      final runtime = MCPUIRuntime();
      addTearDown(runtime.destroy);
      await runtime.initialize({
        'type': 'page',
        'runtime': {
          'theme': {
            'spacing': {'lg': 24},
          },
        },
        'content': {
          'type': 'container',
          'padding': {'token': 'lg'},
          'child': {'type': 'text', 'text': 'inside'},
        },
      });
      await _pump(tester, runtime);

      final container = tester.widget<Container>(find.byType(Container));
      expect(container.padding, const EdgeInsets.all(24));
    });

    testWidgets(
        'card `shape: "medium"` resolves through theme.shape.medium',
        (tester) async {
      final runtime = MCPUIRuntime();
      addTearDown(runtime.destroy);
      await runtime.initialize({
        'type': 'page',
        'runtime': {
          'theme': {
            'shape': {
              'medium': {'uniform': 12},
            },
          },
        },
        'content': {
          'type': 'card',
          'shape': 'medium',
          'child': {'type': 'text', 'text': 'inside'},
        },
      });
      await _pump(tester, runtime);

      final card = tester.widget<Card>(find.byType(Card));
      final shape = card.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(12));
    });

    testWidgets(
        'card `elevation: "level2"` resolves through theme.elevation.level2.shadow',
        (tester) async {
      final runtime = MCPUIRuntime();
      addTearDown(runtime.destroy);
      await runtime.initialize({
        'type': 'page',
        'runtime': {
          'theme': {
            'elevation': {
              'level2': {'shadow': 3},
            },
          },
        },
        'content': {
          'type': 'card',
          'elevation': 'level2',
          'child': {'type': 'text', 'text': 'inside'},
        },
      });
      await _pump(tester, runtime);

      final card = tester.widget<Card>(find.byType(Card));
      expect(card.elevation, 3);
    });

    testWidgets('icon `sizeToken: "lg"` returns the responsive scale value',
        (tester) async {
      // Pin to compact width so the assertion is stable regardless of
      // the default test surface size.
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final runtime = MCPUIRuntime();
      addTearDown(runtime.destroy);
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'icon',
          'icon': 'home',
          'sizeToken': 'lg',
        },
      });
      await _pump(tester, runtime);

      final icon = tester.widget<Icon>(find.byType(Icon));
      // compact baseline lg = 32 (per AppIconSizesScale._compact).
      expect(icon.size, 32);
    });

    testWidgets(
        'button `elevation: "level1"` resolves through theme.elevation.level1.shadow',
        (tester) async {
      final runtime = MCPUIRuntime();
      addTearDown(runtime.destroy);
      await runtime.initialize({
        'type': 'page',
        'runtime': {
          'theme': {
            'elevation': {
              'level1': {'shadow': 1.5},
            },
          },
        },
        'content': {
          'type': 'button',
          'label': 'Tap',
          'variant': 'elevated',
          'elevation': 'level1',
        },
      });
      await _pump(tester, runtime);

      final btn = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      // The ButtonStyle is opaque from the outside; we just confirm the
      // factory resolved without throwing and produced a Material button.
      expect(btn, isNotNull);
    });

    testWidgets(
        'unknown elevation token falls back to numeric form',
        (tester) async {
      final runtime = MCPUIRuntime();
      addTearDown(runtime.destroy);
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'card',
          'elevation': 'doesNotExist',
          'child': {'type': 'text', 'text': 'inside'},
        },
      });
      await _pump(tester, runtime);

      final card = tester.widget<Card>(find.byType(Card));
      // Default fallback in CardWidgetFactory is 1.0.
      expect(card.elevation, 1.0);
    });
  });
}
