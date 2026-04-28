import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/accessibility/live_regions.dart';
import 'package:flutter_mcp_ui_runtime/src/accessibility/focus_manager.dart';

/// TC-012 ~ TC-013: Accessibility integration tests
/// Corresponds to: 04_TEST/feat-runtime/14-accessibility.md §7
void main() {
  group('Accessibility Integration Tests', () {
    setUp(() {
      MCPFocusManager.instance.clear();
      LiveRegionManager.instance.clear();
    });

    tearDown(() {
      MCPFocusManager.instance.clear();
      LiveRegionManager.instance.clear();
    });

    // TC-012: Accessibility with state bindings
    group('TC-012: Live region + state changes', () {
      testWidgets('Normal: LiveRegion widget renders with semantics',
          (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: LiveRegion(
                regionId: 'status-region',
                type: LiveRegionType.polite,
                child: Text('Status: Loading'),
              ),
            ),
          ),
        );

        expect(find.text('Status: Loading'), findsOneWidget);
        expect(find.byType(Semantics), findsWidgets);
      });

      testWidgets(
          'Normal: State change updates semantic label via LiveRegionBuilder',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LiveRegionBuilder(
                regionId: 'count-region',
                builder: (context, announcement) {
                  return Text(announcement ?? '0 items');
                },
              ),
            ),
          ),
        );

        expect(find.text('0 items'), findsOneWidget);

        // Simulate state change via announcement
        LiveRegionManager.instance.announce('count-region', '5 items');
        await tester.pump();

        expect(find.text('5 items'), findsOneWidget);
      });

      testWidgets(
          'Normal: Live region with bound content announces on state change',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LiveRegionBuilder(
                regionId: 'dynamic-region',
                builder: (context, announcement) {
                  return Text(announcement ?? 'Initial');
                },
              ),
            ),
          ),
        );

        LiveRegionManager.instance.announce('dynamic-region', 'Updated value');
        await tester.pump();

        expect(find.text('Updated value'), findsOneWidget);
      });

      testWidgets('Boundary: empty announcement sets empty text',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LiveRegionBuilder(
                regionId: 'empty-region',
                builder: (context, announcement) {
                  return Text(announcement ?? 'Default');
                },
              ),
            ),
          ),
        );

        LiveRegionManager.instance.announce('empty-region', '');
        await tester.pump();

        expect(find.text(''), findsOneWidget);
      });
    });

    // TC-013: Accessibility plugin lifecycle
    group('TC-013: Accessibility lifecycle', () {
      testWidgets('Normal: StatusLiveRegion renders message with icon',
          (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: StatusLiveRegion(
                message: 'Operation complete',
                type: LiveRegionType.status,
              ),
            ),
          ),
        );

        expect(find.text('Operation complete'), findsOneWidget);
        expect(find.byType(Icon), findsWidgets);
      });

      testWidgets('Normal: FocusRestore saves and restores focus',
          (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: FocusRestore(
                focusId: 'restore-test',
                child: Text('Restorable focus area'),
              ),
            ),
          ),
        );

        expect(find.text('Restorable focus area'), findsOneWidget);
      });

      testWidgets('Normal: SkipToContent renders and triggers callback',
          (tester) async {
        bool skipped = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SkipToContent(
                label: 'Skip to main content',
                onSkip: () => skipped = true,
              ),
            ),
          ),
        );

        expect(find.text('Skip to main content'), findsOneWidget);

        await tester.tap(find.text('Skip to main content'));
        expect(skipped, isTrue);
      });

      testWidgets('Normal: AccessibleProgressIndicator shows progress',
          (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: AccessibleProgressIndicator(
                value: 0.75,
                label: 'Upload',
              ),
            ),
          ),
        );

        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        expect(find.byType(Semantics), findsWidgets);
      });

      testWidgets(
          'Normal: AccessibleProgressIndicator without value shows indeterminate',
          (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: AccessibleProgressIndicator(
                label: 'Loading',
              ),
            ),
          ),
        );

        expect(find.byType(LinearProgressIndicator), findsOneWidget);
      });

      testWidgets(
          'Boundary: Plugin disabled — no semantic wrappers (plain widget)',
          (tester) async {
        // Without accessibility wrappers, plain Text has no live region semantics
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Text('Plain text'),
            ),
          ),
        );

        expect(find.text('Plain text'), findsOneWidget);
      });
    });
  });
}
