// Focus order — who receives the keyboard next.
//
// 58% covered, and the uncovered part is the traversal itself: next, previous,
// the wrap at either end, the groups, the custom policy. A document declaring
// an order and getting the tree's order instead is invisible to a sighted
// mouse user and is the whole experience for anyone on a keyboard or a screen
// reader.

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/accessibility/focus_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MCPFocusManager manager;

  setUp(() {
    manager = MCPFocusManager.instance;
    manager.clear();
  });

  tearDown(() => MCPFocusManager.instance.clear());

  /// Mounts three fields whose nodes are registered in the given order.
  Future<List<FocusNode>> mountThree(
    WidgetTester tester, {
    List<String> ids = const ['a', 'b', 'c'],
    String? groupId,
  }) async {
    final nodes = [for (var i = 0; i < ids.length; i++) FocusNode()];
    for (var i = 0; i < ids.length; i++) {
      manager.registerFocusNode(ids[i], nodes[i], groupId: groupId);
    }

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            for (var i = 0; i < ids.length; i++)
              TextField(focusNode: nodes[i], decoration: InputDecoration(labelText: ids[i])),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return nodes;
  }

  group('registration', () {
    testWidgets('a registered node can be looked up and focused',
        (tester) async {
      final nodes = await mountThree(tester);

      expect(manager.getFocusNode('b'), same(nodes[1]));
      manager.focus('b');
      await tester.pumpAndSettle();

      expect(nodes[1].hasFocus, isTrue);
    });

    testWidgets('focusing an id nobody registered does nothing', (tester) async {
      final nodes = await mountThree(tester);
      manager.focus('a');
      await tester.pumpAndSettle();

      manager.focus('nonexistent');
      await tester.pumpAndSettle();

      expect(nodes[0].hasFocus, isTrue,
          reason: 'a miss must not steal focus from wherever the user was');
      expect(manager.getFocusNode('nonexistent'), isNull);
    });

    testWidgets('an explicit order places the node in the traversal',
        (tester) async {
      final first = FocusNode();
      final second = FocusNode();
      final inserted = FocusNode();
      manager.registerFocusNode('first', first);
      manager.registerFocusNode('second', second);
      manager.registerFocusNode('inserted', inserted, order: 1);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(children: [
            TextField(focusNode: first),
            TextField(focusNode: second),
            TextField(focusNode: inserted),
          ]),
        ),
      ));
      await tester.pumpAndSettle();

      manager.focus('first');
      await tester.pumpAndSettle();
      manager.focusNext();
      await tester.pumpAndSettle();

      expect(inserted.hasFocus, isTrue,
          reason: 'the declared order decides who is next, not the order the '
              'widgets happen to appear in the tree');
    });

    testWidgets('unregistering removes it from the traversal', (tester) async {
      final nodes = await mountThree(tester);

      manager.unregisterFocusNode('b');
      expect(manager.getFocusNode('b'), isNull);

      manager.focus('a');
      await tester.pumpAndSettle();
      manager.focusNext();
      await tester.pumpAndSettle();

      expect(nodes[2].hasFocus, isTrue,
          reason: 'a removed node still in the order sends the keyboard to a '
              'field that is no longer there');
    });
  });

  group('traversal', () {
    testWidgets('next walks forward and wraps at the end', (tester) async {
      final nodes = await mountThree(tester);

      manager.focus('a');
      await tester.pumpAndSettle();
      manager.focusNext();
      await tester.pumpAndSettle();
      expect(nodes[1].hasFocus, isTrue);

      manager.focusNext();
      await tester.pumpAndSettle();
      expect(nodes[2].hasFocus, isTrue);

      manager.focusNext();
      await tester.pumpAndSettle();
      expect(nodes[0].hasFocus, isTrue,
          reason: 'tabbing off the end of a dialog has to come back round, or '
              'the keyboard user is stranded on the last field');
    });

    testWidgets('previous walks backward and wraps at the start',
        (tester) async {
      final nodes = await mountThree(tester);

      manager.focus('b');
      await tester.pumpAndSettle();
      manager.focusPrevious();
      await tester.pumpAndSettle();
      expect(nodes[0].hasFocus, isTrue);

      manager.focusPrevious();
      await tester.pumpAndSettle();
      expect(nodes[2].hasFocus, isTrue);
    });

    testWidgets('with the focus outside the registered set, next and previous '
        'leave it alone', (tester) async {
      // `primaryFocus` is never truly null in a mounted app — the scope holds
      // it — so the "nothing focused" branch belongs to a headless caller.
      // What a page can actually reach is this: the focus sits somewhere the
      // manager does not own, and neither call may yank it away.
      final nodes = await mountThree(tester);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      manager.focusNext();
      await tester.pumpAndSettle();
      expect(nodes.any((n) => n.hasFocus), isFalse,
          reason: 'a scope-level focus is not one of the registered nodes, so '
              'there is no "current" to step from');

      manager.focus('a');
      await tester.pumpAndSettle();
      manager.focusPrevious();
      await tester.pumpAndSettle();
      expect(nodes[2].hasFocus, isTrue,
          reason: 'and from a known node, previous still wraps to the last');
    });

    testWidgets('with nothing registered, next and previous do nothing',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('x'))));
      manager.focusNext();
      manager.focusPrevious();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('a focus held by something the manager does not know is left '
        'alone', (tester) async {
      final outsider = FocusNode();
      addTearDown(outsider.dispose);
      final nodes = await mountThree(tester);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(children: [
            TextField(focusNode: outsider),
            for (final node in nodes) TextField(focusNode: node),
          ]),
        ),
      ));
      outsider.requestFocus();
      await tester.pumpAndSettle();

      manager.focusNext();
      await tester.pumpAndSettle();

      expect(outsider.hasFocus, isTrue,
          reason: 'the manager owns its own order; yanking focus out of a '
              'field it never registered would fight the framework');
    });
  });

  group('groups', () {
    testWidgets('focusGroup lands on the first member', (tester) async {
      final nodes = await mountThree(tester, groupId: 'toolbar');

      manager.focusGroup('toolbar');
      await tester.pumpAndSettle();

      expect(nodes[0].hasFocus, isTrue);
    });

    testWidgets('a group nobody declared is a no-op', (tester) async {
      final nodes = await mountThree(tester, groupId: 'toolbar');
      manager.focus('b');
      await tester.pumpAndSettle();

      manager.focusGroup('imaginary');
      await tester.pumpAndSettle();

      expect(nodes[1].hasFocus, isTrue);
    });

    testWidgets('trapping and releasing a group is recorded', (tester) async {
      await mountThree(tester, groupId: 'dialog');

      manager.trapFocus('dialog');
      manager.releaseFocusTrap('dialog');
      // Both on a group that does not exist, too — neither may throw, because
      // a dialog closing after its group was cleared hits exactly this.
      manager.trapFocus('gone');
      manager.releaseFocusTrap('gone');
      expect(tester.takeException(), isNull);
    });

    testWidgets('unregistering removes the node from its group too',
        (tester) async {
      final nodes = await mountThree(tester, groupId: 'toolbar');

      manager.unregisterFocusNode('a');
      manager.focusGroup('toolbar');
      await tester.pumpAndSettle();

      expect(nodes[1].hasFocus, isTrue,
          reason: 'a group still holding a disposed node would focus nothing '
              'and swallow the keyboard');
    });
  });

  group('FocusGroup', () {
    test('holds its nodes in the order they were added', () {
      final group = FocusGroup('g');
      final a = FocusNode();
      final b = FocusNode();
      addTearDown(a.dispose);
      addTearDown(b.dispose);

      group.addNode('a', a);
      group.addNode('b', b);
      expect(group.nodeIds, ['a', 'b']);
      expect(group.nodes['b'], same(b));

      group.removeNode('a');
      expect(group.nodeIds, ['b']);
      expect(group.nodes.containsKey('a'), isFalse);
      expect(group.trapFocus, isFalse);
    });
  });

  group('MCPFocusTraversalPolicy', () {
    late FocusNode a;
    late FocusNode b;
    late FocusNode c;
    late MCPFocusTraversalPolicy policy;

    setUp(() {
      a = FocusNode(debugLabel: 'a');
      b = FocusNode(debugLabel: 'b');
      c = FocusNode(debugLabel: 'c');
      policy = MCPFocusTraversalPolicy(
        traversalOrder: const ['a', 'b', 'c'],
        focusNodes: {'a': a, 'b': b, 'c': c},
      );
    });

    tearDown(() {
      a.dispose();
      b.dispose();
      c.dispose();
    });

    test('first and last come from the declared order', () {
      expect(policy.findFirstFocus(b), same(a));
      expect(policy.findLastFocus(b), same(c));
    });

    test('an empty order falls back to the node it was asked about', () {
      const empty = MCPFocusTraversalPolicy(
          traversalOrder: [], focusNodes: <String, FocusNode>{});
      expect(empty.findFirstFocus(b), same(b));
      expect(empty.findLastFocus(b), same(b));
    });

    test('up and left go to the first, down and right to the last', () {
      expect(policy.findFirstFocusInDirection(b, TraversalDirection.up),
          same(a));
      expect(policy.findFirstFocusInDirection(b, TraversalDirection.left),
          same(a));
      expect(policy.findFirstFocusInDirection(b, TraversalDirection.down),
          same(c));
      expect(policy.findFirstFocusInDirection(b, TraversalDirection.right),
          same(c));
    });

    testWidgets('inDirection moves along the declared order and reports '
        'whether it moved', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(children: [
            TextField(focusNode: a),
            TextField(focusNode: b),
            TextField(focusNode: c),
          ]),
        ),
      ));
      await tester.pumpAndSettle();

      expect(policy.inDirection(a, TraversalDirection.down), isTrue);
      await tester.pumpAndSettle();
      expect(b.hasFocus, isTrue);

      expect(policy.inDirection(b, TraversalDirection.up), isTrue);
      await tester.pumpAndSettle();
      expect(a.hasFocus, isTrue);

      expect(policy.inDirection(a, TraversalDirection.up), isFalse,
          reason: 'false at the boundary is what lets the surrounding scope '
              'take over instead of the focus sticking');
      expect(policy.inDirection(c, TraversalDirection.down), isFalse);
    });

    test('a node outside the policy does not move anything', () {
      final stranger = FocusNode();
      addTearDown(stranger.dispose);
      expect(policy.inDirection(stranger, TraversalDirection.down), isFalse);
    });

    test('sortDescendants puts the declared order first', () {
      final sorted = policy.sortDescendants([c, a, b], a).toList();
      expect(sorted.take(3), [a, b, c],
          reason: 'this is what makes Tab follow the document rather than the '
              'widget tree');
    });
  });

  group('SkipToContent', () {
    testWidgets('is announced as a button and calls back when used',
        (tester) async {
      var skipped = 0;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SkipToContent(onSkip: () => skipped++)),
      ));

      final semantics = tester.widget<Semantics>(find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.button == true));
      expect(semantics.properties.label, 'Skip to main content',
          reason: 'the label IS the control for a screen-reader user — it is '
              'deliberately invisible on screen');

      await tester.tap(find.byType(SkipToContent));
      await tester.pumpAndSettle();
      expect(skipped, 1);
    });
  });

  group('clear', () {
    testWidgets('forgets every node, order and group', (tester) async {
      await mountThree(tester, groupId: 'toolbar');

      manager.clear();

      expect(manager.getFocusNode('a'), isNull);
      manager.focusNext();
      manager.focusGroup('toolbar');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
