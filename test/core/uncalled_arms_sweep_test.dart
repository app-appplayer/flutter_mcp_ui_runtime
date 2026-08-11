// Arms nothing had taken, gathered from across the runtime.
//
// None of these is a subsystem — each is one branch inside one that is
// otherwise well covered: the shape a document writes less often, the answer
// a host gives when it cannot do something, the fallback that only matters
// once the happy path has already failed. They are grouped here because they
// share a failure mode rather than a file: each is silent, and each is the
// only thing standing between a declaration and a page that quietly ignores
// it.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_expression.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/resource_binding_resolver.dart';
import 'package:flutter_mcp_ui_runtime/src/assets/asset_ref.dart';
import 'package:flutter_mcp_ui_runtime/src/capabilities/runtime_capabilities.dart';
import 'package:flutter_mcp_ui_runtime/src/client_resources/client_resource_resolver.dart'
    show ClientResourceResolver;
import 'package:flutter_mcp_ui_runtime/src/client_resources/resource_dependency_resolver.dart';
import 'package:flutter_mcp_ui_runtime/src/core/client_resource_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/core/service_locator.dart';
import 'package:flutter_mcp_ui_runtime/src/models/app_metadata.dart';
import 'package:flutter_mcp_ui_runtime/src/models/ui_definition.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A service that moves its own status the way a real one does — a connection
/// that drops after startup is not a failure to initialize, and the setter is
/// how a subclass says so.
class _Service extends BaseService {
  @override
  Future<void> onInitialize() async {}

  @override
  Future<void> onDispose() async {}

  void connectionLost() => status = ServiceStatus.error;
}

/// A widget that reads its services through the mixin rather than the static.
class _MixinReader extends StatefulWidget {
  const _MixinReader();

  @override
  State<_MixinReader> createState() => _MixinReaderState();
}

class _MixinReaderState extends State<_MixinReader>
    with ServiceLocatorMixin<_MixinReader> {
  @override
  Widget build(BuildContext context) =>
      Text(serviceLocator.isRegistered<String>() ? 'has string' : 'none');
}

