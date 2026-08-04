// Does a declared route open in an application that has a navigation shell?
//
// The shell branch builds `MaterialApp(home: _ApplicationShell(...))`. The only
// `routes:` registration in `mcp_ui_runtime.dart` is the *other* branch, and
// there is no `onGenerateRoute` / `onUnknownRoute` anywhere in the file, while
// `navigation.push` calls `Navigator.pushNamed`. This asks the framework
// instead of reasoning from that.
//
// The action is deliberately **not** awaited: `pushNamed` completes when the
// pushed route is popped, so awaiting it hangs a test in the case where the
// push actually works — which is itself a signal, and was how this probe first
// told the two cases apart.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

String _describe(Object r) {
  final s = r.toString();
  return s.length > 120 ? '${s.substring(0, 120)}…' : s;
}

void main() {
  Map<String, dynamic> app({required bool withShell}) {
    final def = <String, dynamic>{
      'type': 'application',
      'title': 'Shell probe',
      'initialRoute': '/order',
      'routes': <String, dynamic>{
        '/order': 'ui://pages/order',
        '/pos': 'ui://pages/pos',
        '/detail': 'ui://pages/detail', // declared; no tab points at it
      },
    };
    if (withShell) {
      def['navigation'] = <String, dynamic>{
        'type': 'tabs',
        'items': <dynamic>[
          <String, dynamic>{'title': 'Order', 'route': '/order'},
          <String, dynamic>{'title': 'POS', 'route': '/pos'},
        ],
      };
    }
    return def;
  }

  final onScreen = <String>[];

  Future<String> probe(
    WidgetTester tester,
    String route, {
    required bool withShell,
  }) async {
    final runtime = MCPUIRuntime();
    await runtime.initialize(
      app(withShell: withShell),
      pageLoader: (uri) async => <String, dynamic>{
        'type': 'page',
        'content': <String, dynamic>{
          'type': 'text',
          'content': 'PAGE ${uri.split('/').last}',
        },
      },
    );
    await tester.pumpWidget(runtime.buildUI());
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final context = RenderContext(
      renderer: runtime.engine.renderer,
      stateManager: runtime.engine.stateManager,
      bindingEngine: runtime.engine.bindingEngine,
      actionHandler: runtime.engine.actionHandler,
      themeManager: runtime.engine.themeManager,
      engine: runtime.engine,
    );

    // Fire and forget — see the header note. The result is captured if it
    // completes: a push that lands does not complete until it is popped, so
    // an early completion is itself the failure signal.
    Object? early;
    // ignore: unawaited_futures
    runtime.engine.actionHandler
        .execute(
      <String, dynamic>{
        'type': 'navigation',
        'action': 'push',
        'route': route,
      },
      context,
    ).then((r) => early = r);
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    String on(String name) =>
        find.text('PAGE $name').evaluate().isEmpty ? '-' : name;
    final exception = tester.takeException();
    // The screen list is returned separately: asserting on the whole line
    // matched the route name in `push=/pos` and went green without anything
    // being drawn.
    final result = 'shell=$withShell push=$route '
        'screen=[${on('order')} ${on('pos')} ${on('detail')}] '
        'exception=${exception ?? 'none'} '
        'earlyResult=${early == null ? 'pending' : _describe(early!)} '
        'index=${runtime.stateManager.get('runtime.navigation.currentIndex')} '
        'currentRoute=${runtime.stateManager.get('runtime.navigation.currentRoute')}';
    onScreen
      ..clear()
      ..addAll([on('order'), on('pos'), on('detail')].where((e) => e != '-'));

    await runtime.destroy();
    return result;
  }

  testWidgets('CONTROL — no shell: a declared route opens', (tester) async {
    final r = await probe(tester, '/detail', withShell: false);
    debugPrint('PROBE $r');
    expect(onScreen, contains('detail'),
        reason: 'without a shell the route table is registered, so the '
            'declared page is reachable — this is the control that proves the '
            'probe can see a push land (the previous page stays mounted '
            'underneath, which is what a push means)');
  });

  testWidgets('shell: pushing a route a tab points at', (tester) async {
    final r = await probe(tester, '/pos', withShell: true);
    debugPrint('PROBE $r');
    expect(onScreen, contains('pos'),
        reason: 'a shell registers no route table, so pushNamed lands '
            'nowhere — measured 2026-08-04, silently and without an '
            'exception');
    // Regression: the shell branch built MaterialApp(home:) with no `routes:`,
    // so no named route resolved inside a shell — not even one a tab
    // pointed at.
  });

  testWidgets('shell: pushing a declared route no tab points at',
      (tester) async {
    final r = await probe(tester, '/detail', withShell: true);
    debugPrint('PROBE $r');
    expect(onScreen, contains('detail'),
        reason: 'a route declared in `routes` is a page the document can be '
            'sent to; a tab is one way to click there, not the definition of '
            'what exists');
  });
}
