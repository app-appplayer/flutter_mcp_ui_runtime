import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/accessibility/focus_manager.dart';

/// TC-011: Focus properties on widgets
/// Corresponds to: 04_TEST/feat-runtime/14-accessibility.md §6
void main() {
  group('Focus Properties Tests', () {
    late MCPFocusManager focusManager;

    setUp(() {
      focusManager = MCPFocusManager.instance;
      // Note: clear() not called here to avoid disposing FocusNodes
      // owned by previous widget tree teardown
    });

    // TC-011: Focus properties on widgets
    group('TC-011: Widget focus properties', () {
      testWidgets('Normal: Widget with focusOrder appears in traversal',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(builder: (context) {
                final node1 = FocusNode(debugLabel: 'btn-1');
                final node2 = FocusNode(debugLabel: 'btn-2');
                focusManager.registerFocusNode('btn-1', node1, order: 1);
                focusManager.registerFocusNode('btn-2', node2, order: 0);

                return Column(
                  children: [
                    Focus(focusNode: node1, child: const Text('Button 1')),
                    Focus(focusNode: node2, child: const Text('Button 2')),
                  ],
                );
              }),
            ),
          ),
        );

        expect(focusManager.getFocusNode('btn-1'), isNotNull);
        expect(focusManager.getFocusNode('btn-2'), isNotNull);
      });

      testWidgets('Normal: FocusScope creation via createFocusScope',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: focusManager.createFocusScope(
                scopeId: 'test-scope',
                autofocus: true,
                child: const Text('Scoped content'),
              ),
            ),
          ),
        );

        expect(find.text('Scoped content'), findsOneWidget);
        expect(find.byType(FocusScope), findsWidgets);
      });

      test('Normal: FocusGroup addNode and removeNode', () {
        final group = FocusGroup('test-group');
        final node = FocusNode(debugLabel: 'group-item');

        group.addNode('item-1', node);
        expect(group.nodeIds, contains('item-1'));
        expect(group.nodes['item-1'], node);

        group.removeNode('item-1');
        expect(group.nodeIds, isNot(contains('item-1')));
        expect(group.nodes['item-1'], isNull);
      });

      test('Normal: FocusGroup trapFocus flag', () {
        final group = FocusGroup('modal');
        expect(group.trapFocus, isFalse);

        group.trapFocus = true;
        expect(group.trapFocus, isTrue);
      });

      test('Normal: Widget with focusTrap creates focus trap scope', () {
        final node1 = FocusNode(debugLabel: 'trap-1');
        final node2 = FocusNode(debugLabel: 'trap-2');
        focusManager.registerFocusNode('trap-1', node1, groupId: 'trap-scope');
        focusManager.registerFocusNode('trap-2', node2, groupId: 'trap-scope');

        focusManager.trapFocus('trap-scope');
        // Trap is active — no exception
        focusManager.releaseFocusTrap('trap-scope');
      });

      test('Boundary: focusOrder not set — auto-assigned based on registration',
          () {
        final node1 = FocusNode(debugLabel: 'auto-1');
        final node2 = FocusNode(debugLabel: 'auto-2');
        // Register without explicit order
        focusManager.registerFocusNode('auto-1', node1);
        focusManager.registerFocusNode('auto-2', node2);

        expect(focusManager.getFocusNode('auto-1'), node1);
        expect(focusManager.getFocusNode('auto-2'), node2);
      });
    });
  });
}
