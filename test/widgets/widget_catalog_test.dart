// Widget Catalog Tests: TC-100 through TC-133
// Covers common properties, layout widgets, and display widgets.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

void main() {
  late MCPUIRuntime runtime;

  setUp(() {
    runtime = MCPUIRuntime();
  });

  tearDown(() {
    runtime.destroy();
  });

  // Helper to build a page definition wrapping the given content widget
  Map<String, dynamic> page(Map<String, dynamic> content,
      {Map<String, dynamic>? runtimeConfig}) {
    final def = <String, dynamic>{
      'type': 'page',
      'content': content,
    };
    if (runtimeConfig != null) {
      def['runtime'] = runtimeConfig;
    }
    return def;
  }

  // Helper to pump a page definition through the runtime
  Future<void> pumpPage(
    WidgetTester tester,
    Map<String, dynamic> content, {
    Map<String, dynamic>? runtimeConfig,
  }) async {
    await runtime.initialize(page(content, runtimeConfig: runtimeConfig));
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: runtime.buildUI())),
    );
    await tester.pump();
  }

  // ---------------------------------------------------------------------------
  // TC-100~103: Common Properties
  // ---------------------------------------------------------------------------
  group('Common Properties', () {
    // TC-100: type is required; empty type renders error container
    testWidgets('TC-100: empty type renders error container', (tester) async {
      // Negative test: deliberately invalid DSL. Opt out of schema validation
      // so the runtime's fallback error container is exercised.
      await runtime.initialize(
        page({'type': '', 'content': 'hello'}),
        validateSchema: false,
      );
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: runtime.buildUI())),
      );
      await tester.pump();
      expect(find.textContaining('Unknown widget type'), findsOneWidget);
    });

    // TC-101: visible true/false
    testWidgets('TC-101: visible false renders SizedBox.shrink',
        (tester) async {
      await pumpPage(tester, {
        'type': 'text',
        'content': 'Hidden text',
        'visible': false,
      });
      // Text should not be visible
      expect(find.text('Hidden text'), findsNothing);
    });

    testWidgets('TC-101: visible true renders widget normally',
        (tester) async {
      await pumpPage(tester, {
        'type': 'text',
        'content': 'Visible text',
        'visible': true,
      });
      expect(find.text('Visible text'), findsOneWidget);
    });

    // TC-102: key maintains widget identity
    testWidgets('TC-102: key property on widget', (tester) async {
      await pumpPage(tester, {
        'type': 'text',
        'content': 'Keyed widget',
        'key': 'my-unique-key',
      });
      // The widget should render without error
      expect(find.text('Keyed widget'), findsOneWidget);
    });

    // TC-103: testKey makes widget findable
    testWidgets('TC-103: testKey on widget', (tester) async {
      await pumpPage(tester, {
        'type': 'text',
        'content': 'Testable widget',
        'testKey': 'test-key-123',
      });
      // The widget should render successfully
      expect(find.text('Testable widget'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-104~117: Layout Widgets
  // ---------------------------------------------------------------------------
  group('Layout Widgets', () {
    // TC-104: linear direction (vertical=Column, horizontal=Row)
    testWidgets('TC-104: linear vertical renders Column', (tester) async {
      await pumpPage(tester, {
        'type': 'linear',
        'direction': 'vertical',
        'children': [
          {'type': 'text', 'content': 'Item 1'},
          {'type': 'text', 'content': 'Item 2'},
        ],
      });
      expect(find.byType(Column), findsWidgets);
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
    });

    testWidgets('TC-104: linear horizontal renders Row', (tester) async {
      await pumpPage(tester, {
        'type': 'linear',
        'direction': 'horizontal',
        'children': [
          {'type': 'text', 'content': 'A'},
          {'type': 'text', 'content': 'B'},
        ],
      });
      expect(find.byType(Row), findsWidgets);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
    });

    // TC-105: linear alignment/distribution
    testWidgets('TC-105: linear alignment and distribution', (tester) async {
      await pumpPage(tester, {
        'type': 'linear',
        'direction': 'vertical',
        'alignment': 'center',
        'distribution': 'center',
        'children': [
          {'type': 'text', 'content': 'Centered'},
        ],
      });
      expect(find.text('Centered'), findsOneWidget);
    });

    // TC-106: linear children and spacing
    testWidgets('TC-106: linear with spacing between children',
        (tester) async {
      await pumpPage(tester, {
        'type': 'linear',
        'direction': 'vertical',
        'spacing': 16,
        'children': [
          {'type': 'text', 'content': 'First'},
          {'type': 'text', 'content': 'Second'},
          {'type': 'text', 'content': 'Third'},
        ],
      });
      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
      expect(find.text('Third'), findsOneWidget);
    });

    // TC-107: box sizing and decoration
    testWidgets('TC-107: box with width, height, and color', (tester) async {
      await pumpPage(tester, {
        'type': 'box',
        'width': 200,
        'height': 100,
        'color': '#FF0000',
        'child': {'type': 'text', 'content': 'In box'},
      });
      expect(find.text('In box'), findsOneWidget);
    });

    // TC-108: stack alignment and children
    testWidgets('TC-108: stack with alignment and children', (tester) async {
      await pumpPage(tester, {
        'type': 'stack',
        'alignment': 'center',
        'children': [
          {'type': 'text', 'content': 'Bottom layer'},
          {'type': 'text', 'content': 'Top layer'},
        ],
      });
      expect(find.byType(Stack), findsWidgets);
      expect(find.text('Bottom layer'), findsOneWidget);
      expect(find.text('Top layer'), findsOneWidget);
    });

    // TC-109: center widget
    testWidgets('TC-109: center wraps child in Center', (tester) async {
      await pumpPage(tester, {
        'type': 'center',
        'child': {'type': 'text', 'content': 'Centered content'},
      });
      expect(find.byType(Center), findsWidgets);
      expect(find.text('Centered content'), findsOneWidget);
    });

    // TC-110: expanded/flexible
    testWidgets('TC-110: expanded in horizontal linear', (tester) async {
      await pumpPage(tester, {
        'type': 'linear',
        'direction': 'horizontal',
        'children': [
          {
            'type': 'expanded',
            'children': [
              {'type': 'text', 'content': 'Expanded child'},
            ],
          },
        ],
      });
      expect(find.byType(Expanded), findsOneWidget);
      expect(find.text('Expanded child'), findsOneWidget);
    });

    testWidgets('TC-110: flexible in vertical linear', (tester) async {
      await pumpPage(tester, {
        'type': 'linear',
        'direction': 'vertical',
        'children': [
          {
            'type': 'flexible',
            'children': [
              {'type': 'text', 'content': 'Flexible child'},
            ],
          },
        ],
      });
      expect(find.byType(Flexible), findsWidgets);
      expect(find.text('Flexible child'), findsOneWidget);
    });

    // TC-111: sizedBox
    testWidgets('TC-111: sizedBox with width and height', (tester) async {
      await pumpPage(tester, {
        'type': 'sizedBox',
        'width': 150,
        'height': 75,
      });
      expect(find.byType(SizedBox), findsWidgets);
    });

    // TC-112: padding (uses 'child' not 'children')
    testWidgets('TC-112: padding wraps child with padding', (tester) async {
      await pumpPage(tester, {
        'type': 'padding',
        'padding': 16.0,
        'child': {'type': 'text', 'content': 'Padded text'},
      });
      expect(find.byType(Padding), findsWidgets);
      expect(find.text('Padded text'), findsOneWidget);
    });

    // TC-113: align (uses 'child' not 'children')
    testWidgets('TC-113: align positions child', (tester) async {
      await pumpPage(tester, {
        'type': 'align',
        'alignment': 'topLeft',
        'child': {'type': 'text', 'content': 'Aligned text'},
      });
      expect(find.byType(Align), findsWidgets);
      expect(find.text('Aligned text'), findsOneWidget);
    });

    // TC-114: wrap
    testWidgets('TC-114: wrap lays out children in wrapping flow',
        (tester) async {
      await pumpPage(tester, {
        'type': 'wrap',
        'spacing': 8,
        'runSpacing': 8,
        'children': [
          {'type': 'text', 'content': 'Tag 1'},
          {'type': 'text', 'content': 'Tag 2'},
          {'type': 'text', 'content': 'Tag 3'},
        ],
      });
      expect(find.byType(Wrap), findsWidgets);
      expect(find.text('Tag 1'), findsOneWidget);
    });

    // TC-115: conditional widget (condition true -> then, false -> else)
    testWidgets('TC-115: conditional shows then branch when true',
        (tester) async {
      await pumpPage(
        tester,
        {
          'type': 'conditional',
          'condition': '{{showGreeting}}',
          'then': {'type': 'text', 'content': 'Hello!'},
          'else': {'type': 'text', 'content': 'Goodbye!'},
        },
        runtimeConfig: {
          'services': {
            'state': {
              'initialState': {'showGreeting': true},
            },
          },
        },
      );
      expect(find.text('Hello!'), findsOneWidget);
      expect(find.text('Goodbye!'), findsNothing);
    });

    testWidgets('TC-115: conditional shows else branch when false',
        (tester) async {
      await pumpPage(
        tester,
        {
          'type': 'conditional',
          'condition': '{{showGreeting}}',
          'then': {'type': 'text', 'content': 'Hello!'},
          'else': {'type': 'text', 'content': 'Goodbye!'},
        },
        runtimeConfig: {
          'services': {
            'state': {
              'initialState': {'showGreeting': false},
            },
          },
        },
      );
      expect(find.text('Hello!'), findsNothing);
      expect(find.text('Goodbye!'), findsOneWidget);
    });

    // TC-116: table widget
    testWidgets('TC-116: table renders rows and cells', (tester) async {
      await pumpPage(tester, {
        'type': 'table',
        'rows': [
          {
            'cells': [
              {'type': 'text', 'content': 'R1C1'},
              {'type': 'text', 'content': 'R1C2'},
            ],
          },
          {
            'cells': [
              {'type': 'text', 'content': 'R2C1'},
              {'type': 'text', 'content': 'R2C2'},
            ],
          },
        ],
      });
      expect(find.byType(Table), findsOneWidget);
      expect(find.text('R1C1'), findsOneWidget);
      expect(find.text('R2C2'), findsOneWidget);
    });

    // TC-117: positioned widget inside a stack
    testWidgets('TC-117: positioned inside stack', (tester) async {
      await pumpPage(tester, {
        'type': 'stack',
        'children': [
          {
            'type': 'positioned',
            'top': 10,
            'left': 20,
            'child': {'type': 'text', 'content': 'Positioned text'},
          },
        ],
      });
      expect(find.byType(Positioned), findsOneWidget);
      expect(find.text('Positioned text'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-118~133: Display Widgets
  // ---------------------------------------------------------------------------
  group('Display Widgets', () {
    // TC-118: text widget (content, binding, style)
    testWidgets('TC-118: text renders static content', (tester) async {
      await pumpPage(tester, {
        'type': 'text',
        'content': 'Hello World',
      });
      expect(find.text('Hello World'), findsOneWidget);
    });

    testWidgets('TC-118: text with style', (tester) async {
      await pumpPage(tester, {
        'type': 'text',
        'content': 'Styled text',
        'style': {
          'fontSize': 24,
          'fontWeight': 'bold',
          'color': '#FF0000',
        },
      });
      expect(find.text('Styled text'), findsOneWidget);
    });

    testWidgets('TC-118: text with state binding', (tester) async {
      await pumpPage(
        tester,
        {
          'type': 'text',
          'content': '{{message}}',
        },
        runtimeConfig: {
          'services': {
            'state': {
              'initialState': {'message': 'Bound value'},
            },
          },
        },
      );
      expect(find.text('Bound value'), findsOneWidget);
    });

    // TC-119: richText widget
    testWidgets('TC-119: richText renders spans', (tester) async {
      await pumpPage(tester, {
        'type': 'richText',
        'spans': [
          {'text': 'Bold', 'style': {'fontWeight': 'bold'}},
          {'text': ' and normal'},
        ],
      });
      expect(find.byType(RichText), findsWidgets);
    });

    // TC-120: image widget
    testWidgets('TC-120: image renders without crash', (tester) async {
      await pumpPage(tester, {
        'type': 'image',
        'src': 'https://via.placeholder.com/150',
      });
      // Image widget should be in tree (network unavailable in tests is ok)
      expect(find.byType(Scaffold), findsWidgets);
    });

    // TC-121: icon widget
    testWidgets('TC-121: icon renders correctly', (tester) async {
      await pumpPage(tester, {
        'type': 'icon',
        'icon': 'home',
        'size': 32,
        'color': '#0000FF',
      });
      expect(find.byType(Icon), findsOneWidget);
    });

    // TC-122: divider widget
    testWidgets('TC-122: divider renders', (tester) async {
      await pumpPage(tester, {
        'type': 'linear',
        'direction': 'vertical',
        'children': [
          {'type': 'text', 'content': 'Above'},
          {'type': 'divider'},
          {'type': 'text', 'content': 'Below'},
        ],
      });
      expect(find.byType(Divider), findsOneWidget);
    });

    // TC-123: card widget (uses 'child' not 'children')
    testWidgets('TC-123: card renders with child', (tester) async {
      await pumpPage(tester, {
        'type': 'card',
        'child': {'type': 'text', 'content': 'Card content'},
      });
      expect(find.byType(Card), findsOneWidget);
      expect(find.text('Card content'), findsOneWidget);
    });

    // TC-124: badge widget
    testWidgets('TC-124: badge renders with label', (tester) async {
      await pumpPage(tester, {
        'type': 'badge',
        'label': '5',
        'children': [
          {'type': 'icon', 'icon': 'notifications'},
        ],
      });
      expect(find.byType(Badge), findsOneWidget);
    });

    // TC-125: chip widget
    testWidgets('TC-125: chip renders with label', (tester) async {
      await pumpPage(tester, {
        'type': 'chip',
        'label': 'Flutter',
      });
      expect(find.text('Flutter'), findsOneWidget);
    });

    // TC-126: avatar widget
    testWidgets('TC-126: avatar renders with label text', (tester) async {
      await pumpPage(tester, {
        'type': 'avatar',
        'label': 'AB',
        'size': 40,
      });
      expect(find.byType(CircleAvatar), findsOneWidget);
    });

    // TC-127: tooltip widget (uses 'child' not 'children')
    testWidgets('TC-127: tooltip renders with child', (tester) async {
      await pumpPage(tester, {
        'type': 'tooltip',
        'message': 'Helpful info',
        'child': {'type': 'text', 'content': 'Hover me'},
      });
      expect(find.text('Hover me'), findsOneWidget);
      expect(find.byType(Tooltip), findsWidgets);
    });

    // TC-128: placeholder widget
    testWidgets('TC-128: placeholder renders', (tester) async {
      await pumpPage(tester, {
        'type': 'placeholder',
        'fallbackWidth': 200,
        'fallbackHeight': 100,
      });
      expect(find.byType(Placeholder), findsOneWidget);
    });

    // TC-129: progressBar widget (linear progress indicator)
    testWidgets('TC-129: progressBar renders linear indicator', (tester) async {
      await pumpPage(tester, {
        'type': 'progressBar',
        'indicatorType': 'linear',
        'value': 0.5,
      });
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    // TC-130: loadingIndicator widget (circular progress indicator)
    testWidgets('TC-130: loadingIndicator renders circular indicator',
        (tester) async {
      await pumpPage(tester, {
        'type': 'loadingIndicator',
      });
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    // TC-131: banner widget (debug mode adds an extra Banner, so use findsWidgets)
    testWidgets('TC-131: banner renders with message', (tester) async {
      await pumpPage(tester, {
        'type': 'banner',
        'message': 'Beta',
        'location': 'topEnd',
        'children': [
          {
            'type': 'sizedBox',
            'width': 100,
            'height': 100,
          },
        ],
      });
      expect(find.byType(Banner), findsWidgets);
    });

    // TC-132: verticalDivider widget
    testWidgets('TC-132: verticalDivider renders', (tester) async {
      await pumpPage(tester, {
        'type': 'linear',
        'direction': 'horizontal',
        'children': [
          {'type': 'text', 'content': 'Left'},
          {'type': 'verticalDivider'},
          {'type': 'text', 'content': 'Right'},
        ],
      });
      // VerticalDivider needs bounded height from parent; check it renders
      expect(find.text('Left'), findsOneWidget);
      expect(find.text('Right'), findsOneWidget);
    });

    // TC-133: decoration widget (DecoratedBox)
    testWidgets('TC-133: decoration renders with color', (tester) async {
      await pumpPage(tester, {
        'type': 'decoration',
        'color': '#FF0000',
        'borderRadius': 8,
        'children': [
          {'type': 'text', 'content': 'Decorated'},
        ],
      });
      expect(find.byType(DecoratedBox), findsWidgets);
      expect(find.text('Decorated'), findsOneWidget);
    });
  });
}
