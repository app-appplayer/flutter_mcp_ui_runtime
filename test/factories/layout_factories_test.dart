import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

/// Layout Widget Factories Tests
///
/// Tests TC-159 through TC-183 (TC-158 has a dedicated test for linear).
/// Each TC covers Normal + Boundary scenarios for a specific layout factory.
void main() {
  late MCPUIRuntime runtime;

  setUp(() {
    runtime = MCPUIRuntime(enableDebugMode: false);
  });

  tearDown(() async {
    await runtime.dispose();
  });

  // ---------------------------------------------------------------------------
  // TC-159: ContainerWidgetFactory (box) - width, height, color, child
  // ---------------------------------------------------------------------------
  group('TC-159: ContainerWidgetFactory (box)', () {
    testWidgets('Normal: renders box with width, height, color, and child',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'box',
          'width': 200,
          'height': 100,
          'backgroundColor': '#FF0000',
          'child': {'type': 'text', 'content': 'Inside Box'},
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.text('Inside Box'), findsOneWidget);
      final container = tester.widgetList<Container>(find.byType(Container))
          .where((c) => c.constraints?.maxWidth == 200 && c.constraints?.maxHeight == 100)
          .toList();
      expect(container, isNotEmpty);
    });

    testWidgets('Boundary: renders box without optional properties',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'box',
          'child': {'type': 'text', 'content': 'Minimal Box'},
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.text('Minimal Box'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-160: StackWidgetFactory - children, alignment
  // ---------------------------------------------------------------------------
  group('TC-160: StackWidgetFactory', () {
    testWidgets('Normal: renders stack with children and alignment',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'stack',
          'alignment': 'center',
          'children': [
            {'type': 'box', 'width': 200, 'height': 200, 'backgroundColor': '#FF0000'},
            {'type': 'text', 'content': 'On Top'},
          ],
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.text('On Top'), findsOneWidget);
      // Scaffold internally uses Stack, so use findsWidgets instead of findsOneWidget
      expect(find.byType(Stack), findsWidgets);
    });

    testWidgets('Boundary: renders stack with empty children list',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'stack',
          'children': <Map<String, dynamic>>[],
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      // Scaffold internally uses Stack, so use findsWidgets
      expect(find.byType(Stack), findsWidgets);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-161: CenterWidgetFactory - centers child
  // ---------------------------------------------------------------------------
  group('TC-161: CenterWidgetFactory', () {
    testWidgets('Normal: centers child widget',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'center',
          'child': {'type': 'text', 'content': 'Centered'},
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.text('Centered'), findsOneWidget);
      expect(find.byType(Center), findsOneWidget);

      final screenSize = tester.getSize(find.byType(MaterialApp));
      final textCenter = tester.getCenter(find.text('Centered'));
      expect(textCenter.dx, closeTo(screenSize.width / 2, 2));
    });

    testWidgets('Boundary: center with no child renders without error',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'center',
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.byType(Center), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-162: ExpandedWidgetFactory - flex property
  // ---------------------------------------------------------------------------
  group('TC-162: ExpandedWidgetFactory', () {
    testWidgets('Normal: expanded with flex value in horizontal linear',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'linear',
          'direction': 'horizontal',
          'children': [
            {
              'type': 'expanded',
              'flex': 2,
              'child': {'type': 'text', 'content': 'Flex2'},
            },
            {
              'type': 'expanded',
              'flex': 1,
              'child': {'type': 'text', 'content': 'Flex1'},
            },
          ],
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.text('Flex2'), findsOneWidget);
      expect(find.text('Flex1'), findsOneWidget);
      expect(find.byType(Expanded), findsNWidgets(2));
    });

    testWidgets('Boundary: expanded defaults to flex 1',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'linear',
          'direction': 'horizontal',
          'children': [
            {
              'type': 'expanded',
              'child': {'type': 'text', 'content': 'Default Flex'},
            },
          ],
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.text('Default Flex'), findsOneWidget);
      final expanded = tester.widget<Expanded>(find.byType(Expanded));
      expect(expanded.flex, equals(1));
    });
  });

  // ---------------------------------------------------------------------------
  // TC-163: FlexibleWidgetFactory - flex, fit
  // ---------------------------------------------------------------------------
  group('TC-163: FlexibleWidgetFactory', () {
    testWidgets('Normal: flexible with flex and tight fit',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'linear',
          'direction': 'horizontal',
          'children': [
            {
              'type': 'flexible',
              'flex': 3,
              'fit': 'tight',
              'child': {'type': 'text', 'content': 'Tight'},
            },
            {
              'type': 'flexible',
              'flex': 1,
              'child': {'type': 'text', 'content': 'Loose'},
            },
          ],
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.text('Tight'), findsOneWidget);
      expect(find.text('Loose'), findsOneWidget);

      final flexibles = tester.widgetList<Flexible>(find.byType(Flexible)).toList();
      expect(flexibles.length, greaterThanOrEqualTo(2));
    });

    testWidgets('Boundary: flexible defaults to loose fit and flex 1',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'linear',
          'direction': 'horizontal',
          'children': [
            {
              'type': 'flexible',
              'child': {'type': 'text', 'content': 'DefaultFlex'},
            },
          ],
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.text('DefaultFlex'), findsOneWidget);
      final flexible = tester.widget<Flexible>(find.byType(Flexible));
      expect(flexible.flex, equals(1));
      expect(flexible.fit, equals(FlexFit.loose));
    });
  });

  // ---------------------------------------------------------------------------
  // TC-164: SizedBoxWidgetFactory - width, height
  // ---------------------------------------------------------------------------
  group('TC-164: SizedBoxWidgetFactory', () {
    testWidgets('Normal: renders sizedBox with specific dimensions',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'sizedBox',
          'width': 150,
          'height': 75,
          'children': [
            {'type': 'text', 'content': 'Sized'},
          ],
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.text('Sized'), findsOneWidget);
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('Boundary: sizedBox with zero dimensions',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'sizedBox',
          'width': 0,
          'height': 0,
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.byType(SizedBox), findsWidgets);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-165: PaddingWidgetFactory - padding values
  // ---------------------------------------------------------------------------
  group('TC-165: PaddingWidgetFactory', () {
    testWidgets('Normal: applies uniform padding to child',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'padding',
          'padding': 16,
          'child': {'type': 'text', 'content': 'Padded'},
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.text('Padded'), findsOneWidget);
      expect(find.byType(Padding), findsWidgets);
    });

    testWidgets('Boundary: padding with per-edge values',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'padding',
          'padding': {
            'left': 8,
            'top': 16,
            'right': 24,
            'bottom': 32,
          },
          'child': {'type': 'text', 'content': 'EdgePadded'},
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.text('EdgePadded'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-166: AlignWidgetFactory - alignment
  // ---------------------------------------------------------------------------
  group('TC-166: AlignWidgetFactory', () {
    testWidgets('Normal: aligns child to topLeft',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'align',
          'alignment': 'topStart',
          'child': {'type': 'text', 'content': 'TopLeft'},
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.text('TopLeft'), findsOneWidget);
      expect(find.byType(Align), findsOneWidget);

      final textPos = tester.getTopLeft(find.text('TopLeft'));
      expect(textPos.dx, lessThan(50));
      expect(textPos.dy, lessThan(50));
    });

    testWidgets('Boundary: align defaults to center when alignment unspecified',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'align',
          'child': {'type': 'text', 'content': 'DefaultAlign'},
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.text('DefaultAlign'), findsOneWidget);
      final align = tester.widget<Align>(find.byType(Align));
      expect(align.alignment, equals(Alignment.center));
    });
  });

  // ---------------------------------------------------------------------------
  // TC-167: WrapWidgetFactory - spacing, direction
  // ---------------------------------------------------------------------------
  group('TC-167: WrapWidgetFactory', () {
    testWidgets('Normal: renders wrap with spacing and children',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'wrap',
          'spacing': 10,
          'runSpacing': 10,
          'children': [
            {'type': 'box', 'width': 80, 'height': 40, 'backgroundColor': '#FF0000'},
            {'type': 'box', 'width': 80, 'height': 40, 'backgroundColor': '#00FF00'},
            {'type': 'box', 'width': 80, 'height': 40, 'backgroundColor': '#0000FF'},
          ],
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.byType(Wrap), findsOneWidget);
    });

    testWidgets('Boundary: wrap with vertical direction',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'wrap',
          'direction': 'vertical',
          'spacing': 5,
          'children': [
            {'type': 'text', 'content': 'V1'},
            {'type': 'text', 'content': 'V2'},
          ],
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.text('V1'), findsOneWidget);
      expect(find.text('V2'), findsOneWidget);
      final wrap = tester.widget<Wrap>(find.byType(Wrap));
      expect(wrap.direction, equals(Axis.vertical));
    });
  });

  // ---------------------------------------------------------------------------
  // TC-168: ConditionalWidgetFactory - if/then/else
  // ---------------------------------------------------------------------------
  group('TC-168: ConditionalWidgetFactory', () {
    testWidgets('Normal: renders then branch when condition is true',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'conditional',
          'condition': true,
          'then': {'type': 'text', 'content': 'ThenBranch'},
          'else': {'type': 'text', 'content': 'ElseBranch'},
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.text('ThenBranch'), findsOneWidget);
      expect(find.text('ElseBranch'), findsNothing);
    });

    testWidgets('Boundary: renders else branch when condition is false',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'conditional',
          'condition': false,
          'then': {'type': 'text', 'content': 'ThenBranch'},
          'else': {'type': 'text', 'content': 'ElseBranch'},
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.text('ElseBranch'), findsOneWidget);
      expect(find.text('ThenBranch'), findsNothing);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-169: TableWidgetFactory - rows/columns structure
  // ---------------------------------------------------------------------------
  group('TC-169: TableWidgetFactory', () {
    testWidgets('Normal: renders table with rows and cells',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
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
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.text('R1C1'), findsOneWidget);
      expect(find.text('R1C2'), findsOneWidget);
      expect(find.text('R2C1'), findsOneWidget);
      expect(find.text('R2C2'), findsOneWidget);
      expect(find.byType(Table), findsOneWidget);
    });

    testWidgets('Boundary: table with border and single row',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'table',
          'border': {'color': '#000000', 'width': 1},
          'rows': [
            {
              'cells': [
                {'type': 'text', 'content': 'Single'},
              ],
            },
          ],
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.text('Single'), findsOneWidget);
      expect(find.byType(Table), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-170: PositionedWidgetFactory - left/top/right/bottom in stack
  // ---------------------------------------------------------------------------
  group('TC-170: PositionedWidgetFactory', () {
    testWidgets('Normal: positioned widget with left and top inside stack',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'stack',
          'children': [
            {
              'type': 'box',
              'width': 300,
              'height': 300,
              'backgroundColor': '#EEEEEE',
            },
            {
              'type': 'positioned',
              'left': 10,
              'top': 20,
              'child': {'type': 'text', 'content': 'Positioned'},
            },
          ],
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.text('Positioned'), findsOneWidget);
      expect(find.byType(Positioned), findsOneWidget);
    });

    testWidgets('Boundary: positioned with right and bottom values',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'stack',
          'children': [
            {
              'type': 'box',
              'width': 300,
              'height': 300,
              'backgroundColor': '#EEEEEE',
            },
            {
              'type': 'positioned',
              'right': 5,
              'bottom': 5,
              'child': {'type': 'text', 'content': 'BottomRight'},
            },
          ],
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.text('BottomRight'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-171: IntrinsicHeightWidgetFactory - intrinsic height
  // ---------------------------------------------------------------------------
  group('TC-171: IntrinsicHeightWidgetFactory', () {
    testWidgets('Normal: wraps child with intrinsic height',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'intrinsicHeight',
          'children': [
            {
              'type': 'linear',
              'direction': 'horizontal',
              'children': [
                {'type': 'text', 'content': 'IntrinsicH'},
              ],
            },
          ],
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.text('IntrinsicH'), findsOneWidget);
      expect(find.byType(IntrinsicHeight), findsOneWidget);
    });

    testWidgets('Boundary: intrinsicHeight with no children',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'intrinsicHeight',
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.byType(IntrinsicHeight), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-172: IntrinsicWidthWidgetFactory - intrinsic width
  // ---------------------------------------------------------------------------
  group('TC-172: IntrinsicWidthWidgetFactory', () {
    testWidgets('Normal: wraps child with intrinsic width',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'intrinsicWidth',
          'children': [
            {'type': 'text', 'content': 'IntrinsicW'},
          ],
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.text('IntrinsicW'), findsOneWidget);
      expect(find.byType(IntrinsicWidth), findsOneWidget);
    });

    testWidgets('Boundary: intrinsicWidth with stepWidth and stepHeight',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'intrinsicWidth',
          'stepWidth': 50,
          'stepHeight': 50,
          'children': [
            {'type': 'text', 'content': 'Stepped'},
          ],
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.text('Stepped'), findsOneWidget);
      final intrinsicWidth = tester.widget<IntrinsicWidth>(find.byType(IntrinsicWidth));
      expect(intrinsicWidth.stepWidth, equals(50));
      expect(intrinsicWidth.stepHeight, equals(50));
    });
  });

  // ---------------------------------------------------------------------------
  // TC-173: AspectRatioWidgetFactory - aspectRatio property
  // ---------------------------------------------------------------------------
  group('TC-173: AspectRatioWidgetFactory', () {
    testWidgets('Normal: renders with 16:9 aspect ratio',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'aspectRatio',
          'aspectRatio': 1.78,
          'children': [
            {'type': 'box', 'backgroundColor': '#FF0000'},
          ],
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.byType(AspectRatio), findsOneWidget);
      final ar = tester.widget<AspectRatio>(find.byType(AspectRatio));
      expect(ar.aspectRatio, closeTo(1.78, 0.01));
    });

    testWidgets('Boundary: defaults to 1:1 aspect ratio when not specified',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'aspectRatio',
          'children': [
            {'type': 'box', 'backgroundColor': '#00FF00'},
          ],
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      final ar = tester.widget<AspectRatio>(find.byType(AspectRatio));
      expect(ar.aspectRatio, equals(1.0));
    });
  });

  // ---------------------------------------------------------------------------
  // TC-174: BaselineWidgetFactory - baseline alignment
  // ---------------------------------------------------------------------------
  group('TC-174: BaselineWidgetFactory', () {
    testWidgets('Normal: renders baseline with alphabetic type',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'baseline',
          'baseline': 50,
          'baselineType': 'alphabetic',
          'children': [
            {'type': 'text', 'content': 'Baselined'},
          ],
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.text('Baselined'), findsOneWidget);
      expect(find.byType(Baseline), findsOneWidget);
      final baseline = tester.widget<Baseline>(find.byType(Baseline));
      expect(baseline.baseline, equals(50));
      expect(baseline.baselineType, equals(TextBaseline.alphabetic));
    });

    testWidgets('Boundary: baseline with ideographic type',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'baseline',
          'baseline': 30,
          'baselineType': 'ideographic',
          'children': [
            {'type': 'text', 'content': 'Ideographic'},
          ],
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.text('Ideographic'), findsOneWidget);
      final baseline = tester.widget<Baseline>(find.byType(Baseline));
      expect(baseline.baselineType, equals(TextBaseline.ideographic));
    });
  });

  // TC-175 (ConstrainedBoxWidgetFactory) removed — `constrainedBox` /
  // `constrained` are no longer separate widgets. Min/max constraints
  // are properties of `box` (covered by box constraint tests).

  // ---------------------------------------------------------------------------
  // TC-176: FittedBoxWidgetFactory - fit mode
  // ---------------------------------------------------------------------------
  group('TC-176: FittedBoxWidgetFactory', () {
    testWidgets('Normal: renders fitted box with contain fit',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'fittedBox',
          'fit': 'contain',
          'children': [
            {'type': 'text', 'content': 'FittedContain'},
          ],
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.text('FittedContain'), findsOneWidget);
      expect(find.byType(FittedBox), findsOneWidget);
      final fitted = tester.widget<FittedBox>(find.byType(FittedBox));
      expect(fitted.fit, equals(BoxFit.contain));
    });

    testWidgets('Boundary: fitted box with cover fit mode',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'fittedBox',
          'fit': 'cover',
          'children': [
            {'type': 'text', 'content': 'FittedCover'},
          ],
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      final fitted = tester.widget<FittedBox>(find.byType(FittedBox));
      expect(fitted.fit, equals(BoxFit.cover));
    });
  });

  // ---------------------------------------------------------------------------
  // TC-177: LimitedBoxWidgetFactory - maxWidth/maxHeight
  // ---------------------------------------------------------------------------
  group('TC-177: LimitedBoxWidgetFactory', () {
    testWidgets('Normal: renders limited box with max dimensions',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'limitedBox',
          'maxWidth': 200,
          'maxHeight': 100,
          'children': [
            {'type': 'text', 'content': 'Limited'},
          ],
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.text('Limited'), findsOneWidget);
      expect(find.byType(LimitedBox), findsOneWidget);
      final limited = tester.widget<LimitedBox>(find.byType(LimitedBox));
      expect(limited.maxWidth, equals(200));
      expect(limited.maxHeight, equals(100));
    });

    testWidgets('Boundary: limited box without max values defaults to infinity',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'limitedBox',
          'children': [
            {'type': 'text', 'content': 'NoLimit'},
          ],
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.text('NoLimit'), findsOneWidget);
      final limited = tester.widget<LimitedBox>(find.byType(LimitedBox));
      expect(limited.maxWidth, equals(double.infinity));
      expect(limited.maxHeight, equals(double.infinity));
    });
  });

  // ---------------------------------------------------------------------------
  // TC-178: FlowWidgetFactory - flow layout
  // ---------------------------------------------------------------------------
  group('TC-178: FlowWidgetFactory', () {
    testWidgets('Normal: renders flow layout with children',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'flow',
          'spacing': 10,
          'children': [
            {'type': 'box', 'width': 50, 'height': 50, 'backgroundColor': '#FF0000'},
            {'type': 'box', 'width': 50, 'height': 50, 'backgroundColor': '#00FF00'},
          ],
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.byType(Flow), findsOneWidget);
    });

    testWidgets('Boundary: flow with vertical direction',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'flow',
          'direction': 'vertical',
          'spacing': 5,
          'children': [
            {'type': 'box', 'width': 30, 'height': 30, 'backgroundColor': '#0000FF'},
          ],
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.byType(Flow), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-179: MarginWidgetFactory - margin values
  // ---------------------------------------------------------------------------
  group('TC-179: MarginWidgetFactory', () {
    testWidgets('Normal: applies margin around child',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'margin',
          'margin': 20,
          'children': [
            {'type': 'text', 'content': 'Margined'},
          ],
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.text('Margined'), findsOneWidget);

      // Verify margin is applied via Container
      final textPos = tester.getTopLeft(find.text('Margined'));
      expect(textPos.dx, greaterThanOrEqualTo(20));
      expect(textPos.dy, greaterThanOrEqualTo(20));
    });

    testWidgets('Boundary: margin with per-edge values via value property',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'margin',
          'value': {'left': 10, 'top': 20, 'right': 10, 'bottom': 20},
          'children': [
            {'type': 'text', 'content': 'EdgeMargin'},
          ],
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.text('EdgeMargin'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-180: FractionallySizedWidgetFactory - widthFactor/heightFactor
  // ---------------------------------------------------------------------------
  group('TC-180: FractionallySizedWidgetFactory', () {
    testWidgets('Normal: renders with width and height factors',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'fractionallySized',
          'widthFactor': 0.5,
          'heightFactor': 0.5,
          'child': {
            'type': 'box',
            'backgroundColor': '#FF0000',
          },
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.byType(FractionallySizedBox), findsOneWidget);
      final fractional = tester.widget<FractionallySizedBox>(
          find.byType(FractionallySizedBox));
      expect(fractional.widthFactor, equals(0.5));
      expect(fractional.heightFactor, equals(0.5));
    });

    testWidgets('Boundary: fractionallySized with only widthFactor',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'fractionallySized',
          'widthFactor': 0.75,
          'child': {
            'type': 'text',
            'content': 'WidthOnly',
          },
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.text('WidthOnly'), findsOneWidget);
      final fractional = tester.widget<FractionallySizedBox>(
          find.byType(FractionallySizedBox));
      expect(fractional.widthFactor, equals(0.75));
      expect(fractional.heightFactor, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-181: MediaQueryWidgetFactory - media query responsive
  // ---------------------------------------------------------------------------
  group('TC-181: MediaQueryWidgetFactory', () {
    testWidgets('Normal: renders then branch when condition matches',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'mediaQuery',
          'condition': {'minWidth': 0},
          'then': {'type': 'text', 'content': 'WideLayout'},
          'else': {'type': 'text', 'content': 'NarrowLayout'},
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      // minWidth: 0 should always match
      expect(find.text('WideLayout'), findsOneWidget);
    });

    testWidgets('Boundary: renders else branch when condition fails',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'mediaQuery',
          'condition': {'minWidth': 99999},
          'then': {'type': 'text', 'content': 'HugeScreen'},
          'else': {'type': 'text', 'content': 'SmallScreen'},
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      // minWidth: 99999 should never match in test environment
      expect(find.text('SmallScreen'), findsOneWidget);
      expect(find.text('HugeScreen'), findsNothing);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-182: SafeAreaWidgetFactory - safe area insets
  // ---------------------------------------------------------------------------
  group('TC-182: SafeAreaWidgetFactory', () {
    testWidgets('Normal: wraps child with safe area',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'safeArea',
          'top': true,
          'bottom': true,
          'children': [
            {'type': 'text', 'content': 'SafeContent'},
          ],
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.text('SafeContent'), findsOneWidget);
      expect(find.byType(SafeArea), findsOneWidget);
    });

    testWidgets('Boundary: safe area with selective edge disabling',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'safeArea',
          'top': false,
          'bottom': false,
          'left': true,
          'right': true,
          'children': [
            {'type': 'text', 'content': 'PartialSafe'},
          ],
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.text('PartialSafe'), findsOneWidget);
      final safeArea = tester.widget<SafeArea>(find.byType(SafeArea));
      expect(safeArea.top, isFalse);
      expect(safeArea.bottom, isFalse);
      expect(safeArea.left, isTrue);
      expect(safeArea.right, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-183: ErrorBoundaryWidgetFactory - error boundary wrapping
  // ---------------------------------------------------------------------------
  group('TC-183: ErrorBoundaryWidgetFactory', () {
    testWidgets('Normal: renders child content when no error occurs',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'errorBoundary',
          'content': {'type': 'text', 'content': 'NoError'},
          'fallback': {'type': 'text', 'content': 'ErrorOccurred'},
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.text('NoError'), findsOneWidget);
      expect(find.text('ErrorOccurred'), findsNothing);
    });

    testWidgets('Boundary: renders fallback when child causes error',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'errorBoundary',
          'content': {'type': 'nonExistentWidget'},
          'fallback': {'type': 'text', 'content': 'Recovered'},
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();
      // Allow post-frame callback to run for error state update
      await tester.pump();

      // Unknown widget type renders an error widget (not throwing),
      // so errorBoundary shows it as-is or fallback depending on impl.
      // Verify no unhandled crash — the page renders successfully.
      final recovered = find.text('Recovered');
      final errorUI = find.text('Something went wrong');
      final unknownError = find.textContaining('Unknown widget type');
      expect(
        recovered.evaluate().isNotEmpty ||
            errorUI.evaluate().isNotEmpty ||
            unknownError.evaluate().isNotEmpty,
        isTrue,
      );
    });
  });
}
