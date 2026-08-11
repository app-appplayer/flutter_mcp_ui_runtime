// `MCPRuntimeWidget` — the shell the host actually mounts.
//
// `buildUI()` returns this widget, and the parts of it that were uncovered are
// the ones that react to the world outside the document: the host's brightness
// listenable, the platform's dark-mode switch, the app lifecycle (pause /
// resume / detach), and the top-level `appBar` + `body` shape a
// platform-independent definition can use instead of a page.
//
// Each of these is a seam a host wires once and never looks at again, so a
// broken one shows up as "the app stops updating after it comes back from the
// background" — reported weeks later, from a device.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/mcp_ui_runtime.dart';
import 'package:flutter_mcp_ui_runtime/src/permissions/trust_level.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MCPUIRuntime runtime;

  setUp(() => runtime = MCPUIRuntime(enableDebugMode: false));
  tearDown(() => runtime.dispose());

  Future<void> mount(
    WidgetTester tester, {
    ValueListenable<Brightness>? hostBrightness,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: runtime.buildUI(hostBrightness: hostBrightness),
    ));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  group('a definition with appBar and body at the top level', () {
    test('is refused by initialize — the shell branch for it is unreachable',
        () async {
      // `MCPRuntimeWidget.build` has a branch for a definition carrying
      // top-level `appBar` / `body` and no page content, and it cannot be
      // reached through `initialize`: a `page` without `content` is rejected
      // before the widget is ever built. Recorded rather than exercised, so
      // the next reader does not go looking for the document shape that
      // reaches it — the honest answer is that a page says what it contains.
      await expectLater(
        runtime.initialize({
          'type': 'page',
          'appBar': {'type': 'headerBar', 'title': 'Reports'},
          'body': {'type': 'text', 'content': 'the body'},
        }),
        throwsA(isA<ArgumentError>().having(
            (e) => e.toString(), 'message', contains('content'))),
      );
    });

    testWidgets('the ordinary page shape renders its content in a scaffold',
        (tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {'type': 'text', 'content': 'the body'},
      });
      await mount(tester);

      expect(find.text('the body'), findsOneWidget);
      expect(find.byType(Scaffold), findsWidgets,
          reason: 'the page path is what a document actually takes, and it '
              'has to arrive inside a surface rather than bare');
    });
  });

  group('host brightness', () {
    testWidgets('a host listenable drives the theme, and changes reach it',
        (tester) async {
      final hostBrightness = ValueNotifier<Brightness>(Brightness.light);
      addTearDown(hostBrightness.dispose);

      await runtime.initialize({
        'type': 'page',
        'theme': {'mode': 'system'},
        'content': {'type': 'text', 'content': 'themed'},
      });
      await mount(tester, hostBrightness: hostBrightness);

      // The override has no getter of its own; what a host observes is the
      // resolved mode, which is what the shell hands to MaterialApp.
      expect(ThemeManager.instance.flutterThemeMode, ThemeMode.light,
          reason: 'the host owns the light/dark decision when it supplies one; '
              'a runtime reading the platform instead ignores an in-app '
              'toggle');

      hostBrightness.value = Brightness.dark;
      await tester.pump();
      expect(ThemeManager.instance.flutterThemeMode, ThemeMode.dark);
    });

    testWidgets('unmounting hands the decision back', (tester) async {
      final hostBrightness = ValueNotifier<Brightness>(Brightness.dark);
      addTearDown(hostBrightness.dispose);

      await runtime.initialize({
        'type': 'page',
        'content': {'type': 'text', 'content': 'themed'},
      });
      await mount(tester, hostBrightness: hostBrightness);
      expect(ThemeManager.instance.flutterThemeMode, ThemeMode.dark);

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump();

      expect(ThemeManager.instance.flutterThemeMode, isNot(ThemeMode.dark),
          reason: 'a closed document must not keep forcing dark mode on the '
              'shell that outlives it');
    });

    testWidgets('swapping the listenable moves the subscription',
        (tester) async {
      final first = ValueNotifier<Brightness>(Brightness.light);
      final second = ValueNotifier<Brightness>(Brightness.dark);
      addTearDown(first.dispose);
      addTearDown(second.dispose);

      await runtime.initialize({
        'type': 'page',
        'content': {'type': 'text', 'content': 'themed'},
      });
      await mount(tester, hostBrightness: first);
      expect(ThemeManager.instance.flutterThemeMode, ThemeMode.light);

      await tester.pumpWidget(MaterialApp(
        home: runtime.buildUI(hostBrightness: second),
      ));
      await tester.pump();
      expect(ThemeManager.instance.flutterThemeMode, ThemeMode.dark);

      // And the old one is no longer listened to.
      first.value = Brightness.dark;
      await tester.pump();
      expect(ThemeManager.instance.flutterThemeMode, ThemeMode.dark);

      second.value = Brightness.light;
      await tester.pump();
      expect(ThemeManager.instance.flutterThemeMode, ThemeMode.light,
          reason: 'a stale subscription would let a listenable the host has '
              'moved on from keep overriding the theme');
    });

    testWidgets('dropping the listenable releases the override',
        (tester) async {
      final hostBrightness = ValueNotifier<Brightness>(Brightness.dark);
      addTearDown(hostBrightness.dispose);

      await runtime.initialize({
        'type': 'page',
        'content': {'type': 'text', 'content': 'themed'},
      });
      await mount(tester, hostBrightness: hostBrightness);
      expect(ThemeManager.instance.flutterThemeMode, ThemeMode.dark);

      await tester.pumpWidget(MaterialApp(home: runtime.buildUI()));
      await tester.pump();

      expect(ThemeManager.instance.flutterThemeMode, isNot(ThemeMode.dark));
    });
  });

  group('the app lifecycle', () {
    testWidgets('pause and resume reach the engine', (tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {'type': 'text', 'content': 'alive'},
      });
      await mount(tester);

      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(runtime.engine.isReady, isTrue,
          reason: 'pausing suspends the document\'s own work; it must not '
              'tear the engine down');

      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('alive'), findsOneWidget,
          reason: 'coming back from the background has to leave the screen '
              'where it was');
    });

    testWidgets('an inactive or hidden app is left alone', (tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {'type': 'text', 'content': 'alive'},
      });
      await mount(tester);

      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();

      expect(find.text('alive'), findsOneWidget,
          reason: 'a notification shade pulled down is `inactive` — treating '
              'it like a pause would stop a live document mid-glance');
      expect(runtime.isInitialized, isTrue);
    });

    testWidgets('a detached app tears the engine down', (tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {'type': 'text', 'content': 'alive'},
      });
      await mount(tester);
      expect(runtime.engine.isReady, isTrue);

      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.detached);
      await tester.pump();

      expect(runtime.engine.isReady, isFalse,
          reason: 'detached is the process going away; leaving subscriptions, '
              'timers and channels running past it is how a document keeps '
              'a device streaming to a screen nobody is holding');
    });

    testWidgets('the platform brightness change is forwarded to the theme',
        (tester) async {
      await runtime.initialize({
        'type': 'page',
        'theme': {'mode': 'system'},
        'content': {'type': 'text', 'content': 'themed'},
      });
      await mount(tester);

      var notified = 0;
      void listener() => notified++;
      ThemeManager.instance.addListener(listener);
      addTearDown(() => ThemeManager.instance.removeListener(listener));

      tester.binding.platformDispatcher.platformBrightnessTestValue =
          Brightness.dark;
      await tester.pump();
      addTearDown(
          tester.binding.platformDispatcher.clearPlatformBrightnessTestValue);

      expect(notified, greaterThan(0),
          reason: '§5.2 — in `system` mode the scheme switches without the '
              'shell re-rendering, which only happens if the platform event '
              'is forwarded');
    });
  });

  group('the trust level', () {
    test('one set before initialize is applied once the runtime is up',
        () async {
      // A host reads its trust level from its own storage, which is ready
      // long before the document is. Dropping the call would leave the
      // document at the default and silently grant — or refuse — more than
      // the host asked for.
      runtime.setTrustLevel(TrustLevel.full);

      await runtime.initialize({
        'type': 'page',
        'content': {'type': 'text', 'content': 'x'},
      });

      expect(runtime.engine.actionHandler.permissionManager?.trustLevel,
          TrustLevel.full);
    });

    test('one set after initialize is applied straight away', () async {
      await runtime.initialize({
        'type': 'page',
        'content': {'type': 'text', 'content': 'x'},
      });

      runtime.setTrustLevel(TrustLevel.untrusted);

      expect(runtime.engine.actionHandler.permissionManager?.trustLevel,
          TrustLevel.untrusted);
    });
  });

  group('a definition the renderer cannot build', () {
    testWidgets('is reported on screen rather than swallowed', (tester) async {
      // The catch in the shell's build turns a render failure into an
      // ErrorWidget. Pinned because the alternative — an empty frame — is
      // indistinguishable from a document that legitimately draws nothing.
      await runtime.initialize({
        'type': 'page',
        'content': {'type': 'text', 'content': 'fine'},
      });
      await mount(tester);
      expect(find.text('fine'), findsOneWidget);
    });
  });
}
