// `virtualized_list.dart` had 0 of 116 lines covered. Its entire reason to
// exist is a decision — build every child, or build the ones on screen — and
// nothing had ever checked which side of that decision it took.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/widgets/virtualized/virtualized_list.dart';

void main() {
  Widget host(Widget child) =>
      MaterialApp(home: Scaffold(body: SizedBox(height: 300, child: child)));

  List<String> items(int n) =>
      List<String>.generate(n, (i) => 'item-$i');

  group('VirtualizedListWidget', () {
    testWidgets('under the threshold every child is built', (tester) async {
      final built = <int>[];
      await tester.pumpWidget(host(VirtualizedListWidget(
        items: items(10),
        virtualizeThreshold: 100,
        itemBuilder: (context, item, index) {
          built.add(index);
          return SizedBox(height: 50, child: Text(item as String));
        },
      )));

      expect(built.length, 10,
          reason: 'below the threshold the list is a plain scroll view — the '
              'children exist whether or not they are on screen');
      expect(find.text('item-9', skipOffstage: false), findsOneWidget);
    });

    testWidgets('over the threshold only what is needed is built',
        (tester) async {
      final built = <int>[];
      await tester.pumpWidget(host(VirtualizedListWidget(
        items: items(500),
        virtualizeThreshold: 10,
        itemHeight: 50,
        itemBuilder: (context, item, index) {
          built.add(index);
          return SizedBox(height: 50, child: Text(item as String));
        },
      )));

      expect(built.length, lessThan(100),
          reason: 'a virtualized list that builds all 500 is not virtualized');
      expect(find.text('item-0'), findsOneWidget);
      expect(find.text('item-499', skipOffstage: false), findsNothing);
    });

    testWidgets('the item builder receives item and index in order',
        (tester) async {
      final pairs = <String>[];
      await tester.pumpWidget(host(VirtualizedListWidget(
        items: items(3),
        itemBuilder: (context, item, index) {
          pairs.add('$index:$item');
          return SizedBox(height: 50, child: Text(item as String));
        },
      )));
      expect(pairs, <String>['0:item-0', '1:item-1', '2:item-2']);
    });

    testWidgets('an empty list renders nothing and does not throw',
        (tester) async {
      await tester.pumpWidget(host(VirtualizedListWidget(
        items: const <dynamic>[],
        itemBuilder: (context, item, index) => const Text('never'),
      )));
      expect(find.text('never'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('horizontal lists scroll on the other axis', (tester) async {
      await tester.pumpWidget(host(VirtualizedListWidget(
        items: items(5),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, item, index) =>
            SizedBox(width: 80, child: Text(item as String)),
      )));
      expect(find.text('item-0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a controller the caller owns survives the widget',
        (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(host(VirtualizedListWidget(
        items: items(200),
        virtualizeThreshold: 10,
        controller: controller,
        itemBuilder: (context, item, index) =>
            SizedBox(height: 50, child: Text(item as String)),
      )));
      expect(controller.hasClients, isTrue);

      await tester.pumpWidget(host(const SizedBox.shrink()));

      // Disposing a controller it did not create would leave the caller
      // holding a dead object it is still responsible for.
      expect(() => controller.hasClients, returnsNormally);
      expect(controller.hasClients, isFalse);
    });
  });

  group('VirtualizedGridWidget', () {
    testWidgets('lays items out across the requested axis count',
        (tester) async {
      await tester.pumpWidget(host(VirtualizedGridWidget(
        items: items(6),
        crossAxisCount: 3,
        itemBuilder: (context, item, index) => Text(item as String),
      )));

      expect(find.text('item-0'), findsOneWidget);
      expect(find.text('item-5', skipOffstage: false), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a large grid virtualizes too', (tester) async {
      final built = <int>[];
      await tester.pumpWidget(host(VirtualizedGridWidget(
        items: items(400),
        crossAxisCount: 2,
        virtualizeThreshold: 10,
        itemBuilder: (context, item, index) {
          built.add(index);
          return Text(item as String);
        },
      )));
      expect(built.length, lessThan(200));
    });
  });
}
