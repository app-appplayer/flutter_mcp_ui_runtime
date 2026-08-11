// `RemoteValidator` — a field checked against a server, and `CustomValidator`
// — one checked against an expression.
//
// The remote one is the interesting half: whatever the server answers, the
// user has to end up with a message they can act on. A malformed response or
// a 500 that reads as "valid" lets a form submit data the server has already
// said it will refuse.
//
// Every test talks to a real loopback server. `flutter_test` installs an
// HttpOverrides that answers 400 with an empty body, so a suite that leaves
// it in place would pass for the wrong reason.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/validation/custom_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late HttpServer server;
  late RenderContext context;
  late int status;
  late String responseBody;
  late ContentType responseType;
  late List<String> bodies;
  HttpOverrides? saved;

  String endpointFor(HttpServer s) =>
      'http://${s.address.address}:${s.port}/validate';

  setUp(() async {
    saved = HttpOverrides.current;
    HttpOverrides.global = null;

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

    bodies = <String>[];
    status = 200;
    responseBody = jsonEncode(<String, dynamic>{'valid': true});
    responseType = ContentType.json;

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      bodies.add(await utf8.decodeStream(request));
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

  group('what the server answered', () {
    test('a valid answer passes', () async {
      final result =
          await RemoteValidator(endpoint: endpointFor(server)).validateAsync('a', context);

      expect(result.isValid, isTrue);
    });

    test('the declared field name is what is sent', () async {
      await RemoteValidator(
              endpoint: endpointFor(server), fieldName: 'email')
          .validateAsync('ada@example.com', context);

      expect(jsonDecode(bodies.single), <String, dynamic>{
        'email': 'ada@example.com',
      }, reason: 'a server expecting `email` and given `value` sees an empty '
          'field and answers about the wrong thing');
    });

    test('with no field name it sends `value`', () async {
      await RemoteValidator(endpoint: endpointFor(server)).validateAsync('x', context);

      expect(jsonDecode(bodies.single), <String, dynamic>{'value': 'x'});
    });

    test('an invalid answer carries the server\'s own message', () async {
      responseBody = jsonEncode(<String, dynamic>{
        'valid': false,
        'error': 'That address is already registered',
        'metadata': <String, dynamic>{'field': 'email'},
      });

      final result =
          await RemoteValidator(endpoint: endpointFor(server)).validateAsync('a', context);

      expect(result.isValid, isFalse);
      expect(result.message, 'That address is already registered',
          reason: 'the server said why; replacing it with a generic refusal '
              'throws away the only thing the user could act on');
      expect(result.details, <String, dynamic>{'field': 'email'});
    });

    test('the `isValid` spelling is read as well as `valid`', () async {
      responseBody = jsonEncode(<String, dynamic>{'isValid': false});

      final result = await RemoteValidator(
        endpoint: endpointFor(server),
        message: 'Not allowed',
      ).validateAsync('a', context);

      expect(result.isValid, isFalse);
      expect(result.message, 'Not allowed');
    });

    test('a 200 that is not an object is treated as a pass', () async {
      responseBody = jsonEncode(<dynamic>[1, 2]);

      final result =
          await RemoteValidator(endpoint: endpointFor(server)).validateAsync('a', context);

      expect(result.isValid, isTrue);
    });

    test('a 200 whose body will not parse is a refusal, not a pass',
        () async {
      responseBody = 'not json at all';
      responseType = ContentType.text;

      final result = await RemoteValidator(
        endpoint: endpointFor(server),
        message: 'Could not check that',
      ).validateAsync('a', context);

      expect(result.isValid, isFalse,
          reason: 'a body the runtime cannot read is not an answer; passing '
              'on it lets the form submit what the server may refuse');
      expect(result.message, 'Could not check that');
    });
  });

  group('what the server refused', () {
    test('a 400 carries the message it sent', () async {
      status = 400;
      responseBody = jsonEncode(<String, dynamic>{'message': 'Too short'});

      final result =
          await RemoteValidator(endpoint: endpointFor(server)).validateAsync('a', context);

      expect(result.isValid, isFalse);
      expect(result.message, 'Too short');
    });

    test('a 422 is read the same way', () async {
      status = 422;
      responseBody = jsonEncode(<String, dynamic>{'error': 'Wrong format'});

      final result =
          await RemoteValidator(endpoint: endpointFor(server)).validateAsync('a', context);

      expect(result.message, 'Wrong format');
    });

    test('a 400 with an unreadable body still refuses, by status', () async {
      status = 400;
      responseBody = '<html>bad request</html>';
      responseType = ContentType.html;

      final result =
          await RemoteValidator(endpoint: endpointFor(server)).validateAsync('a', context);

      expect(result.isValid, isFalse);
      expect(result.message, isNotNull);
    });

    test('a server error is a refusal that names the status', () async {
      status = 500;
      responseBody = '';
      responseType = ContentType.text;

      final result =
          await RemoteValidator(endpoint: endpointFor(server)).validateAsync('a', context);

      expect(result.isValid, isFalse);
      expect(result.message, contains('500'),
          reason: 'the status is what tells an author their endpoint is '
              'broken rather than their input');
    });
  });

    test('a 400 whose body names nothing falls back to the status text',
        () async {
      status = 400;
      responseBody = jsonEncode(<String, dynamic>{});

      final result =
          await RemoteValidator(endpoint: endpointFor(server)).validateAsync('a', context);

      expect(result.isValid, isFalse);
      expect(result.message, isNotNull,
          reason: 'a refusal with no reason at all leaves the user re-typing '
              'the same value; the status line is the last thing left to say');
  });

  group('an endpoint that is not a URL', () {
    test('is a refusal rather than a thrown parse error', () async {
      final result = await RemoteValidator(
        endpoint: ':::not a url:::',
        message: 'Could not check that',
      ).validateAsync('a', context);

      expect(result.isValid, isFalse,
          reason: 'a typo in the endpoint is an authoring mistake; letting it '
              'throw out of the validator takes the form down with it');
      expect(result.message, 'Could not check that');
    });
  });

  group('a server that is not there', () {
    test('is a refusal rather than a thrown request', () async {
      final port = server.port;
      await server.close(force: true);

      final result = await RemoteValidator(
        endpoint: 'http://127.0.0.1:$port/validate',
        message: 'Could not reach the server',
      ).validateAsync('a', context);

      expect(result.isValid, isFalse);
      expect(result.message, 'Could not reach the server');

      // Re-bind so the tear-down has something to close.
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    });
  });

  group('CustomValidator', () {
    test('an expression that answers true passes', () {
      final validator = CustomValidator(
        expression: "{{value == 'ok'}}",
        bindingEngine: context.bindingEngine,
      );

      expect(validator.validate('ok', context).isValid, isTrue);
      expect(validator.validate('nope', context).isValid, isFalse);
    });

    test('an expression that answers a string uses it as the message', () {
      final validator = CustomValidator(
        expression: "{{value == 'ok' ? true : 'Too short'}}",
        bindingEngine: context.bindingEngine,
      );

      expect(validator.validate('nope', context).message, 'Too short',
          reason: 'letting the expression name the reason is what makes a '
              'per-field rule readable in the document');
    });

    test('a validator with no context refuses rather than throwing', () {
      final validator = CustomValidator(
        expression: '{{value}}',
        bindingEngine: context.bindingEngine,
        message: 'Could not check that',
      );

      final result = validator.validate('a', null);

      expect(result.isValid, isFalse,
          reason: 'a rule that cannot be evaluated has not passed; treating '
              'the failure as a pass is the one answer that is never safe');
    });

    test('it round-trips through JSON', () {
      final validator = CustomValidator(
        expression: '{{value}}',
        bindingEngine: context.bindingEngine,
        message: 'Nope',
      );

      expect(validator.toJson()['expression'], '{{value}}');
    });
  });
}
