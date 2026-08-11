// The host-facing registration surface of `MCPUIRuntime`.
//
// Every one of these is a seam a host wires once and never thinks about again:
// how a `view` resolves a definition, how a tool call reaches another origin,
// how a `client.mcpStream` channel finds its stream. Each one guards on
// "initialized first", and none of those guards had ever been executed — which
// means the failure mode nobody had watched is the one where a host registers
// too early, gets no complaint, and the seam is quietly never wired.

import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MCPUIRuntime runtime;

  Map<String, dynamic> page() => {
        'type': 'page',
        'content': {'type': 'text', 'content': 'hello'},
      };

  setUp(() => runtime = MCPUIRuntime());
  tearDown(() => runtime.destroy());

  group('before initialize, every registration is refused', () {
    test('and the message says what has to happen first', () {
      expect(
        () => runtime.registerDefinitionResolver((ref, origin) async => {}),
        throwsA(isA<StateError>().having((e) => e.toString(), 'message',
            contains('initialized'))),
      );
      expect(
        () => runtime.registerOriginToolCaller((origin, tool, params) async {}),
        throwsStateError,
      );
      expect(
        () => runtime.registerOriginResourceWatcher(
            (origin, uri, onUpdate) async => () {}),
        throwsStateError,
      );
      expect(
        () => runtime.registerOriginResourceReader((origin, uri) async => null),
        throwsStateError,
      );
      expect(
        () => runtime.registerStreamSource('mcp', (uri, params) => const Stream.empty()),
        throwsStateError,
      );
      expect(
        () => runtime.registerPermissionHandler((_) {}),
        throwsStateError,
      );
      expect(
        () => runtime.registerClientActionHandler('custom', (_) async {}),
        throwsStateError,
      );
    });

    test('and the read-only accessors answer null instead of throwing', () {
      // A host that asks before initializing gets nothing, not an exception:
      // these are checked on paths where throwing would take down a shell that
      // is merely eager.
      expect(runtime.permissionManager, isNull);
      expect(runtime.channelManager, isNull);
    });

    test('buildUI before initialize is refused', () {
      expect(() => runtime.buildUI(), throwsStateError);
    });
  });

  group('after initialize', () {
    setUp(() async => runtime.initialize(page()));

    test('each seam is accepted and reaches the engine', () async {
      runtime.registerDefinitionResolver((ref, origin) async => {'type': 'text'});
      runtime.registerOriginToolCaller((origin, tool, params) async => 'ok');
      runtime.registerOriginResourceWatcher(
          (origin, uri, onUpdate) async => () {});
      runtime.registerOriginResourceReader((origin, uri) async => 'contents');
      runtime.registerPermissionHandler((_) {});
      runtime.registerClientActionHandler('custom', (_) async => 'done');

      expect(runtime.engine.renderer.definitionResolver, isNotNull);
      expect(runtime.engine.renderer.originToolCaller, isNotNull);
      expect(runtime.engine.renderer.originResourceWatcher, isNotNull);
      expect(runtime.engine.renderer.originResourceReader, isNotNull);
      expect(runtime.permissionManager, isNotNull);
      expect(runtime.channelManager, isNotNull);
    });

    test('a stream source is found by the scheme of the uri', () async {
      final opened = <String>[];
      runtime.registerStreamSource('mcp', (uri, params) {
        opened.add(uri);
        return Stream<dynamic>.value({'tick': 1});
      });

      final resolver = runtime.channelManager!.streamSourceResolver;
      expect(resolver, isNotNull,
          reason: 'registering a source has to wire the channel manager, or a '
              'mcpStream channel starts and finds nothing');

      final stream = resolver!('mcp://feed/one', const {});
      expect(stream, isNotNull);
      expect(await stream!.first, {'tick': 1});
      expect(opened, ['mcp://feed/one']);
    });

    test('a uri whose scheme nobody registered resolves to nothing', () {
      runtime.registerStreamSource('mcp', (uri, params) => const Stream.empty());
      final resolver = runtime.channelManager!.streamSourceResolver!;

      expect(resolver('other://feed', const {}), isNull,
          reason: 'answering the wrong source would be worse than answering '
              'none: the channel would deliver another origin\'s data');
      expect(resolver('no-scheme-at-all', const {}), isNull);
    });

    test('two schemes can be registered side by side', () async {
      runtime.registerStreamSource('mcp', (uri, params) => Stream.value('a'));
      runtime.registerStreamSource('ws', (uri, params) => Stream.value('b'));
      final resolver = runtime.channelManager!.streamSourceResolver!;

      expect(await resolver('mcp://x', const {})!.first, 'a');
      expect(await resolver('ws://y', const {})!.first, 'b');
    });
  });

  group('trust level', () {
    test('set before initialize is remembered and applied afterwards',
        () async {
      // A host reads its trust level from its own config, which is ready long
      // before a document is. Dropping it here would silently run a bundle at
      // the default level.
      runtime.setTrustLevel(TrustLevel.full);
      await runtime.initialize(page());
      expect(runtime.permissionManager?.trustLevel, TrustLevel.full);
    });

    test('set after initialize takes effect immediately', () async {
      await runtime.initialize(page());
      runtime.setTrustLevel(TrustLevel.untrusted);
      expect(runtime.permissionManager?.trustLevel, TrustLevel.untrusted);
    });
  });

  group('initialize', () {
    test('a definition that is neither a page nor an application is refused',
        () {
      expect(
        () => runtime.initialize({'runtime': <String, dynamic>{}}),
        throwsA(isA<ArgumentError>().having((e) => e.toString(), 'message',
            contains('application or page'))),
        reason: 'the message has to name what was expected, or a host debugging '
            'a bundle has only "invalid" to go on',
      );
    });

    test('initializing twice is refused', () async {
      await runtime.initialize(page());
      expect(() => runtime.initialize(page()), throwsStateError,
          reason: 'a second initialize would leave the first document\'s state '
              'and channels behind with nothing owning them');
    });

    test('hasDashboard answers for a page document', () async {
      await runtime.initialize(page());
      expect(runtime.hasDashboard, isFalse);
    });
  });
}
