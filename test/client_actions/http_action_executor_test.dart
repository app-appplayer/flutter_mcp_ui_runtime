// `client.http` — the executor a document uses to reach a server that is not
// its MCP host.
//
// It was 41% covered, which is what you get from testing the two refusals and
// nothing else: no request had ever been made, so the method switch, the body
// encoding, the header handling and the response parsing had all never run.
//
// Every test here talks to a real loopback server. `flutter_test` installs an
// HttpOverrides that answers 400 with an empty body for every request, so a
// suite that leaves it in place passes for the wrong reason — every response
// looks like a failure, and a client that sent nothing at all would look the
// same as one that sent the wrong thing.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/client_actions/executors/http_action_executor.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_test/flutter_test.dart';

/// One request as the server saw it.
class _Seen {
  _Seen(this.method, this.path, this.headers, this.body);

  final String method;
  final String path;
  final Map<String, String> headers;
  final String body;
}

void main() {
  late HttpActionExecutor executor;
  late RenderContext context;
  late HttpServer server;
  late List<_Seen> seen;
  late int status;
  late String responseBody;
  late ContentType responseType;
  HttpOverrides? saved;

  setUp(() async {
    saved = HttpOverrides.current;
    HttpOverrides.global = null;

    executor = HttpActionExecutor();
    final stateManager = StateManager()..initialize(<String, dynamic>{});
    final bindingEngine = BindingEngine();
    final actionHandler = ActionHandler();
    context = RenderContext(
      renderer: Renderer(
        widgetRegistry: WidgetRegistry(),
        bindingEngine: bindingEngine,
        actionHandler: actionHandler,
        stateManager: stateManager,
      ),
      stateManager: stateManager,
      bindingEngine: bindingEngine,
      actionHandler: actionHandler,
      themeManager: ThemeManager.instance,
    );

    seen = [];
    status = 200;
    responseBody = jsonEncode({'ok': true, 'rows': 3});
    responseType = ContentType.json;

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final body = await utf8.decodeStream(request);
      final headers = <String, String>{};
      request.headers.forEach((name, values) => headers[name] = values.join(','));
      seen.add(_Seen(request.method, request.uri.path, headers, body));

      request.response.statusCode = status;
      request.response.headers.contentType = responseType;
      request.response.write(responseBody);
      await request.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    HttpOverrides.global = saved;
  });

  String url([String path = '/api']) =>
      'http://127.0.0.1:${server.port}$path';

  group('what cannot be requested', () {
    test('a missing url is refused, not guessed at', () async {
      final result = await executor.request({}, context);

      expect(result.success, isFalse);
      expect(result.error, contains('URL'));
    });

    test('an unsupported method is named in the refusal', () async {
      final result = await executor
          .request({'url': url(), 'method': 'TRACE'}, context);

      expect(result.success, isFalse);
      expect(result.error, contains('TRACE'),
          reason: 'a document written against a method this runtime does not '
              'send has to be told which one');
      expect(seen, isEmpty);
    });

    test('an unreachable host is reported rather than thrown', () async {
      final result = await executor
          .request({'url': 'http://127.0.0.1:1/nothing'}, context);

      expect(result.success, isFalse);
      expect(result.error, contains('HTTP request failed'));
    });

    test('a malformed url is reported', () async {
      final result = await executor.request({'url': ':::not a url'}, context);
      expect(result.success, isFalse);
    });
  });

  group('the methods', () {
    test('GET is the default, and carries no body', () async {
      final result = await executor.request({'url': url('/rows')}, context);

      expect(result.success, isTrue);
      expect(seen.single.method, 'GET');
      expect(seen.single.path, '/rows');
      expect(seen.single.body, isEmpty);
      expect((result.data! as Map)['method'], 'GET');
    });

    test('a lowercase method is accepted', () async {
      await executor.request({'url': url(), 'method': 'post'}, context);
      expect(seen.single.method, 'POST',
          reason: 'a document writing "post" must not fall through to the '
              'unsupported-method arm');
    });

    for (final method in const ['POST', 'PUT', 'PATCH']) {
      test('$method sends its body', () async {
        await executor.request({
          'url': url(),
          'method': method,
          'body': {'name': 'Ada'},
        }, context);

        expect(seen.single.method, method);
        expect(jsonDecode(seen.single.body), {'name': 'Ada'});
      });
    }

    test('DELETE is sent', () async {
      await executor.request({'url': url(), 'method': 'DELETE'}, context);
      expect(seen.single.method, 'DELETE');
    });
  });

  group('the request body', () {
    Future<void> post(dynamic body, {Map<String, dynamic>? headers}) =>
        executor.request({
          'url': url(),
          'method': 'POST',
          'body': body,
          if (headers != null) 'headers': headers,
        }, context);

    test('a map is encoded as JSON', () async {
      await post({'name': 'Ada'});
      expect(jsonDecode(seen.single.body), {'name': 'Ada'});
    });

    test('a list is encoded as JSON', () async {
      await post([1, 2, 3]);
      expect(jsonDecode(seen.single.body), [1, 2, 3]);
    });

    test('a string is sent as-is under a JSON content type', () async {
      await post('{"already":"encoded"}',
          headers: {'Content-Type': 'application/json'});

      expect(seen.single.body, '{"already":"encoded"}',
          reason: 'encoding an already-encoded string sends the server a JSON '
              'string containing JSON');
    });

    test('a map under an explicit JSON content type is still encoded',
        () async {
      await post({'name': 'Ada'},
          headers: {'Content-Type': 'application/json'});

      expect(jsonDecode(seen.single.body), {'name': 'Ada'},
          reason: 'declaring the content type must not change what happens to '
              'a map — sending its `toString()` is what an unencoded body '
              'looks like on the wire');
    });

    test('a scalar is sent as text', () async {
      await post(42);
      expect(seen.single.body, '42');
    });

    test('no body means no body', () async {
      await post(null);
      expect(seen.single.body, isEmpty);
    });

    test('the lowercase content-type spelling is honoured too', () async {
      await post('{"a":1}', headers: {'content-type': 'application/json'});
      expect(seen.single.body, '{"a":1}');
    });
  });

  group('headers', () {
    test('declared headers reach the server', () async {
      await executor.request({
        'url': url(),
        'headers': {'X-Tenant': 'acme', 'Authorization': 'Bearer t0ken'},
      }, context);

      expect(seen.single.headers['x-tenant'], 'acme');
      expect(seen.single.headers['authorization'], 'Bearer t0ken',
          reason: 'a dropped Authorization header turns every call into an '
              'anonymous one, which the server answers with a 401 nobody can '
              'explain');
    });

    test('non-string header values are stringified rather than refused',
        () async {
      await executor.request({
        'url': url(),
        'headers': {'X-Attempt': 2},
      }, context);

      expect(seen.single.headers['x-attempt'], '2');
    });

    test('a headers value that is not a map is ignored', () async {
      final result = await executor
          .request({'url': url(), 'headers': 'X-Tenant: acme'}, context);

      expect(result.success, isTrue);
    });
  });

  group('the response', () {
    test('a JSON body is decoded', () async {
      final result = await executor.request({'url': url()}, context);

      final data = result.data! as Map<String, dynamic>;
      expect(data['status'], 200);
      expect(data['data'], {'ok': true, 'rows': 3},
          reason: 'handing the document a JSON string it has to decode itself '
              'is the one thing this executor exists to do');
      expect(data['url'], url());
      expect((data['headers']! as Map)['content-type'], contains('json'));
    });

    test('a non-JSON body is handed over as text', () async {
      responseType = ContentType.text;
      responseBody = 'plain text answer';

      final result = await executor.request({'url': url()}, context);
      expect((result.data! as Map)['data'], 'plain text answer');
    });

    test('a JSON content type with an undecodable body degrades to text',
        () async {
      responseBody = 'not json at all';

      final result = await executor.request({'url': url()}, context);

      expect((result.data! as Map)['data'], 'not json at all',
          reason: 'a proxy error page served as application/json is ordinary; '
              'throwing on it loses the only evidence of what happened');
    });

    test('an error status is still a completed request, with the status on it',
        () async {
      status = 503;
      responseBody = jsonEncode({'message': 'maintenance'});

      final result = await executor.request({'url': url()}, context);

      expect(result.success, isTrue,
          reason: 'the request itself succeeded — the document decides what a '
              '503 means for it, and cannot if the status never arrives');
      final data = result.data! as Map<String, dynamic>;
      expect(data['status'], 503);
      expect(data['data'], {'message': 'maintenance'});
      expect(data['statusText'], isNotNull);
    });
  });

  group('timeout', () {
    test('a request that overruns is reported', () async {
      // A server that accepts the connection and never answers.
      final silent = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => silent.close(force: true));
      silent.listen((request) {/* never responds */});

      final result = await executor.request({
        'url': 'http://127.0.0.1:${silent.port}/slow',
        'timeout': 50,
      }, context);

      expect(result.success, isFalse);
      expect(result.error, contains('HTTP request failed'),
          reason: 'without a timeout the document waits forever and shows the '
              'user nothing');
    });
  });
}
