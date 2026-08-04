// The dashboard host — the widget a host mounts for a `dashboard` definition.
//
// It is where every host seam is wired: the tool executor, the resource
// subscribe/unsubscribe pair, exit and open-app callbacks, host brightness,
// the refresh timer, and the post-frame `markReady` that lets a definition's
// `onReady` start its subscriptions. Each of those is a closure stored
// somewhere else, so the failure mode is always the same shape — a host
// feature that is simply never reached.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

void main() {
  /// §11.9: the dashboard is a block *inside* an application definition, and
  /// the host mounts it with `buildDashboard()` rather than `buildUI()`.
  Map<String, dynamic> dashboard({Map<String, dynamic>? lifecycle}) =>
      <String, dynamic>{
        'type': 'application',
        'title': 'Line 3',
        'initialRoute': '/home',
        'routes': <String, dynamic>{'/home': 'ui://pages/home'},
        if (lifecycle != null) 'lifecycle': lifecycle,
        'dashboard': <String, dynamic>{
          'content': <String, dynamic>{'type': 'text', 'content': 'gauge'},
        },
      };

  testWidgets('a dashboard renders its content', (tester) async {
    final runtime = MCPUIRuntime();
    await runtime.initialize(
      dashboard(),
      pageLoader: (uri) async => <String, dynamic>{
        'type': 'page',
        'content': <String, dynamic>{'type': 'text', 'content': 'home'},
      },
    );
    await tester.pumpWidget(MaterialApp(home: runtime.buildDashboard()!));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('gauge'), findsOneWidget);
    await runtime.destroy();
  });

  testWidgets('mounting marks the runtime ready after the first frame',
      (tester) async {
    final runtime = MCPUIRuntime();
    await runtime.initialize(
      dashboard(),
      pageLoader: (uri) async => <String, dynamic>{
        'type': 'page',
        'content': <String, dynamic>{'type': 'text', 'content': 'home'},
      },
    );
    expect(runtime.isReady, isFalse);

    await tester.pumpWidget(MaterialApp(home: runtime.buildDashboard()!));
    await tester.pump();

    expect(runtime.isReady, isTrue,
        reason: 'readiness is what lets a definition-level onReady start its '
            'subscriptions; without it a live dashboard never asks for data');
    await runtime.destroy();
  });

  testWidgets('a definition-level onReady runs once mounted', (tester) async {
    final runtime = MCPUIRuntime();
    await runtime.initialize(
      dashboard(lifecycle: <String, dynamic>{
      'onReady': <dynamic>[
        <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'started',
          'value': true,
        },
      ],
    }),
      pageLoader: (uri) async => <String, dynamic>{
        'type': 'page',
        'content': <String, dynamic>{'type': 'text', 'content': 'home'},
      },
    );

    await tester.pumpWidget(MaterialApp(home: runtime.buildDashboard()!));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(runtime.stateManager.get<bool>('started'), isTrue);
    await runtime.destroy();
  });

  testWidgets('the host tool callback receives calls from the definition',
      (tester) async {
    final runtime = MCPUIRuntime();
    final calls = <String>[];
    await runtime.initialize(
      dashboard(lifecycle: <String, dynamic>{
      'onReady': <dynamic>[
        <String, dynamic>{
          'type': 'tool',
          'tool': 'refresh',
          'params': <String, dynamic>{'zone': 'north'},
        },
      ],
    }),
      pageLoader: (uri) async => <String, dynamic>{
        'type': 'page',
        'content': <String, dynamic>{'type': 'text', 'content': 'home'},
      },
    );

    await tester.pumpWidget(MaterialApp(
      home: runtime.buildDashboard(
        onToolCall: (tool, params) {
          calls.add('$tool:${params['zone']}');
        },
      )!,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(calls, <String>['refresh:north'],
        reason: 'the executor is registered in initState, so a hook firing on '
            'the first frame has to find it already there');
    await runtime.destroy();
  });

  testWidgets('host brightness drives the theme and is released on dispose',
      (tester) async {
    final runtime = MCPUIRuntime();
    await runtime.initialize(
      dashboard(),
      pageLoader: (uri) async => <String, dynamic>{
        'type': 'page',
        'content': <String, dynamic>{'type': 'text', 'content': 'home'},
      },
    );
    final brightness = ValueNotifier<Brightness>(Brightness.dark);

    await tester.pumpWidget(MaterialApp(
      home: runtime.buildDashboard(hostBrightness: brightness)!,
    ));
    await tester.pump();

    expect(runtime.engine.themeManager.flutterThemeMode, ThemeMode.dark);

    brightness.value = Brightness.light;
    await tester.pump();
    expect(runtime.engine.themeManager.flutterThemeMode, ThemeMode.light,
        reason: 'a host that flips its own brightness expects the surface to '
            'follow without a rebuild of the definition');

    // Unmounting must let the notifier go: a listener left behind fires into
    // a disposed theme manager the next time the host changes brightness.
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    expect(() => brightness.value = Brightness.dark, returnsNormally);

    brightness.dispose();
    await runtime.destroy();
  });

  testWidgets('the exit callback is registered for the definition',
      (tester) async {
    final runtime = MCPUIRuntime();
    var exited = 0;
    await runtime.initialize(
      dashboard(),
      pageLoader: (uri) async => <String, dynamic>{
        'type': 'page',
        'content': <String, dynamic>{'type': 'text', 'content': 'home'},
      },
    );

    await tester.pumpWidget(MaterialApp(
      home: runtime.buildDashboard(onExit: () => exited++)!,
    ));
    await tester.pump();

    await runtime.engine.actionHandler.execute(
      <String, dynamic>{'type': 'navigation', 'action': 'exitApp'},
      runtime.engine.renderer.createRootContext(null),
    );

    expect(exited, 1);
    await runtime.destroy();
  });
}
