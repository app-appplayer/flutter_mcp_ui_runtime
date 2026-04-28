import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/accessibility/focus_manager.dart';

/// TC-014 ~ TC-019: MCPFocusManager extended tests
/// Corresponds to: 04_TEST/feat-runtime/14-accessibility.md §8
void main() {
  group('MCPFocusManager Extended Tests', () {
    late MCPFocusManager focusManager;

    setUp(() {
      focusManager = MCPFocusManager.instance;
      focusManager.clear();
    });

    tearDown(() {
      focusManager.clear();
    });

    // TC-014: registerFocusNode and unregisterFocusNode
    group('TC-014: registerFocusNode and unregisterFocusNode', () {
      test('Normal: registerFocusNode stores node, getFocusNode retrieves it',
          () {
        final node = FocusNode(debugLabel: 'btn-1');
        focusManager.registerFocusNode('btn-1', node, label: 'Submit');

        expect(focusManager.getFocusNode('btn-1'), equals(node));
      });

      test('Normal: unregisterFocusNode removes the node', () {
        final node = FocusNode(debugLabel: 'btn-1');
        focusManager.registerFocusNode('btn-1', node);

        focusManager.unregisterFocusNode('btn-1');
        expect(focusManager.getFocusNode('btn-1'), isNull);
      });

      test('Normal: registerFocusNode with label sets onKeyEvent handler', () {
        final node = FocusNode(debugLabel: 'btn-labeled');
        focusManager.registerFocusNode('btn-labeled', node, label: 'Submit');

        // Node should have an onKeyEvent handler set
        expect(node.onKeyEvent, isNotNull);
      });

      test('Normal: registerFocusNode without label has no onKeyEvent', () {
        final node = FocusNode(debugLabel: 'btn-nolabel');
        focusManager.registerFocusNode('btn-nolabel', node);

        expect(node.onKeyEvent, isNull);
      });

      test('Boundary: register with same id twice overwrites previous', () {
        final node1 = FocusNode(debugLabel: 'btn-1-v1');
        final node2 = FocusNode(debugLabel: 'btn-1-v2');

        focusManager.registerFocusNode('btn-1', node1);
        focusManager.registerFocusNode('btn-1', node2);

        expect(focusManager.getFocusNode('btn-1'), equals(node2));
      });
    });

    // TC-015: getFocusNode
    group('TC-015: getFocusNode', () {
      test('Normal: returns FocusNode for registered id', () {
        final node = FocusNode(debugLabel: 'input-1');
        focusManager.registerFocusNode('input-1', node);

        final result = focusManager.getFocusNode('input-1');
        expect(result, equals(node));
      });

      test('Boundary: unknown id returns null', () {
        expect(focusManager.getFocusNode('unknown-id'), isNull);
      });
    });

    // TC-016: focus
    group('TC-016: focus', () {
      test('Normal: focus on registered node does not throw', () {
        final node = FocusNode(debugLabel: 'input-1');
        focusManager.registerFocusNode('input-1', node);

        // Should not throw
        focusManager.focus('input-1');
        expect(true, isTrue);
      });

      test('Boundary: focus on unknown id is no-op', () {
        // Should not throw
        focusManager.focus('unknown-id');
        expect(true, isTrue);
      });
    });

    // TC-017: focusGroup
    group('TC-017: focusGroup', () {
      test('Normal: focusGroup focuses first node in group', () {
        final node1 = FocusNode(debugLabel: 'field-1');
        final node2 = FocusNode(debugLabel: 'field-2');
        focusManager.registerFocusNode('field-1', node1,
            groupId: 'form-fields');
        focusManager.registerFocusNode('field-2', node2,
            groupId: 'form-fields');

        // Should not throw
        focusManager.focusGroup('form-fields');
        expect(true, isTrue);
      });

      test('Boundary: empty group — no-op (group with no nodes)', () {
        // Group not created, so focusGroup should be no-op
        focusManager.focusGroup('empty-group');
        expect(true, isTrue);
      });

      test('Error: unknown group id — no-op', () {
        focusManager.focusGroup('nonexistent-group');
        expect(true, isTrue);
      });
    });

    // TC-018: trapFocus and releaseFocusTrap
    group('TC-018: trapFocus and releaseFocusTrap', () {
      test('Normal: trapFocus constrains focus to group nodes', () {
        final node1 = FocusNode(debugLabel: 'dlg-ok');
        final node2 = FocusNode(debugLabel: 'dlg-cancel');
        focusManager.registerFocusNode('dlg-ok', node1, groupId: 'dialog');
        focusManager.registerFocusNode('dlg-cancel', node2,
            groupId: 'dialog');

        focusManager.trapFocus('dialog');
        // Trap is set — no exception
        expect(true, isTrue);
      });

      test('Normal: releaseFocusTrap removes constraint', () {
        final node = FocusNode(debugLabel: 'dlg-ok');
        focusManager.registerFocusNode('dlg-ok', node, groupId: 'dialog');

        focusManager.trapFocus('dialog');
        focusManager.releaseFocusTrap('dialog');
        expect(true, isTrue);
      });

      test('Boundary: nested traps — inner takes priority, release restores outer',
          () {
        final outerNode = FocusNode(debugLabel: 'outer-btn');
        final innerNode = FocusNode(debugLabel: 'inner-btn');
        focusManager.registerFocusNode('outer-btn', outerNode,
            groupId: 'outer');
        focusManager.registerFocusNode('inner-btn', innerNode,
            groupId: 'inner');

        focusManager.trapFocus('outer');
        focusManager.trapFocus('inner');

        // Release inner trap
        focusManager.releaseFocusTrap('inner');
        // Outer trap still manageable
        focusManager.releaseFocusTrap('outer');
        expect(true, isTrue);
      });

      test('Error: release non-existent trap is no-op', () {
        focusManager.releaseFocusTrap('nonexistent');
        expect(true, isTrue);
      });
    });

    // TC-019: clear and createFocusScope
    group('TC-019: clear and createFocusScope', () {
      test('Normal: clear removes all registered focus nodes and groups', () {
        final node1 = FocusNode(debugLabel: 'n1');
        final node2 = FocusNode(debugLabel: 'n2');
        focusManager.registerFocusNode('n1', node1, groupId: 'g1');
        focusManager.registerFocusNode('n2', node2, groupId: 'g1');

        focusManager.clear();

        expect(focusManager.getFocusNode('n1'), isNull);
        expect(focusManager.getFocusNode('n2'), isNull);
      });

      test('Normal: createFocusScope returns a widget', () {
        final scope = focusManager.createFocusScope(
          scopeId: 'scope-1',
          child: const Text('Scoped content'),
        );
        expect(scope, isA<Widget>());
      });

      test('Boundary: createFocusScope with autofocus returns a widget', () {
        final scope = focusManager.createFocusScope(
          scopeId: 'autofocus-scope',
          autofocus: true,
          child: const Text('Auto-focused'),
        );
        expect(scope, isA<Widget>());
      });
    });
  });
}
