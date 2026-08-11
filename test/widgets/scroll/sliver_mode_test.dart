// `scrollView.slivers` — the second layout mode of §2.9.1.
//
// The spec declares five sliver shapes and the runtime had none of them: the
// entries were laid out as ordinary children, so `sliverAppBar` reached the
// widget registry, found no factory, and drew an unknown-type box inside the
// page. These tests ask what a sliver is *for* — does the bar collapse, does
// the header stay while its section scrolls, do the fixed-extent rows all
// measure the same — because a `CustomScrollView` that merely builds proves
// none of that.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

Future<void> _pumpPage(
  WidgetTester tester,
  Map<String, dynamic> content, {
  Map<String, dynamic> state = const {},
}) async {
  final runtime = MCPUIRuntime();
  await runtime.initialize(<String, dynamic>{
    'type': 'page',
    'content': content,
    'runtime': <String, dynamic>{
      'services': <String, dynamic>{
        'state': <String, dynamic>{'initialState': state},
      },
    },
  });
  addTearDown(runtime.dispose);
  await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: runtime.buildUI())));
  await tester.pump();
}

void main() {
  testWidgets('sliver mode builds a sliver viewport, not a linear one',
      (tester) async {
    await _pumpPage(tester, <String, dynamic>{
      'type': 'scrollView',
      'slivers': [
        <String, dynamic>{
          'type': 'sliverAppBar',
          'expandedHeight': 240,
          'pinned': true,
          'title': <String, dynamic>{'type': 'text', 'content': 'Library'},
        },
      ],
    });

    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(find.byType(SliverAppBar), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    // The shape that used to happen: the sliver fell through to the widget
    // registry and reported itself unknown.
    expect(find.textContaining('Unknown widget type'), findsNothing);
  });

  testWidgets('a pinned sliverAppBar collapses to its bar and stays',
      (tester) async {
    await _pumpPage(tester, <String, dynamic>{
      'type': 'scrollView',
      'slivers': [
        <String, dynamic>{
          'type': 'sliverAppBar',
          'expandedHeight': 240,
          'pinned': true,
          'title': <String, dynamic>{'type': 'text', 'content': 'Library'},
        },
        <String, dynamic>{
          'type': 'sliverFixedExtentList',
          'itemExtent': 60,
          'items': '{{books}}',
          'itemTemplate': <String, dynamic>{
            'type': 'text',
            'content': '{{item.title}}',
          },
        },
      ],
    }, state: <String, dynamic>{
      'books': [
        for (var i = 0; i < 30; i++) {'title': 'Book $i'},
      ],
    });

    // Measured on the box the bar builds: a sliver has no `RenderBox` size of
    // its own, and the question here is how much of the screen it occupies.
    final bar = find.descendant(
        of: find.byType(SliverAppBar), matching: find.byType(AppBar));
    final expanded = tester.getSize(bar).height;
    expect(expanded, greaterThan(200),
        reason: 'expandedHeight was declared as 240');

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pump();

    final collapsed = tester.getSize(bar).height;
    expect(collapsed, lessThan(expanded),
        reason: 'a collapsing bar that never collapses is a plain header');
    expect(find.text('Library'), findsOneWidget,
        reason: 'pinned: the bar stays on screen after the scroll');
  });

  testWidgets('sliverList renders one child per bound item', (tester) async {
    await _pumpPage(tester, <String, dynamic>{
      'type': 'scrollView',
      'slivers': [
        <String, dynamic>{
          'type': 'sliverList',
          'items': '{{books}}',
          'itemTemplate': <String, dynamic>{
            'type': 'text',
            'content': '{{item.title}}',
          },
        },
      ],
    }, state: <String, dynamic>{
      'books': [
        {'title': 'Dune'},
        {'title': 'Solaris'},
      ],
    });

    expect(find.text('Dune'), findsOneWidget);
    expect(find.text('Solaris'), findsOneWidget);
  });

  testWidgets('sliverList also takes literal children', (tester) async {
    await _pumpPage(tester, <String, dynamic>{
      'type': 'scrollView',
      'slivers': [
        <String, dynamic>{
          'type': 'sliverList',
          'children': [
            <String, dynamic>{'type': 'text', 'content': 'first'},
            <String, dynamic>{'type': 'text', 'content': 'second'},
          ],
        },
      ],
    });

    expect(find.text('first'), findsOneWidget);
    expect(find.text('second'), findsOneWidget);
  });

  testWidgets('sliverFixedExtentList gives every row the declared extent',
      (tester) async {
    await _pumpPage(tester, <String, dynamic>{
      'type': 'scrollView',
      'slivers': [
        <String, dynamic>{
          'type': 'sliverFixedExtentList',
          'itemExtent': 60,
          'children': [
            <String, dynamic>{'type': 'text', 'content': 'a'},
            <String, dynamic>{'type': 'text', 'content': 'b'},
          ],
        },
      ],
    });

    final first = tester.getRect(find.text('a'));
    final second = tester.getRect(find.text('b'));
    expect(second.top - first.top, closeTo(60, 0.5),
        reason: 'itemExtent is what makes this list fixed-extent');
  });

  testWidgets('sliverGrid lays items out across the declared columns',
      (tester) async {
    await _pumpPage(tester, <String, dynamic>{
      'type': 'scrollView',
      'slivers': [
        <String, dynamic>{
          'type': 'sliverGrid',
          'columns': 2,
          'children': [
            <String, dynamic>{'type': 'text', 'content': 'a'},
            <String, dynamic>{'type': 'text', 'content': 'b'},
            <String, dynamic>{'type': 'text', 'content': 'c'},
          ],
        },
      ],
    });

    final a = tester.getRect(find.text('a'));
    final b = tester.getRect(find.text('b'));
    final c = tester.getRect(find.text('c'));
    expect(b.top, closeTo(a.top, 0.5),
        reason: 'two columns: the second item shares the first row');
    expect(c.top, greaterThan(a.top),
        reason: 'the third item wraps to the next row');
  });

  testWidgets('a pinned sliverPersistentHeader stays while its section scrolls',
      (tester) async {
    await _pumpPage(tester, <String, dynamic>{
      'type': 'scrollView',
      'slivers': [
        <String, dynamic>{
          'type': 'sliverPersistentHeader',
          'pinned': true,
          'minExtent': 40,
          'maxExtent': 40,
          'child': <String, dynamic>{'type': 'text', 'content': 'Section A'},
        },
        <String, dynamic>{
          'type': 'sliverFixedExtentList',
          'itemExtent': 60,
          'items': '{{rows}}',
          'itemTemplate': <String, dynamic>{
            'type': 'text',
            'content': '{{item}}',
          },
        },
      ],
    }, state: <String, dynamic>{
      'rows': [for (var i = 0; i < 30; i++) 'row $i'],
    });

    expect(find.text('Section A'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pump();
    expect(find.text('Section A'), findsOneWidget,
        reason: 'pinned: the header is what does not scroll away');
  });

  testWidgets('an undefined sliver shape is refused at load', (tester) async {
    // `Sliver` is a closed set of five shapes, so the load gate is where a
    // sixth is caught — before anything is drawn. The factory keeps a branch
    // for it anyway: a host may load with `validateSchema: false`, and a
    // viewport that silently skips one entry looks like a layout bug in the
    // entries around it.
    final runtime = MCPUIRuntime();
    addTearDown(runtime.dispose);

    await expectLater(
      runtime.initialize(<String, dynamic>{
        'type': 'page',
        'content': <String, dynamic>{
          'type': 'scrollView',
          'slivers': [
            <String, dynamic>{'type': 'sliverCarousel'},
          ],
        },
      }),
      throwsA(isA<StateError>()),
    );
  });

  testWidgets('with the gate off, an undefined shape reports in place',
      (tester) async {
    final runtime = MCPUIRuntime();
    addTearDown(runtime.dispose);
    await runtime.initialize(<String, dynamic>{
      'type': 'page',
      'content': <String, dynamic>{
        'type': 'scrollView',
        'slivers': [
          <String, dynamic>{'type': 'sliverCarousel'},
          <String, dynamic>{
            'type': 'sliverList',
            'children': [
              <String, dynamic>{'type': 'text', 'content': 'after'},
            ],
          },
        ],
      },
    }, validateSchema: false);
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: runtime.buildUI())));
    await tester.pump();

    expect(find.textContaining('unknown sliver type: sliverCarousel'),
        findsOneWidget);
    expect(find.text('after'), findsOneWidget,
        reason: 'the entries around the bad one still render');
  });

  testWidgets('the collapsed bar takes the colour the document declares',
      (tester) async {
    // The hero fades out as the bar collapses and the bar's own surface is
    // what is left. Reported from a real screen: a `title` colour picked
    // against the hero became unreadable at that moment, and the document had
    // no way to name the surface underneath — the key was silently dropped.
    await _pumpPage(tester, <String, dynamic>{
      'type': 'scrollView',
      'slivers': [
        <String, dynamic>{
          'type': 'sliverAppBar',
          'expandedHeight': 200,
          'pinned': true,
          'backgroundColor': '#FF00FF00',
          'foregroundColor': '#FFFF0000',
          'background': <String, dynamic>{'type': 'box', 'color': '#FF0000FF'},
          'title': <String, dynamic>{'type': 'text', 'content': 'Library'},
        },
        <String, dynamic>{
          'type': 'sliverFixedExtentList',
          'itemExtent': 60,
          'items': '{{rows}}',
          'itemTemplate': <String, dynamic>{
            'type': 'text',
            'content': '{{item}}',
          },
        },
      ],
    }, state: <String, dynamic>{
      'rows': [for (var i = 0; i < 30; i++) 'row \$i'],
    });

    final bar = tester.widget<AppBar>(find.descendant(
        of: find.byType(SliverAppBar), matching: find.byType(AppBar)));
    expect(bar.backgroundColor, const Color(0xFF00FF00));
    expect(bar.foregroundColor, const Color(0xFFFF0000));

    // And it survives the collapse — the point of declaring it.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pump();
    final collapsed = tester.widget<AppBar>(find.descendant(
        of: find.byType(SliverAppBar), matching: find.byType(AppBar)));
    expect(collapsed.backgroundColor, const Color(0xFF00FF00));
    expect(find.text('Library'), findsOneWidget);
  });

  // Reported from a real screen: in the same slot — a child of a vertical
  // `linear`, which gives unbounded height — `children` drew and `slivers` drew
  // nothing, with no error and no log. One widget, two modes, and the
  // difference arrived as silence. Split in two because a single test that
  // pumps twice reuses the element tree and measures the first frame again.
  testWidgets('linear mode draws in an unbounded parent', (tester) async {
    await _pumpPage(tester, <String, dynamic>{
      'type': 'linear',
      'direction': 'vertical',
      'children': [
        <String, dynamic>{
          'type': 'scrollView',
          'children': [
            <String, dynamic>{'type': 'text', 'content': 'LINEAR-MODE'},
          ],
        },
      ],
    });
    expect(find.text('LINEAR-MODE'), findsOneWidget);
  });

  testWidgets('sliver mode draws in an unbounded parent too', (tester) async {
    await _pumpPage(tester, <String, dynamic>{
      'type': 'linear',
      'direction': 'vertical',
      'children': [
        <String, dynamic>{
          'type': 'scrollView',
          'slivers': [
            <String, dynamic>{
              'type': 'sliverList',
              'children': [
                <String, dynamic>{'type': 'text', 'content': 'SLIVER-MODE'},
              ],
            },
          ],
        },
      ],
    });
    expect(find.text('SLIVER-MODE'), findsOneWidget,
        reason: 'sliver mode drew nothing where linear mode drew');
    expect(find.byType(CustomScrollView), findsOneWidget);
  });

  testWidgets('sliverList takes an inline array as well as a binding',
      (tester) async {
    // `list` / `grid` accept `items` as an array or a binding; the sliver
    // shapes declared the binding string alone, so the ordinary inline form
    // was refused at load in slivers and nowhere else.
    await _pumpPage(tester, <String, dynamic>{
      'type': 'scrollView',
      'slivers': [
        <String, dynamic>{
          'type': 'sliverList',
          'items': ['Dune', 'Solaris'],
          'itemTemplate': <String, dynamic>{
            'type': 'text',
            'content': '{{item}}',
          },
        },
      ],
    });
    expect(find.text('Dune'), findsOneWidget);
    expect(find.text('Solaris'), findsOneWidget);
  });

  testWidgets('linear mode is untouched by sliver mode', (tester) async {
    await _pumpPage(tester, <String, dynamic>{
      'type': 'scrollView',
      'direction': 'vertical',
      'children': [
        <String, dynamic>{'type': 'text', 'content': 'Hello'},
        <String, dynamic>{'type': 'text', 'content': 'World'},
      ],
    });

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.byType(CustomScrollView), findsNothing);
    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('World'), findsOneWidget);
  });
}
