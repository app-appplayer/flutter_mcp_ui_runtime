import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/mcp_ui_runtime.dart';

void main() {
  late MCPUIRuntime runtime;

  setUp(() {
    runtime = MCPUIRuntime(enableDebugMode: false);
  });

  tearDown(() async {
    await runtime.dispose();
  });

  group('TC-146: Enhanced TextInput with clientAction', () {
    testWidgets('Normal: textInput renders with placeholder', (tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'textInput',
          'placeholder': 'Enter text',
          'binding': 'inputValue',
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('Boundary: textInput with empty placeholder', (tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'textInput',
          'placeholder': '',
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('TC-147: Enhanced Image with protocols', () {
    testWidgets('Normal: image renders with src', (tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'image',
          'src': 'https://example.com/image.png',
          'width': 100,
          'height': 100,
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      // Image widget should be present
      expect(find.byType(Image), findsOneWidget);
    });
  });

  group('TC-148: Full rendering pipeline', () {
    testWidgets('Normal: nested widget tree renders correctly', (tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'linear',
          'direction': 'vertical',
          'children': [
            {'type': 'text', 'content': 'Header'},
            {
              'type': 'linear',
              'direction': 'horizontal',
              'children': [
                {'type': 'text', 'content': 'Left'},
                {'type': 'text', 'content': 'Right'},
              ],
            },
            {'type': 'text', 'content': 'Footer'},
          ],
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.text('Header'), findsOneWidget);
      expect(find.text('Left'), findsOneWidget);
      expect(find.text('Right'), findsOneWidget);
      expect(find.text('Footer'), findsOneWidget);
    });
  });

  group('TC-149: Binding resolution in render', () {
    testWidgets('Normal: text with binding resolves from state', (tester) async {
      await runtime.initialize({
        'type': 'page',
        'state': {
          'initial': {'username': 'John'},
        },
        'content': {
          'type': 'text',
          'content': '{{username}}',
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.text('John'), findsOneWidget);
    });

    testWidgets('Boundary: unresolvable binding renders as-is or empty', (tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'text',
          'content': '{{nonexistent}}',
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      // Should render without crashing
      expect(find.byType(Text), findsWidgets);
    });
  });

  group('TC-150: Recursive child rendering', () {
    testWidgets('Normal: deeply nested children render', (tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'box',
          'child': {
            'type': 'box',
            'child': {
              'type': 'box',
              'child': {
                'type': 'text',
                'content': 'Deep',
              },
            },
          },
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.text('Deep'), findsOneWidget);
    });
  });

  group('TC-151: Event handler wrapping', () {
    testWidgets('Normal: button with click action renders interactive', (tester) async {
      await runtime.initialize({
        'type': 'page',
        'state': {
          'initial': {'counter': 0},
        },
        'content': {
          'type': 'button',
          'label': 'Increment',
          'onTap': {
            'type': 'state',
            'path': 'counter',
            'value': 1,
          },
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.text('Increment'), findsOneWidget);
      // Button should be tappable
      await tester.tap(find.text('Increment'));
      await tester.pump();
    });
  });
}