void main() {
  group('ServiceProvider.maybeOf', () {
    testWidgets('answers null above the provider and the locator below it',
        (tester) async {
      final locator = ServiceLocator()..register<String>('hello');
      ServiceLocator? outside;
      ServiceLocator? inside;

      await tester.pumpWidget(Builder(builder: (above) {
        outside = ServiceProvider.maybeOf(above);
        return ServiceProvider(
          serviceLocator: locator,
          child: Builder(builder: (below) {
            inside = ServiceProvider.maybeOf(below);
            return const SizedBox();
          }),
        );
      }));

      expect(outside, isNull,
          reason: '`maybeOf` exists so a widget can work with or without a '
              'runtime around it; throwing where `of` throws would make the '
              'two the same call');
      expect(inside, same(locator));
    });

    testWidgets('the mixin reads the same locator', (tester) async {
      final locator = ServiceLocator()..register<String>('hello');

      await tester.pumpWidget(MaterialApp(
        home: ServiceProvider(
          serviceLocator: locator,
          child: const _MixinReader(),
        ),
      ));

      expect(find.text('has string'), findsOneWidget,
          reason: 'the mixin is the door most widgets use; a getter that '
              'answered a different locator would hand out services from '
              'another runtime');
    });
  });

  group('BaseService', () {
    test('a subclass moves its own status through the protected setter',
        () async {
      final service = _Service();
      expect(service.status, ServiceStatus.uninitialized);

      await service.initialize();
      expect(service.status, ServiceStatus.ready);

      service.connectionLost();
      expect(service.status, ServiceStatus.error,
          reason: 'the status is what a host polls to decide whether the '
              'runtime is usable; a setter that did not take would leave a '
              'broken service reporting "ready" forever');

      await service.dispose();
      expect(service.status, ServiceStatus.disposed);
    });
  });

  group('a resource path through untyped maps', () {
    test('state-shaped data is walked like JSON-shaped data', () {
      // A resource loaded from JSON is `Map<String, dynamic>`; one that came
      // back through state is `Map<dynamic, dynamic>`. A resolver that reads
      // only the typed form answers null for the second, so the same binding
      // works or does not depending on where the data has been.
      final resolver = ResourceBindingResolver()
        ..updateResourceData('profile', <dynamic, dynamic>{
          'address': <dynamic, dynamic>{'city': 'Seoul'},
        });

      expect(resolver.resolve('{{resources.profile.address.city}}'), 'Seoul');
      expect(resolver.resolve('{{resources.profile.address.zip}}'), isNull);
      expect(resolver.resolve('{{resources.profile.address.city.deeper}}'), isNull,
          reason: 'walking into a string has no answer, and inventing one '
              'would hide the author\'s mistake');
    });
  });

  group('a dependency on something that was never declared', () {
    test('is refused by name before anything is loaded', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'mcp_client_cache_theme': '{"primary":"#000"}',
      });
      final resources = ClientResourceResolver();
      await resources.init();
      final resolver = ResourceDependencyResolver(resources);

      // A typo in `dependsOn` is not a cycle. Left to the topological loop it
      // would simply never become ready, and the only symptom would be a page
      // that never finishes loading — so it is caught up front and named.
      expect(
        () => resolver.resolve(const [
          ResourceDeclaration(
            key: 'theme',
            source: 'client://cache/theme',
            dependsOn: ['confg'],
          ),
        ]),
        throwsA(isA<ArgumentError>().having(
            (e) => e.message.toString(), 'message', allOf(
          contains('theme'),
          contains('confg'),
        ))),
        reason: 'the author has to be told which resource and which missing '
            'key, or the typo is invisible',
      );
    });
  });

  group('ClientResourceManager', () {
    setUp(ClientResourceManager.resetInstance);

    test('a failed entry under cacheOnly falls back rather than refetching',
        () async {
      var calls = 0;
      final manager = ClientResourceManager.instance
        ..setFetcher((uri) async {
          calls++;
          throw StateError('offline');
        });

      // The entry is left in the cache in an error state, which is the case
      // `cacheOnly` has no answer for: there is something cached and it is
      // not usable, and going to the network is exactly what the strategy
      // forbids.
      const uri = 'client://config/failed-only';
      expect(await manager.fetch(const ResourceFetchConfig(uri: uri)), isNull);
      expect(calls, 1);

      final result = await manager.fetch(const ResourceFetchConfig(
        uri: uri,
        strategy: CachingStrategy.cacheOnly,
        fallback: ResourceFallback(value: 'placeholder'),
      ));

      expect(calls, 1,
          reason: 'cacheOnly must not reach the network even when what it '
              'holds is unusable — that is the whole declaration');
      expect(result, 'placeholder',
          reason: 'and a failed entry is not an answer, so the declared '
              'fallback is what the page shows');
    });

    test('binary data is measured against the limit by length', () {
      final uri = ClientResourceUri.parse('client://cache/blob')!;
      final limit = ResourceSizeLimits.limitFor(uri);

      expect(ResourceSizeLimits.validate(uri, Uint8List(16)), isNull);
      expect(ResourceSizeLimits.validate(uri, Uint8List(limit + 1)), isNotNull,
          reason: 'a byte list that skipped the check is how a device runs '
              'out of memory holding a file it should have refused');
      expect(ResourceSizeLimits.validate(uri, DateTime.now()), isNull,
          reason: 'an object with no length cannot be measured, and guessing '
              'would refuse things that are fine');
    });

    test('a fallback declares its three shapes independently', () {
      const fallback = ResourceFallback(
        value: 'last resort',
        alternativeUri: 'client://cache/backup',
        useLastKnown: true,
      );

      expect(fallback.value, 'last resort');
      expect(fallback.alternativeUri, 'client://cache/backup');
      expect(fallback.useLastKnown, isTrue);
      expect(const ResourceFallback().useLastKnown, isFalse,
          reason: 'defaulting to "use the last known value" would serve stale '
              'data to documents that never asked for it');
    });
  });

  group('capabilities a host may not have', () {
    test('a player that cannot produce a waveform says so', () {
      expect(_MinimalPlayer().waveform, isNull,
          reason: '§6.13.2: a widget that asked for a waveform and got '
              'nothing has to report it, and it can only report what the '
              'capability admits');
    });

    test('SurfaceAssets forwards the read it was built with', () async {
      AssetRef? asked;
      final assets = SurfaceAssets((ref) async {
        asked = ref;
        return null;
      });

      expect(await assets.read(AssetRef.parse('bundle://logo.png')!), isNull);
      expect(asked, isNotNull,
          reason: 'a surface that cannot read bundle assets is one that works '
              'for images and fails for a PDF in the same bundle');
    });
  });

  group('document shapes', () {
    test('a page carries its themeOverride through', () {
      final page = UIDefinition.fromJson(<String, dynamic>{
        'type': 'page',
        'title': 'Settings',
        'route': '/settings',
        'themeOverride': <String, dynamic>{
          'colors': <String, dynamic>{'primary': '#FF0000FF'},
        },
        'content': <String, dynamic>{'type': 'text', 'content': 'hi'},
      });

      expect(page.properties['themeOverride'], isA<Map<String, dynamic>>(),
          reason: 'a page that declares its own theme and renders in the '
              'app\'s is the declaration being dropped in transit');
      expect(page.properties['title'], 'Settings');
      expect(page.properties['route'], '/settings');
    });

    test('app metadata parses a splash block', () {
      final meta = DslAppMetadata.fromJson(<String, dynamic>{
        'name': 'demo',
        'version': '1.0.0',
        'splash': <String, dynamic>{
          'backgroundColor': '#FF000000',
          'duration': 1200,
        },
      });

      expect(meta.splash, isNotNull,
          reason: '§11.2 splash is what the host shows before the first '
              'frame; dropping it means the app opens on a white flash');
      expect(DslAppMetadata.fromJson(<String, dynamic>{'name': 'x'}).splash, isNull);
    });

    test('a channel merges its lifecycle block into params', () {
      final channel = ChannelConfig.fromJson(<String, dynamic>{
        'type': 'websocket',
        'params': <String, dynamic>{'url': 'ws://host'},
        'lifecycle': <String, dynamic>{
          'autoStart': true,
          'autoDispose': true,
        },
      });

      expect(channel.autoStart, isTrue);
      expect(channel.autoDispose, isTrue);
      expect(channel.params, containsPair('url', 'ws://host'),
          reason: 'the lifecycle block must be added to the params, not '
              'replace them — a merge that drops the url leaves the channel '
              'with nowhere to connect');
      expect(channel.params, containsPair('autoStart', true));
    });
  });

  group('unary not', () {
    test('parses and evaluates', () {
      final expression = BindingExpression.parse('!enabled');
      expect(expression.operator, '!');

      final state = StateManager()..initialize(<String, dynamic>{'enabled': false});
      final engine = BindingEngine();
      final actions = ActionHandler();
      final context = RenderContext(
        renderer: Renderer(
          widgetRegistry: WidgetRegistry(),
          bindingEngine: engine,
          actionHandler: actions,
          stateManager: state,
        ),
        stateManager: state,
        bindingEngine: engine,
        actionHandler: actions,
        themeManager: ThemeManager.instance,
      );

      expect(engine.resolve<bool>('{{!enabled}}', context), isTrue,
          reason: '`{{!enabled}}` is how a document hides a widget while a '
              'flag is off; a parser that does not know `!` reads it as a '
              'path and answers null, which is falsey — so the widget stays '
              'visible exactly when it should not');
    });
  });

  group('a numeric font weight', () {
    tearDown(() => ThemeManager.instance.reset());

    test('is snapped to the nearest declared step in both directions', () {
      final theme = ThemeManager.instance..reset();
      theme.setTheme(<String, dynamic>{
        'typography': <String, dynamic>{
          'labelSmall': <String, dynamic>{'fontSize': 10, 'fontWeight': 40},
          'displayLarge': <String, dynamic>{'fontSize': 40, 'fontWeight': 5000},
          'bodyLarge': <String, dynamic>{'fontSize': 14, 'fontWeight': 650},
        },
      });

      expect(theme.getTextStyleValue('labelSmall')?.fontWeight, FontWeight.w100,
          reason: 'a weight below the scale clamps to the lightest rather '
              'than falling off it');
      expect(theme.getTextStyleValue('displayLarge')?.fontWeight, FontWeight.w900);
      expect(theme.getTextStyleValue('bodyLarge')?.fontWeight, FontWeight.w600,
          reason: 'a value between steps takes the step below, so a theme '
              'is never silently rendered at the default weight');
    });
  });
}

/// The smallest thing that can claim to be a media session.
/// It `extends` rather than `implements` on purpose: `waveform` has a default
/// body, and inheriting it is what a host that does not produce waveforms
/// actually does.
class _MinimalPlayer extends MediaSession {
  @override
  Stream<Duration> get position => const Stream.empty();

  @override
  Stream<Duration?> get duration => const Stream.empty();

  @override
  Stream<bool> get playing => const Stream.empty();

  @override
  Stream<void> get ended => const Stream.empty();

  @override
  Stream<Object> get errors => const Stream.empty();

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> setMuted(bool muted) async {}

  @override
  Future<void> dispose() async {}
}
