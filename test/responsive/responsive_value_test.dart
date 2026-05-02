// Verifies the responsive override map — when a property value is a
// Map carrying any of the FormFactor keys (`compact` / `medium` /
// `expanded` / `large` / `extraLarge` / `embedded`), the binding engine
// picks the entry matching the active form factor (with smaller-class
// fallback) and recurses on the chosen branch.
//
// Spec § 5.7 / § 6 (responsive contract). The 0.3.0 release defined
// the form-factor enum but provided no DSL surface to override
// per-class values; 0.4.4 closes that gap.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

void main() {
  group('ResponsiveValue (Phase D)', () {
    Future<void> _pumpAt(WidgetTester tester, Size size,
        Map<String, dynamic> definition) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final runtime = MCPUIRuntime();
      addTearDown(runtime.destroy);
      await runtime.initialize(definition, validateSchema: false);
      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pumpAndSettle();
    }

    testWidgets('container padding picks compact value at 360w',
        (tester) async {
      await _pumpAt(tester, const Size(360, 640), {
        'type': 'page',
        'content': {
          'type': 'container',
          'padding': {
            'compact': 8,
            'expanded': 24,
          },
          'child': {'type': 'text', 'text': 'inside'},
        },
      });

      final c = tester.widget<Container>(find.byType(Container));
      expect(c.padding, const EdgeInsets.all(8));
    });

    testWidgets('container padding picks expanded value at 1280w',
        (tester) async {
      await _pumpAt(tester, const Size(1280, 800), {
        'type': 'page',
        'content': {
          'type': 'container',
          'padding': {
            'compact': 8,
            'expanded': 24,
          },
          'child': {'type': 'text', 'text': 'inside'},
        },
      });

      final c = tester.widget<Container>(find.byType(Container));
      // 1280 falls into `large` (1200-1600); fallback chain reaches
      // `expanded`, so 24 wins.
      expect(c.padding, const EdgeInsets.all(24));
    });

    testWidgets('falls back to default when no class matches',
        (tester) async {
      await _pumpAt(tester, const Size(1280, 800), {
        'type': 'page',
        'content': {
          'type': 'container',
          'padding': {
            'default': 12,
            'compact': 4,
          },
          'child': {'type': 'text', 'text': 'inside'},
        },
      });

      // 1280 → large; falls back through expanded/medium/compact;
      // compact = 4 wins (compact is reached on the way down).
      final c = tester.widget<Container>(find.byType(Container));
      expect(c.padding, const EdgeInsets.all(4));
    });

    testWidgets('default applies when only `default` is given',
        (tester) async {
      await _pumpAt(tester, const Size(1280, 800), {
        'type': 'page',
        'content': {
          'type': 'container',
          'padding': {
            'default': 9,
            'embedded': 1,
          },
          'child': {'type': 'text', 'text': 'inside'},
        },
      });

      final c = tester.widget<Container>(find.byType(Container));
      expect(c.padding, const EdgeInsets.all(9));
    });

    testWidgets('plain value (no FF keys) is left untouched',
        (tester) async {
      await _pumpAt(tester, const Size(1280, 800), {
        'type': 'page',
        'content': {
          'type': 'container',
          'padding': {'all': 16},
          'child': {'type': 'text', 'text': 'inside'},
        },
      });

      final c = tester.widget<Container>(find.byType(Container));
      expect(c.padding, const EdgeInsets.all(16));
    });
  });
}
