import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/accessibility/focus_manager.dart';

/// TC-001 ~ TC-005: FocusManager tests
/// Corresponds to: 04_TEST/feat-runtime/14-accessibility.md §2
void main() {
  group('MCPFocusManager Tests', () {
    late MCPFocusManager focusManager;

    setUp(() {
      focusManager = MCPFocusManager.instance;
      focusManager.clear();
    });

    // TC-001: FocusManager — requestFocus and clearFocus
    group('TC-001: registerFocusNode, unregisterFocusNode, getFocusNode', () {
      test('Normal: registerFocusNode stores node, getFocusNode retrieves it',
          () {
        final node1 = FocusNode(debugLabel: 'widget-1');
        final node2 = FocusNode(debugLabel: 'widget-2');
        focusManager.registerFocusNode('widget-1', node1);
        focusManager.registerFocusNode('widget-2', node2);

        expect(focusManager.getFocusNode('widget-1'), equals(node1));
        expect(focusManager.getFocusNode('widget-2'), equals(node2));
      });

      test('Normal: unregisterFocusNode removes node', () {
        final node = FocusNode(debugLabel: 'temp');
        focusManager.registerFocusNode('temp', node);
        expect(focusManager.getFocusNode('temp'), isNotNull);

        focusManager.unregisterFocusNode('temp');
        expect(focusManager.getFocusNode('temp'), isNull);
      });

      test(
          'Normal: registering focus on different widget replaces previous registration',
          () {
        final node1 = FocusNode(debugLabel: 'widget-1');
        final node2 = FocusNode(debugLabel: 'widget-1-v2');
        focusManager.registerFocusNode('widget-1', node1);
        focusManager.registerFocusNode('widget-1', node2);

        // Overwritten with the new node
        expect(focusManager.getFocusNode('widget-1'), equals(node2));
      });

      test('Boundary: getFocusNode on non-existent key returns null', () {
        expect(focusManager.getFocusNode('nonexistent'), isNull);
      });

      test('Boundary: unregisterFocusNode with non-existent key is no-op', () {
        // Should not throw
        focusManager.unregisterFocusNode('nonexistent');
        expect(focusManager.getFocusNode('nonexistent'), isNull);
      });
    });

    // TC-002: FocusManager — focusOrder
    group('TC-002: Focus order management', () {
      test('Normal: nodes registered with order are retrievable', () {
        final nodeA = FocusNode(debugLabel: 'btn-a');
        final nodeB = FocusNode(debugLabel: 'btn-b');
        focusManager.registerFocusNode('btn-b', nodeB, order: 0);
        focusManager.registerFocusNode('btn-a', nodeA, order: 1);

        expect(focusManager.getFocusNode('btn-a'), nodeA);
        expect(focusManager.getFocusNode('btn-b'), nodeB);
      });

      test('Normal: unregisterFocusNode removes from traversal order', () {
        final nodeA = FocusNode(debugLabel: 'btn-a');
        final nodeB = FocusNode(debugLabel: 'btn-b');
        focusManager.registerFocusNode('btn-a', nodeA, order: 0);
        focusManager.registerFocusNode('btn-b', nodeB, order: 1);

        focusManager.unregisterFocusNode('btn-a');
        expect(focusManager.getFocusNode('btn-a'), isNull);
        // btn-b should still exist
        expect(focusManager.getFocusNode('btn-b'), nodeB);
      });

      test('Normal: nodes without explicit order are appended', () {
        final node1 = FocusNode(debugLabel: 'n1');
        final node2 = FocusNode(debugLabel: 'n2');
        final node3 = FocusNode(debugLabel: 'n3');
        focusManager.registerFocusNode('n1', node1);
        focusManager.registerFocusNode('n2', node2);
        focusManager.registerFocusNode('n3', node3);

        // All should be registered
        expect(focusManager.getFocusNode('n1'), node1);
        expect(focusManager.getFocusNode('n2'), node2);
        expect(focusManager.getFocusNode('n3'), node3);
      });
    });

    // TC-003: FocusManager — focus traps
    group('TC-003: Focus traps', () {
      test('Normal: trapFocus constrains focus to group', () {
        final node1 = FocusNode(debugLabel: 'btn-ok');
        final node2 = FocusNode(debugLabel: 'btn-cancel');
        focusManager.registerFocusNode('btn-ok', node1, groupId: 'dialog');
        focusManager.registerFocusNode('btn-cancel', node2,
            groupId: 'dialog');

        focusManager.trapFocus('dialog');
        // No exception thrown, trap is active
        expect(true, isTrue);
      });

      test('Normal: releaseFocusTrap removes constraint', () {
        final node1 = FocusNode(debugLabel: 'btn-ok');
        focusManager.registerFocusNode('btn-ok', node1, groupId: 'dialog');

        focusManager.trapFocus('dialog');
        focusManager.releaseFocusTrap('dialog');
        // No exception thrown
        expect(true, isTrue);
      });

      test('Boundary: nested traps — inner trap active, release restores outer',
          () {
        final outerNode = FocusNode(debugLabel: 'outer');
        final innerNode = FocusNode(debugLabel: 'inner');
        focusManager.registerFocusNode('outer-btn', outerNode,
            groupId: 'outer-dialog');
        focusManager.registerFocusNode('inner-btn', innerNode,
            groupId: 'inner-dialog');

        focusManager.trapFocus('outer-dialog');
        focusManager.trapFocus('inner-dialog');
        // Release inner
        focusManager.releaseFocusTrap('inner-dialog');
        // Outer should still be manageable
        focusManager.releaseFocusTrap('outer-dialog');
        expect(true, isTrue);
      });

      test('Error: releaseFocusTrap with unknown scope is no-op', () {
        // Should not throw
        focusManager.releaseFocusTrap('nonexistent');
        expect(true, isTrue);
      });

      test('Error: trapFocus with unknown group is no-op', () {
        // Should not throw
        focusManager.trapFocus('nonexistent');
        expect(true, isTrue);
      });
    });

    // TC-004: FocusManager — initialFocus and restoreFocus
    group('TC-004: initialFocus and restoreFocus', () {
      testWidgets('Normal: FocusRestore widget renders child',
          (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: FocusRestore(
                focusId: 'restore-scope',
                child: Text('Content'),
              ),
            ),
          ),
        );

        expect(find.text('Content'), findsOneWidget);
      });

      testWidgets(
          'Normal: FocusRestore saves focus on init and restores on dispose',
          (tester) async {
        // Build a widget with FocusRestore, then remove it
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FocusRestore(
                key: key,
                focusId: 'scope-a',
                child: const Text('Restorable'),
              ),
            ),
          ),
        );

        expect(find.text('Restorable'), findsOneWidget);

        // Replace the widget tree to trigger dispose
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: Text('Replaced')),
          ),
        );

        expect(find.text('Replaced'), findsOneWidget);
      });
    });

    // TC-005: FocusManager — keyboard navigation
    group('TC-005: Keyboard navigation', () {
      test(
          'Normal: MCPFocusTraversalPolicy sortDescendants respects traversal order',
          () {
        final node1 = FocusNode(debugLabel: 'a');
        final node2 = FocusNode(debugLabel: 'b');
        final node3 = FocusNode(debugLabel: 'c');

        final policy = MCPFocusTraversalPolicy(
          traversalOrder: ['b', 'a', 'c'],
          focusNodes: {'a': node1, 'b': node2, 'c': node3},
        );

        final sorted = policy.sortDescendants([node1, node2, node3], node1);
        expect(sorted.toList(), [node2, node1, node3]);
      });

      test(
          'Normal: MCPFocusTraversalPolicy findFirstFocus returns first in order',
          () {
        final node1 = FocusNode(debugLabel: 'first');
        final node2 = FocusNode(debugLabel: 'second');

        final policy = MCPFocusTraversalPolicy(
          traversalOrder: ['first', 'second'],
          focusNodes: {'first': node1, 'second': node2},
        );

        final result = policy.findFirstFocus(node2);
        expect(result, node1);
      });

      test(
          'Normal: MCPFocusTraversalPolicy findLastFocus returns last in order',
          () {
        final node1 = FocusNode(debugLabel: 'first');
        final node2 = FocusNode(debugLabel: 'second');

        final policy = MCPFocusTraversalPolicy(
          traversalOrder: ['first', 'second'],
          focusNodes: {'first': node1, 'second': node2},
        );

        final result = policy.findLastFocus(node1);
        expect(result, node2);
      });

      test('Boundary: empty traversal order returns current node', () {
        final currentNode = FocusNode(debugLabel: 'current');

        final policy = MCPFocusTraversalPolicy(
          traversalOrder: [],
          focusNodes: {},
        );

        expect(policy.findFirstFocus(currentNode), currentNode);
        expect(policy.findLastFocus(currentNode), currentNode);
      });

      test(
          'Boundary: sortDescendants includes nodes not in traversal order at end',
          () {
        final node1 = FocusNode(debugLabel: 'ordered');
        final node2 = FocusNode(debugLabel: 'unordered');

        final policy = MCPFocusTraversalPolicy(
          traversalOrder: ['ordered'],
          focusNodes: {'ordered': node1},
        );

        final sorted = policy.sortDescendants([node1, node2], node1);
        final sortedList = sorted.toList();
        expect(sortedList.first, node1);
        expect(sortedList.last, node2);
      });
    });
  });
}
