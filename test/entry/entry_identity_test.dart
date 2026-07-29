import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

/// MCP UI DSL §8.9 — entry & identity.
///
/// Each group pins one contract of the spec section. The bindings are read
/// through a real runtime rather than a stubbed state map, because the
/// failure this suite exists to catch is "the value is set but the screen
/// never sees it".
void main() {
  Map<String, dynamic> appWithRoutes() => <String, dynamic>{
        'type': 'application',
        'title': 'Entry Test App',
        'initialRoute': '/home',
        'routes': <String, dynamic>{
          '/home': 'ui://pages/home',
          '/contact': 'ui://pages/contact',
        },
      };

  Future<MCPUIRuntime> boot({
    EntryContext? entry,
    IdentityContext? identity,
    String? launchRoute,
  }) async {
    final runtime = MCPUIRuntime();
    await runtime.initialize(
      appWithRoutes(),
      pageLoader: (uri) async => <String, dynamic>{
        'type': 'page',
        'content': <String, dynamic>{'type': 'text', 'content': uri},
      },
      entry: entry,
      identity: identity,
      launchRoute: launchRoute,
    );
    return runtime;
  }

  /// A root context wired to the real engine — the identity executor reads
  /// its session through `context.engine`.
  RenderContext rootContext(MCPUIRuntime runtime) => RenderContext(
        renderer: runtime.engine.renderer,
        stateManager: runtime.engine.stateManager,
        bindingEngine: runtime.engine.bindingEngine,
        actionHandler: runtime.engine.actionHandler,
        themeManager: runtime.engine.themeManager,
        engine: runtime.engine,
      );

  group('§8.9.6 inert without host support', () {
    test('every binding resolves to null when nothing was adopted', () async {
      final runtime = await boot();
      final context = rootContext(runtime);

      expect(context.resolve<dynamic>('{{entry.route}}'), isNull);
      expect(context.resolve<dynamic>('{{entry.params.plate}}'), isNull);
      expect(context.resolve<dynamic>('{{entry.issuer.name}}'), isNull);
      expect(context.resolve<dynamic>('{{entry.canSteward}}'), isNull);
      expect(context.resolve<dynamic>('{{identity.subject.ref}}'), isNull);
      await runtime.destroy();
    });

    test('a null binding never throws', () async {
      final runtime = await boot();
      final context = rootContext(runtime);
      expect(
        () => context.resolve<dynamic>('{{entry.deeply.absent.path}}'),
        returnsNormally,
      );
      await runtime.destroy();
    });
  });

  group('§8.9.2 bindings', () {
    late MCPUIRuntime runtime;

    setUp(() async {
      runtime = await boot(
        entry: EntryContext(
          route: '/contact',
          params: <String, dynamic>{'plate': 'AB-1234'},
          issuer: const EntryIssuer(name: 'Fleet Co', verified: true),
          grantScope: <String>['relay.notify'],
          canSteward: false,
          notice: EntryNotice.fromWire('custodyChanged', 'Contact updated'),
        ),
        identity: const IdentityContext(canPromote: true),
      );
    });

    tearDown(() async => runtime.destroy());

    test('entry.* resolves the adopted entry', () {
      final c = rootContext(runtime);
      expect(c.resolve<dynamic>('{{entry.route}}'), '/contact');
      expect(c.resolve<dynamic>('{{entry.params.plate}}'), 'AB-1234');
      expect(c.resolve<dynamic>('{{entry.issuer.name}}'), 'Fleet Co');
      expect(c.resolve<dynamic>('{{entry.issuer.verified}}'), isTrue);
      expect(c.resolve<dynamic>('{{entry.canSteward}}'), isFalse);
      expect(c.resolve<dynamic>('{{entry.notice.kind}}'), 'custodyChanged');
    });

    test('identity defaults to guest', () {
      final c = rootContext(runtime);
      expect(c.resolve<dynamic>('{{identity.state}}'), 'guest');
      expect(c.resolve<dynamic>('{{identity.subject.kind}}'), 'guest');
    });

    test('entry.params is not route.params', () {
      final c = rootContext(runtime);
      // The scan context lives under `entry`, and `route.params` stays empty:
      // collapsing the two loses the scan on the first navigation.
      expect(c.resolve<dynamic>('{{entry.params.plate}}'), 'AB-1234');
      expect(c.resolve<dynamic>('{{route.params.plate}}'), isNull);
    });

    test('an unknown notice kind is carried as advisory, not dropped', () {
      final notice = EntryNotice.fromWire('somethingNewer', 'text');
      expect(notice.kind, 'advisory');
      expect(notice.message, 'text');
    });
  });

  group('§8.9.4 reactivity', () {
    test('adopting an identity re-resolves bindings in place', () async {
      final runtime = await boot(
        entry: EntryContext(route: '/home'),
        identity: const IdentityContext(canPromote: true),
      );
      final c = rootContext(runtime);
      expect(c.resolve<dynamic>('{{identity.state}}'), 'guest');

      runtime.entrySession.adoptIdentity(
        const IdentityContext(
          state: IdentityState.identified,
          subjectKind: IdentitySubjectKind.user,
          subjectRef: 'u-1',
        ),
      );

      expect(c.resolve<dynamic>('{{identity.state}}'), 'identified');
      expect(c.resolve<dynamic>('{{identity.subject.kind}}'), 'user');
      expect(c.resolve<dynamic>('{{identity.subject.ref}}'), 'u-1');
      await runtime.destroy();
    });

    test('a state listener fires on identity change', () async {
      final runtime = await boot(identity: const IdentityContext());
      var notified = 0;
      void listener() => notified++;
      runtime.stateManager.addListener(listener);

      runtime.entrySession.adoptIdentity(
        const IdentityContext(state: IdentityState.identified),
      );
      expect(notified, greaterThan(0),
          reason: 'binding re-evaluation depends on this notification');

      runtime.stateManager.removeListener(listener);
      await runtime.destroy();
    });

    test('adopting an identical identity does not churn', () async {
      final runtime = await boot(identity: const IdentityContext());
      var notified = 0;
      void listener() => notified++;
      runtime.stateManager.addListener(listener);

      runtime.entrySession.adoptIdentity(const IdentityContext());
      expect(notified, 0);

      runtime.stateManager.removeListener(listener);
      await runtime.destroy();
    });
  });

  group('launch route (platform spec 19 §4.3)', () {
    test('an entry route becomes the initial route', () async {
      final runtime = await boot(entry: EntryContext(route: '/contact'));
      expect(runtime.engine.routeManager!.initialRoute, '/contact');
      expect(runtime.engine.routeManager!.launchRouteMissing, isFalse);
      await runtime.destroy();
    });

    test('no entry leaves the document initial route alone', () async {
      final runtime = await boot();
      expect(runtime.engine.routeManager!.initialRoute, '/home');
      await runtime.destroy();
    });

    test('an in-app open sets the route without inventing an entry', () async {
      // §8.9.1 — a navigation action is not an arrival. If it left an entry
      // tree behind, a document asking "was I scanned?" would read every
      // app-to-app open as a scan.
      final runtime = await boot(launchRoute: '/contact');
      final c = rootContext(runtime);

      expect(runtime.engine.routeManager!.initialRoute, '/contact');
      expect(c.resolve<dynamic>('{{entry.route}}'), isNull);
      expect(runtime.entrySession.entry, isNull);
      await runtime.destroy();
    });

    test('an entry route wins over a plain launch route', () async {
      final runtime = await boot(
        entry: EntryContext(route: '/contact'),
        launchRoute: '/home',
      );
      expect(runtime.engine.routeManager!.initialRoute, '/contact');
      await runtime.destroy();
    });

    test('a route the document no longer has is not honoured silently',
        () async {
      final runtime = await boot(entry: EntryContext(route: '/removed'));
      // Falls back, but reports that it did — a stale binding must not look
      // like a working one.
      expect(runtime.engine.routeManager!.initialRoute, '/home');
      expect(runtime.engine.routeManager!.launchRouteMissing, isTrue);
      await runtime.destroy();
    });
  });

  group('§8.9.3 actions', () {
    testWidgets('promote runs the host handler and changes state',
        (tester) async {
      final runtime = await boot(
        identity: const IdentityContext(canPromote: true),
      );
      runtime.entrySession.registerPromotion(
        onPromote: () async => const IdentityPromotion.promoted(
          IdentityContext(
            state: IdentityState.identified,
            subjectKind: IdentitySubjectKind.user,
            subjectRef: 'u-9',
          ),
        ),
        onRelease: () async =>
            const IdentityPromotion.promoted(IdentityContext(canPromote: true)),
      );

      final context = rootContext(runtime);
      final result = await runtime.engine.actionHandler.execute(
        <String, dynamic>{'type': 'identity.promote'},
        context,
      );

      expect(result.success, isTrue);
      expect((result.data as Map)['changed'], isTrue);
      expect(runtime.entrySession.identity.isIdentified, isTrue);
      expect(context.resolve<dynamic>('{{identity.state}}'), 'identified');
      await runtime.destroy();
    });

    testWidgets('release returns to guest', (tester) async {
      final runtime = await boot(
        identity: const IdentityContext(
          state: IdentityState.identified,
          subjectKind: IdentitySubjectKind.user,
          subjectRef: 'u-9',
        ),
      );
      runtime.entrySession.registerPromotion(
        onRelease: () async =>
            const IdentityPromotion.promoted(IdentityContext()),
      );

      final context = rootContext(runtime);
      final result = await runtime.engine.actionHandler.execute(
        <String, dynamic>{'type': 'identity.release'},
        context,
      );

      expect(result.success, isTrue);
      expect(runtime.entrySession.identity.state, IdentityState.guest);
      await runtime.destroy();
    });

    testWidgets('promote is unsupported, not an error, with no host handler',
        (tester) async {
      final runtime = await boot(
        identity: const IdentityContext(canPromote: true),
      );
      final context = rootContext(runtime);
      final result = await runtime.engine.actionHandler.execute(
        <String, dynamic>{'type': 'identity.promote'},
        context,
      );

      expect(result.success, isTrue,
          reason: 'a document must degrade, not fail (§8.9.6)');
      expect((result.data as Map)['supported'], isFalse);
      expect((result.data as Map)['outcome'], 'unavailable');
      await runtime.destroy();
    });

    testWidgets('canPromote is false when the host wired no promoter',
        (tester) async {
      final runtime = await boot(
        identity: const IdentityContext(canPromote: true),
      );
      final context = rootContext(runtime);
      // The document asked for a sign-in affordance; this host cannot perform
      // one, so the binding must not offer a dead button.
      expect(context.resolve<dynamic>('{{identity.canPromote}}'), isFalse);

      runtime.entrySession.registerPromotion(
        onPromote: () async => const IdentityPromotion.promoted(
          IdentityContext(state: IdentityState.identified),
        ),
      );
      expect(context.resolve<dynamic>('{{identity.canPromote}}'), isTrue);
      await runtime.destroy();
    });

    testWidgets('a declined promotion leaves identity untouched',
        (tester) async {
      final runtime = await boot(
        identity: const IdentityContext(canPromote: true),
      );
      runtime.entrySession
          .registerPromotion(onPromote: () async => const IdentityPromotion.declined());

      final context = rootContext(runtime);
      final result = await runtime.engine.actionHandler.execute(
        <String, dynamic>{'type': 'identity.promote'},
        context,
      );

      expect(result.success, isTrue);
      expect((result.data as Map)['changed'], isFalse);
      // A decline is not an impossibility: the document may reasonably offer
      // sign-in again, which it cannot decide if both look the same.
      expect((result.data as Map)['outcome'], 'declined');
      expect((result.data as Map)['supported'], isTrue);
      expect(runtime.entrySession.identity.state, IdentityState.guest);
      await runtime.destroy();
    });

    testWidgets('a failed promotion is distinguishable from a decline',
        (tester) async {
      final runtime = await boot(
        identity: const IdentityContext(canPromote: true),
      );
      runtime.entrySession.registerPromotion(
        onPromote: () async => const IdentityPromotion.failed(),
      );
      final context = rootContext(runtime);
      final result = await runtime.engine.actionHandler.execute(
        <String, dynamic>{'type': 'identity.promote'},
        context,
      );
      expect((result.data as Map)['outcome'], 'failed');
      expect((result.data as Map)['changed'], isFalse);
      expect(runtime.entrySession.identity.state, IdentityState.guest);
      await runtime.destroy();
    });

    testWidgets('a host reporting unavailable does not change identity',
        (tester) async {
      final runtime = await boot(
        identity: const IdentityContext(canPromote: true),
      );
      runtime.entrySession.registerPromotion(
        onPromote: () async => const IdentityPromotion.unavailable(),
      );
      final context = rootContext(runtime);
      final result = await runtime.engine.actionHandler.execute(
        <String, dynamic>{'type': 'identity.promote'},
        context,
      );
      expect((result.data as Map)['outcome'], 'unavailable');
      expect((result.data as Map)['supported'], isFalse);
      await runtime.destroy();
    });

    testWidgets('the canonical sub-operation form dispatches too',
        (tester) async {
      final runtime = await boot(
        identity: const IdentityContext(canPromote: true),
      );
      runtime.entrySession.registerPromotion(
        onPromote: () async => const IdentityPromotion.promoted(
          IdentityContext(state: IdentityState.identified),
        ),
      );
      final context = rootContext(runtime);
      final result = await runtime.engine.actionHandler.execute(
        <String, dynamic>{'type': 'identity', 'action': 'promote'},
        context,
      );
      expect(result.success, isTrue);
      expect(runtime.entrySession.identity.isIdentified, isTrue);
      await runtime.destroy();
    });
  });

  group('§8.9.2 read-only', () {
    testWidgets('a state action cannot assign entry.* or identity.*',
        (tester) async {
      final runtime = await boot(
        entry: EntryContext(route: '/home', canSteward: false),
      );
      final context = rootContext(runtime);

      for (final path in <String>[
        'entry.canSteward',
        'identity.state',
        'entry',
      ]) {
        final result = await runtime.engine.actionHandler.execute(
          <String, dynamic>{
            'type': 'state',
            'action': 'set',
            'binding': path,
            'value': true,
          },
          context,
        );
        expect(result.success, isFalse, reason: '$path must be read-only');
      }

      // The forged steward affordance never materialized.
      expect(context.resolve<dynamic>('{{entry.canSteward}}'), isFalse);
      await runtime.destroy();
    });

    testWidgets('document state cannot shadow entry.* or identity.*',
        (tester) async {
      final runtime = await boot(
        entry: EntryContext(route: '/home', canSteward: false),
        identity: const IdentityContext(),
      );
      final context = rootContext(runtime);

      // Writing `entry.*` directly is rejected, but a document may freely
      // write its OWN page/app state — and `page.entry` must not become the
      // value `{{entry.*}}` resolves to. Without a dedicated resolution
      // branch the generic fallback searches page state first, which lets a
      // definition forge itself a steward affordance and a launch route.
      runtime.stateManager.set('page.entry', <String, dynamic>{
        'canSteward': true,
        'route': '/forged',
      });
      runtime.stateManager.set('app.identity', <String, dynamic>{
        'state': 'identified',
      });

      expect(context.resolve<dynamic>('{{entry.canSteward}}'), isFalse);
      expect(context.resolve<dynamic>('{{entry.route}}'), '/home');
      expect(context.resolve<dynamic>('{{identity.state}}'), 'guest');
      await runtime.destroy();
    });

    test('a neighbouring root that merely starts with the same letters is not locked',
        () {
      expect(EntryStateKeys.isReadOnly('entryPoint.foo'), isFalse);
      expect(EntryStateKeys.isReadOnly('identityish'), isFalse);
      expect(EntryStateKeys.isReadOnly('entry.params.x'), isTrue);
      expect(EntryStateKeys.isReadOnly('identity'), isTrue);
    });
  });
}
