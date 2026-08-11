// Traversal with nothing focused yet.
//
// `focusNext` / `focusPrevious` open with "if nothing has focus, take the
// first / last one". In a mounted app the focus scope always holds SOMETHING,
// so that opening is not a widget-test shape — it is what a caller reaches
// before any of it is on screen: a document restoring focus on entry, a host
// driving the order from outside a frame. Left unrun, the first Tab of a
// keyboard session was the one path nobody had measured.
//
// Off a tree, `requestFocus` cannot grant focus — there is no scope to grant
// it — so what is asserted is that the manager ASKED, and asked the right
// node.

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/accessibility/focus_manager.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingFocusNode extends FocusNode {
  _RecordingFocusNode(String label) : super(debugLabel: label);

  int requests = 0;

  @override
  void requestFocus([FocusNode? node]) {
    requests++;
    super.requestFocus(node);
  }
}

void main() {
  late MCPFocusManager manager;
  late List<_RecordingFocusNode> nodes;

  setUp(() {
    manager = MCPFocusManager.instance..clear();
    nodes = <_RecordingFocusNode>[];
    for (final id in const ['a', 'b', 'c']) {
      final node = _RecordingFocusNode(id);
      nodes.add(node);
      manager.registerFocusNode(id, node);
    }
  });

  // `clear()` owns the nodes it was handed and disposes them.
  tearDown(() => MCPFocusManager.instance.clear());

  test('with nothing focused, next takes the first in declared order', () {
    expect(FocusManager.instance.primaryFocus, isNull,
        reason: 'the state this branch is written for — no tree, so no scope '
            'holding the focus');

    manager.focusNext();

    expect(nodes[0].requests, 1,
        reason: 'a keyboard user tabbing into a fresh page lands on the first '
            'declared field; asking nobody is a page that cannot be entered '
            'from the keyboard at all');
    expect(nodes[1].requests, 0);
    expect(nodes[2].requests, 0);
  });

  test('with nothing focused, previous takes the last', () {
    manager.focusPrevious();

    expect(nodes[2].requests, 1,
        reason: 'shift-Tab enters from the end, which is what makes the order '
            'symmetric');
    expect(nodes[0].requests, 0);
  });

  test('with no nodes registered at all, neither throws', () {
    manager.clear();

    expect(manager.focusNext, returnsNormally);
    expect(manager.focusPrevious, returnsNormally);
  });
}
