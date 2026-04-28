import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

/// Display Widget Factories Tests
///
/// TC-185 ~ TC-202 (skipping TC-184 text which has dedicated tests)
/// Each TC has Normal + Boundary tests.
void main() {
  late MCPUIRuntime runtime;

  setUp(() {
    runtime = MCPUIRuntime(enableDebugMode: false);
  });

  tearDown(() async {
    await runtime.dispose();
  });

  // ---------------------------------------------------------------------------
  // TC-185: RichTextWidgetFactory
  // ---------------------------------------------------------------------------
  group('TC-185: RichTextWidgetFactory', () {
    testWidgets('Normal - renders text spans with styles',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'richText',
          'spans': [
            {
              'text': 'Hello ',
              'style': {'fontWeight': 'bold'},
            },
            {
              'text': 'World',
              'style': {'color': '#FF0000'},
            },
          ],
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      // RichText renders as a RichText widget
      expect(find.byType(RichText), findsWidgets);
    });

    testWidgets('Boundary - renders with empty spans list',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'richText',
          'spans': <Map<String, dynamic>>[],
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      // Should render without error even with empty spans
      expect(find.byType(RichText), findsWidgets);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-186: IconWidgetFactory
  // ---------------------------------------------------------------------------
  group('TC-186: IconWidgetFactory', () {
    testWidgets('Normal - renders icon with name, size, and color',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'icon',
          'icon': 'home',
          'size': 32,
          'color': '#2196F3',
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      final iconWidget = tester.widget<Icon>(find.byType(Icon).first);
      expect(iconWidget.icon, Icons.home);
      expect(iconWidget.size, 32.0);
      expect(iconWidget.color, const Color(0xFF2196F3));
    });

    testWidgets('Boundary - renders fallback icon for unknown name',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'icon',
          'icon': 'nonexistent_icon_name',
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      // Unknown icon name falls back to Icons.help_outline so missing
      // icons are visually obvious (vs. the old silent black dot).
      final iconWidget = tester.widget<Icon>(find.byType(Icon).first);
      expect(iconWidget.icon, Icons.help_outline);
      expect(iconWidget.size, 24.0); // default size
    });
  });

  // ---------------------------------------------------------------------------
  // TC-187: ImageWidgetFactory
  // ---------------------------------------------------------------------------
  group('TC-187: ImageWidgetFactory', () {
    testWidgets('Normal - renders image with width, height, and fit',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'image',
          'src': 'https://example.com/image.png',
          'width': 200,
          'height': 150,
          'fit': 'cover',
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      // Network image creates an Image widget
      final imageWidget = tester.widget<Image>(find.byType(Image).first);
      expect(imageWidget.width, 200.0);
      expect(imageWidget.height, 150.0);
      expect(imageWidget.fit, BoxFit.cover);
    });

    testWidgets('Boundary - renders fallback for empty src',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'image',
          'src': '',
          'width': 100,
          'height': 100,
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      // Empty src should show fallback/error widget, not crash
      expect(tester.takeException(), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-188: AvatarWidgetFactory
  // ---------------------------------------------------------------------------
  group('TC-188: AvatarWidgetFactory', () {
    testWidgets('Normal - renders avatar with size and initials',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'avatar',
          'size': 48,
          'label': 'John',
          'backgroundColor': '#4CAF50',
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar).first);
      // size 48 => radius 24
      expect(avatar.radius, 24.0);
      // Label 'John' gets truncated to 2 chars and uppercased
      expect(find.text('JO'), findsOneWidget);
    });

    testWidgets('Boundary - renders avatar with no label and no image',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'avatar',
          'radius': 16,
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar).first);
      expect(avatar.radius, 16.0);
      // No child text or icon when no label/icon provided
      expect(avatar.child, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-189: BadgeWidgetFactory
  // ---------------------------------------------------------------------------
  group('TC-189: BadgeWidgetFactory', () {
    testWidgets('Normal - renders badge with label and color',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'badge',
          'label': '5',
          'color': '#F44336',
          'child': {
            'type': 'icon',
            'icon': 'email',
          },
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.byType(Badge), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('Boundary - renders badge with no label',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'badge',
          'isLabelVisible': false,
          'child': {
            'type': 'icon',
            'icon': 'star',
          },
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      final badge = tester.widget<Badge>(find.byType(Badge));
      expect(badge.isLabelVisible, false);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-190: BannerWidgetFactory
  // ---------------------------------------------------------------------------
  group('TC-190: BannerWidgetFactory', () {
    testWidgets('Normal - renders banner with message and severity',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'banner',
          'message': 'Operation completed successfully',
          'severity': 'success',
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.text('Operation completed successfully'), findsOneWidget);
      // Success severity uses check_circle_outline icon
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('Boundary - renders banner with empty message',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'banner',
          'message': '',
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      // Default severity is 'info'
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-191: CardWidgetFactory
  // ---------------------------------------------------------------------------
  group('TC-191: CardWidgetFactory', () {
    testWidgets('Normal - renders card with elevation and child',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'card',
          'elevation': 4,
          'child': {
            'type': 'text',
            'content': 'Card Content',
          },
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      final card = tester.widget<Card>(find.byType(Card));
      expect(card.elevation, 4.0);
      expect(find.text('Card Content'), findsOneWidget);
    });

    testWidgets('Boundary - renders card with zero elevation and no child',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'card',
          'elevation': 0,
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      final card = tester.widget<Card>(find.byType(Card));
      expect(card.elevation, 0.0);
      expect(card.child, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-192: ChipWidgetFactory
  // ---------------------------------------------------------------------------
  group('TC-192: ChipWidgetFactory', () {
    testWidgets('Normal - renders chip with label',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'chip',
          'label': 'Flutter',
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.text('Flutter'), findsOneWidget);
      expect(find.byType(RawChip), findsOneWidget);
    });

    testWidgets('Boundary - renders chip with delete action',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'chip',
          'label': 'Deletable',
          'onDeleted': {
            'type': 'state',
            'action': 'set',
            'path': 'deleted',
            'value': true,
          },
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      final chip = tester.widget<RawChip>(find.byType(RawChip));
      expect(chip.onDeleted, isNotNull);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-193: DividerWidgetFactory
  // ---------------------------------------------------------------------------
  group('TC-193: DividerWidgetFactory', () {
    testWidgets('Normal - renders divider with thickness and color',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'divider',
          'thickness': 2,
          'color': '#BDBDBD',
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      final divider = tester.widget<Divider>(find.byType(Divider));
      expect(divider.thickness, 2.0);
      expect(divider.color, const Color(0xFFBDBDBD));
    });

    testWidgets('Boundary - renders divider with default thickness',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'divider',
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      final divider = tester.widget<Divider>(find.byType(Divider));
      // Default thickness is 1.0
      expect(divider.thickness, 1.0);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-194: ProgressWidgetFactory
  // ---------------------------------------------------------------------------
  group('TC-194: ProgressWidgetFactory', () {
    testWidgets('Normal - renders linear progress with value',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'progress',
          'indicatorType': 'linear',
          'value': 0.7,
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      final progress = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator));
      expect(progress.value, 0.7);
    });

    testWidgets('Boundary - renders circular progress without value (indeterminate)',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'progress',
          'indicatorType': 'circular',
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      final progress = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator));
      // No value means indeterminate
      expect(progress.value, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-195: TooltipWidgetFactory
  // ---------------------------------------------------------------------------
  group('TC-195: TooltipWidgetFactory', () {
    testWidgets('Normal - renders tooltip with message and child',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'tooltip',
          'message': 'Helpful tip',
          'child': {
            'type': 'icon',
            'icon': 'info',
          },
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, 'Helpful tip');
    });

    testWidgets('Boundary - renders tooltip with empty message',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'tooltip',
          'message': '',
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, '');
      // Default child is Icon(Icons.info) when no child provided
      expect(find.byIcon(Icons.info), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-196: PlaceholderWidgetFactory
  // ---------------------------------------------------------------------------
  group('TC-196: PlaceholderWidgetFactory', () {
    testWidgets('Normal - renders placeholder with custom dimensions',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'placeholder',
          'fallbackWidth': 200,
          'fallbackHeight': 100,
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      final placeholder = tester.widget<Placeholder>(find.byType(Placeholder));
      expect(placeholder.fallbackWidth, 200.0);
      expect(placeholder.fallbackHeight, 100.0);
    });

    testWidgets('Boundary - renders placeholder with defaults',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'placeholder',
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      final placeholder = tester.widget<Placeholder>(find.byType(Placeholder));
      // Defaults: 400x400
      expect(placeholder.fallbackWidth, 400.0);
      expect(placeholder.fallbackHeight, 400.0);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-197: VerticalDividerWidgetFactory
  // ---------------------------------------------------------------------------
  group('TC-197: VerticalDividerWidgetFactory', () {
    testWidgets('Normal - renders vertical divider with thickness',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'linear',
          'direction': 'horizontal',
          'children': [
            {'type': 'text', 'content': 'Left'},
            {
              'type': 'verticalDivider',
              'thickness': 3,
              'color': '#9E9E9E',
            },
            {'type': 'text', 'content': 'Right'},
          ],
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      final divider = tester.widget<VerticalDivider>(
          find.byType(VerticalDivider));
      expect(divider.thickness, 3.0);
    });

    testWidgets('Boundary - renders vertical divider with no properties',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'linear',
          'direction': 'horizontal',
          'children': [
            {'type': 'text', 'content': 'A'},
            {'type': 'verticalDivider'},
            {'type': 'text', 'content': 'B'},
          ],
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      // Should render without error with null thickness
      expect(find.byType(VerticalDivider), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-198: DecorationWidgetFactory
  // ---------------------------------------------------------------------------
  group('TC-198: DecorationWidgetFactory', () {
    testWidgets('Normal - renders decoration with color and border',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'decoration',
          'color': '#E3F2FD',
          'borderRadius': 8,
          'border': {
            'all': {'color': '#2196F3', 'width': 2},
          },
          'children': [
            {'type': 'text', 'content': 'Decorated'},
          ],
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.byType(DecoratedBox), findsOneWidget);
      expect(find.text('Decorated'), findsOneWidget);
    });

    testWidgets('Boundary - renders decoration with no properties',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'decoration',
          'children': [
            {'type': 'text', 'content': 'Minimal'},
          ],
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.byType(DecoratedBox), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-199: ClipOvalWidgetFactory
  // ---------------------------------------------------------------------------
  group('TC-199: ClipOvalWidgetFactory', () {
    testWidgets('Normal - renders ClipOval with child',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'clipOval',
          'children': [
            {
              'type': 'box',
              'width': 100,
              'height': 100,
              'color': '#FF0000',
            },
          ],
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.byType(ClipOval), findsOneWidget);
    });

    testWidgets('Boundary - renders ClipOval with no children',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'clipOval',
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      final clipOval = tester.widget<ClipOval>(find.byType(ClipOval));
      expect(clipOval.clipBehavior, Clip.antiAlias);
      expect(clipOval.child, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-200: ClipRRectWidgetFactory
  // ---------------------------------------------------------------------------
  group('TC-200: ClipRRectWidgetFactory', () {
    testWidgets('Normal - renders ClipRRect with borderRadius',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'clipRRect',
          'borderRadius': 16,
          'children': [
            {
              'type': 'box',
              'width': 100,
              'height': 100,
              'color': '#4CAF50',
            },
          ],
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      final clipRRect = tester.widget<ClipRRect>(find.byType(ClipRRect));
      expect(clipRRect.borderRadius, BorderRadius.circular(16));
    });

    testWidgets('Boundary - renders ClipRRect with per-corner radius',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'clipRRect',
          'borderRadius': {
            'topLeft': 8,
            'topRight': 16,
            'bottomLeft': 0,
            'bottomRight': 4,
          },
          'children': [
            {'type': 'text', 'content': 'Clipped'},
          ],
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      final clipRRect = tester.widget<ClipRRect>(find.byType(ClipRRect));
      expect(
        clipRRect.borderRadius,
        const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(0),
          bottomRight: Radius.circular(4),
        ),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // TC-201: DecoratedBoxWidgetFactory
  // ---------------------------------------------------------------------------
  group('TC-201: DecoratedBoxWidgetFactory', () {
    testWidgets('Normal - renders DecoratedBox with box decoration',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'decoratedBox',
          'decoration': {
            'color': '#FFF3E0',
            'borderRadius': 12,
          },
          'children': [
            {'type': 'text', 'content': 'Decorated Box'},
          ],
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.byType(DecoratedBox), findsOneWidget);
      expect(find.text('Decorated Box'), findsOneWidget);
    });

    testWidgets('Boundary - renders DecoratedBox with no decoration',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'decoratedBox',
          'children': [
            {'type': 'text', 'content': 'No Decoration'},
          ],
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      // Should use default BoxDecoration when none provided
      expect(find.byType(DecoratedBox), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-202: VisibilityWidgetFactory
  // ---------------------------------------------------------------------------
  group('TC-202: VisibilityWidgetFactory', () {
    testWidgets('Normal - hides child when visible is false',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'visibility',
          'visible': false,
          'child': {
            'type': 'text',
            'content': 'Hidden Content',
          },
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      final visibility = tester.widget<Visibility>(find.byType(Visibility));
      expect(visibility.visible, false);
    });

    testWidgets('Boundary - shows child when visible defaults to true',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'visibility',
          'child': {
            'type': 'text',
            'content': 'Visible Content',
          },
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      final visibility = tester.widget<Visibility>(find.byType(Visibility));
      expect(visibility.visible, true);
      expect(find.text('Visible Content'), findsOneWidget);
    });
  });
}
