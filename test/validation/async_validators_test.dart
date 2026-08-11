// Custom, async, remote and composite validators.
//
// 57% covered, and what was missing is the half that decides whether a form
// can be submitted: the debounce that keeps a remote check from firing per
// keystroke, the server responses a validator has to read, and the state
// object a form asks "is this valid yet". A validator that answers `valid` for
// a request that failed is worse than one that throws — the user is let
// through and the server refuses at the end.
//
// The remote validator is driven against a REAL loopback HTTP server. A mocked
// client would test the mock; the branches here are about status codes and
// response shapes, which is exactly what a mock would have to invent.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/validation/custom_validator.dart';
import 'package:flutter_mcp_ui_runtime/src/validation/validation_engine.dart'
    show ValidationResult;
import 'package:flutter_test/flutter_test.dart';

/// A validator that answers what the test tells it to, without a network.
class _ScriptedValidator extends AsyncValidator {
  _ScriptedValidator(this.answer, {super.debounceMilliseconds = 0});

  final ValidationResult Function(dynamic value) answer;
  final calls = <dynamic>[];

  @override
  Future<ValidationResult> validateAsync(
      dynamic value, RenderContext? context) async {
    calls.add(value);
    return answer(value);
  }

  @override
  Map<String, dynamic> toJson() => {'type': 'scripted'};
}

class _ThrowingValidator extends AsyncValidator {
  _ThrowingValidator() : super(debounceMilliseconds: 0);

  @override
  Future<ValidationResult> validateAsync(
          dynamic value, RenderContext? context) async =>
      throw StateError('validator exploded');

  @override
  Map<String, dynamic> toJson() => {'type': 'throwing'};
}

void main() {
  late RenderContext context;
  late BindingEngine bindingEngine;

  setUp(() {
    final stateManager = StateManager()
      ..initialize(<String, dynamic>{'minimum': 3});
    bindingEngine = BindingEngine();
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
  });

  group('CustomValidator', () {
    CustomValidator validator(String expression, {String? message}) =>
        CustomValidator(
          expression: expression,
          bindingEngine: bindingEngine,
          message: message,
        );

    test('an expression that answers true is valid', () {
      final result = validator('{{value > 2}}').validate(5, context);
      expect(result.isValid, isTrue);
      expect(result.message, isNull);
    });

    test('an expression that answers false uses the declared message', () {
      final result = validator('{{value > 2}}', message: 'Too small')
          .validate(1, context);
      expect(result.isValid, isFalse);
      expect(result.message, 'Too small');
    });

    test('an expression may return the message itself', () {
      // A string result IS the error — that is how a document writes a
      // conditional message without two validators.
      final result = validator(
              '{{value > 2 ? true : "must be more than two"}}')
          .validate(1, context);
      expect(result.isValid, isFalse);
      expect(result.message, 'must be more than two');
    });

    test('the expression can read the surrounding state, not just the value',
        () {
      expect(validator('{{value >= minimum}}').validate(3, context).isValid,
          isTrue);
      expect(validator('{{value >= minimum}}').validate(2, context).isValid,
          isFalse,
          reason: 'a rule whose threshold lives in state is the reason this '
              'takes a render context at all');
    });

    test('with no context it refuses rather than passing the value through',
        () {
      final result = validator('{{value > 2}}').validate(5, null);
      expect(result.isValid, isFalse,
          reason: 'a validator that cannot evaluate must not answer "valid" — '
              'that is a form submitted unchecked');
    });

    test('an expression that cannot be evaluated is reported, not thrown', () {
      final result = validator('{{ ((( }}').validate(1, context);
      expect(result.isValid, isFalse);
      expect(result.message, isNotNull);
    });

    test('it serialises back to its declaration', () {
      expect(validator('{{value > 2}}', message: 'Too small').toJson(), {
        'type': 'custom',
        'expression': '{{value > 2}}',
        'message': 'Too small',
      });
      expect(validator('{{value > 2}}').toJson().containsKey('message'),
          isFalse);
    });
  });

  group('AsyncValidator', () {
    test('the synchronous answer is pending, never valid', () {
      final validator = _ScriptedValidator((_) => ValidationResult.valid);
      addTearDown(validator.dispose);

      final result = validator.validate('anything', context);
      expect(result.isPending, isTrue);
      expect(result.isValid, isFalse,
          reason: 'a form that reads the sync answer must not be told a '
              'value passed before the server has seen it');
    });

    test('validateWithDebounce reports pending first, then the answer',
        () async {
      final validator = _ScriptedValidator(
          (value) => ValidationResult.invalid('taken'),
          debounceMilliseconds: 30);
      addTearDown(validator.dispose);

      final seen = <ValidationResult>[];
      validator.validateWithDebounce('ada', context, seen.add);

      expect(seen.single.isPending, isTrue,
          reason: 'the spinner has to appear on the keystroke, not after the '
              'round trip');

      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(seen.last.isValid, isFalse);
      expect(seen.last.message, 'taken');
    });

    test('only the last of a burst is actually validated', () async {
      final validator = _ScriptedValidator(
          (_) => ValidationResult.valid,
          debounceMilliseconds: 40);
      addTearDown(validator.dispose);

      validator.validateWithDebounce('a', context, (_) {});
      validator.validateWithDebounce('ab', context, (_) {});
      validator.validateWithDebounce('abc', context, (_) {});
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(validator.calls, ['abc'],
          reason: 'a remote check per keystroke is a request per keystroke, '
              'which is what the debounce exists to prevent');
    });

    test('cancel drops a pending validation', () async {
      final validator = _ScriptedValidator(
          (_) => ValidationResult.valid,
          debounceMilliseconds: 40);
      addTearDown(validator.dispose);

      validator.validateWithDebounce('ada', context, (_) {});
      validator.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(validator.calls, isEmpty,
          reason: 'a field the user left must not keep asking the server '
              'about a value nobody is looking at');
    });

    test('a validator that throws answers invalid rather than escaping',
        () async {
      final validator = _ThrowingValidator();
      addTearDown(validator.dispose);

      final seen = <ValidationResult>[];
      validator.validateWithDebounce('x', context, seen.add);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(seen.last.isValid, isFalse);
      expect(seen.last.message, contains('exploded'),
          reason: 'the exception belongs in the field error, not in the zone');
    });
  });

  group('CompositeAsyncValidator', () {
    test('all validators must pass', () async {
      final composite = CompositeAsyncValidator(validators: [
        _ScriptedValidator((_) => ValidationResult.valid),
        _ScriptedValidator((_) => ValidationResult.valid),
      ]);
      addTearDown(composite.dispose);

      expect((await composite.validateAsync('x', context)).isValid, isTrue);
    });

    test('stopOnFirstError reports the first failure and asks no further',
        () async {
      final second = _ScriptedValidator((_) => ValidationResult.invalid('two'));
      final composite = CompositeAsyncValidator(validators: [
        _ScriptedValidator((_) => ValidationResult.invalid('one')),
        second,
      ]);
      addTearDown(composite.dispose);

      final result = await composite.validateAsync('x', context);
      expect(result.message, 'one');
      expect(second.calls, isEmpty,
          reason: 'the point of stopping is not asking the next server');
    });

    test('without stopOnFirstError every message is collected', () async {
      final composite = CompositeAsyncValidator(
        stopOnFirstError: false,
        validators: [
          _ScriptedValidator((_) => ValidationResult.invalid('one')),
          _ScriptedValidator((_) => ValidationResult.invalid('two')),
        ],
      );
      addTearDown(composite.dispose);

      final result = await composite.validateAsync('x', context);
      expect(result.message, 'one, two',
          reason: 'a user fixing one rule at a time is a user submitting the '
              'form five times');
    });

    test('it serialises its children, and disposes them', () {
      final child = _ScriptedValidator((_) => ValidationResult.valid);
      final composite = CompositeAsyncValidator(validators: [child]);

      final json = composite.toJson();
      expect(json['type'], 'composite_async');
      expect((json['validators'] as List).single, {'type': 'scripted'});
      expect(json['stopOnFirstError'], isTrue);

      composite.dispose(); // must not throw: the children go with it
    });
  });

  group('RemoteValidator', () {
    late HttpServer server;
    late List<Map<String, dynamic>> received;
    late int status;
    late String body;

    HttpOverrides? savedOverrides;

    setUp(() async {
      // `flutter_test` installs an HttpOverrides that answers 400 with an
      // empty body for every request, so a real endpoint is unreachable until
      // it is lifted. Without this the whole group passes for the wrong
      // reason: every response looks like a validation failure.
      savedOverrides = HttpOverrides.current;
      HttpOverrides.global = null;
      received = [];
      status = 200;
      body = jsonEncode({'valid': true});
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        received.add(jsonDecode(await utf8.decodeStream(request))
            as Map<String, dynamic>);
        request.response.statusCode = status;
        request.response.headers.contentType = ContentType.json;
        request.response.write(body);
        await request.response.close();
      });
    });

    tearDown(() async {
      await server.close(force: true);
      HttpOverrides.global = savedOverrides;
    });

    String endpoint() => 'http://127.0.0.1:${server.port}/check';

    test('a 200 with valid:true passes, and the value is sent as `value`',
        () async {
      final validator = RemoteValidator(endpoint: endpoint());
      addTearDown(validator.dispose);

      final result = await validator.validateAsync('ada', context);

      expect(result.isValid, isTrue);
      expect(received.single, {'value': 'ada'});
    });

    test('a declared fieldName is the key the server is given', () async {
      final validator =
          RemoteValidator(endpoint: endpoint(), fieldName: 'username');
      addTearDown(validator.dispose);

      await validator.validateAsync('ada', context);
      expect(received.single, {'username': 'ada'},
          reason: 'a server expecting `username` and handed `value` validates '
              'nothing and answers 200');
    });

    test('a 200 with valid:false carries the server message through',
        () async {
      body = jsonEncode({'valid': false, 'error': 'already taken'});
      final validator = RemoteValidator(endpoint: endpoint());
      addTearDown(validator.dispose);

      final result = await validator.validateAsync('ada', context);
      expect(result.isValid, isFalse);
      expect(result.message, 'already taken');
    });

    test('a 422 is a validation failure with its own message', () async {
      status = 422;
      body = jsonEncode({'message': 'too short'});
      final validator = RemoteValidator(endpoint: endpoint());
      addTearDown(validator.dispose);

      final result = await validator.validateAsync('a', context);
      expect(result.isValid, isFalse);
      expect(result.message, 'too short');
    });

    test('a 500 is reported as a server error, not as an invalid value',
        () async {
      status = 500;
      body = 'boom';
      final validator = RemoteValidator(endpoint: endpoint());
      addTearDown(validator.dispose);

      final result = await validator.validateAsync('ada', context);
      expect(result.isValid, isFalse);
      expect(result.message, contains('500'),
          reason: 'the user needs to know the check could not be made — '
              '"already taken" would be a lie');
    });

    test('a body that is not json falls back to the declared message',
        () async {
      status = 422;
      body = '<html>nope</html>';
      final validator =
          RemoteValidator(endpoint: endpoint(), message: 'Could not verify');
      addTearDown(validator.dispose);

      final result = await validator.validateAsync('ada', context);
      expect(result.isValid, isFalse);
      expect(result.message, contains('Could not verify'));
    });

    test('a 200 whose body is not an object is treated as valid', () async {
      body = jsonEncode([1, 2, 3]);
      final validator = RemoteValidator(endpoint: endpoint());
      addTearDown(validator.dispose);

      expect((await validator.validateAsync('ada', context)).isValid, isTrue);
    });

    test('a network failure is reported, not thrown', () async {
      final validator =
          RemoteValidator(endpoint: 'http://127.0.0.1:1/nothing-here');
      addTearDown(validator.dispose);

      final result = await validator.validateAsync('ada', context);
      expect(result.isValid, isFalse);
      expect(result.message, isNotNull);
    });

    test('headers declared by the document are sent', () async {
      late HttpHeaders seen;
      await server.close(force: true);
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        seen = request.headers;
        await utf8.decodeStream(request);
        request.response.write(jsonEncode({'valid': true}));
        await request.response.close();
      });

      final validator = RemoteValidator(
        endpoint: 'http://127.0.0.1:${server.port}/check',
        headers: {'Authorization': 'Bearer token-1'},
      );
      addTearDown(validator.dispose);

      await validator.validateAsync('ada', context);
      expect(seen.value('authorization'), 'Bearer token-1',
          reason: 'a validation endpoint behind auth is the ordinary case');
    });

    test('it serialises back to its declaration', () {
      final validator = RemoteValidator(
        endpoint: 'https://example.com/check',
        fieldName: 'username',
        message: 'nope',
      );
      addTearDown(validator.dispose);

      expect(validator.toJson(), {
        'type': 'remote',
        'endpoint': 'https://example.com/check',
        'fieldName': 'username',
        'message': 'nope',
      });
    });
  });

  group('ValidationState', () {
    test('a field moves from pending to its answer, notifying each time',
        () async {
      final state = ValidationState();
      addTearDown(state.dispose);
      var notifications = 0;
      state.addListener(() => notifications++);

      state.validateField('email', 'nope',
          _ScriptedValidator((_) => ValidationResult.invalid('bad address')),
          context);

      expect(state.isFieldPending('email'), isTrue);
      expect(state.hasPendingValidations, isTrue);
      expect(state.isValid, isTrue,
          reason: 'a form is not invalid while its checks are still running — '
              'that would flash an error under every field being typed into');

      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(state.isFieldValid('email'), isFalse);
      expect(state.getFieldError('email'), 'bad address');
      expect(state.isValid, isFalse);
      expect(notifications, greaterThanOrEqualTo(2));
    });

    test('an unknown field is valid and has no error', () {
      final state = ValidationState();
      addTearDown(state.dispose);

      expect(state.isFieldValid('never-validated'), isTrue,
          reason: 'a field nobody has checked yet must not block submission');
      expect(state.getFieldError('never-validated'), isNull);
      expect(state.getResult('never-validated'), isNull);
      expect(state.isFieldPending('never-validated'), isFalse);
    });

    test('clearing a field forgets its result and cancels its validator',
        () async {
      final validator = _ScriptedValidator(
          (_) => ValidationResult.invalid('bad'),
          debounceMilliseconds: 40);
      final state = ValidationState();
      addTearDown(state.dispose);

      state.validateField('email', 'x', validator, context);
      state.clearField('email');
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(state.getResult('email'), isNull);
      expect(validator.calls, isEmpty,
          reason: 'a cleared field must not have its answer arrive later and '
              'reappear');
    });

    test('clear empties every field', () async {
      final state = ValidationState();
      addTearDown(state.dispose);

      state.validateField('a', '1',
          _ScriptedValidator((_) => ValidationResult.invalid('x')), context);
      state.validateField('b', '2',
          _ScriptedValidator((_) => ValidationResult.invalid('y')), context);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(state.isValid, isFalse);

      state.clear();

      expect(state.getResult('a'), isNull);
      expect(state.getResult('b'), isNull);
      expect(state.isValid, isTrue);
      expect(state.hasPendingValidations, isFalse);
    });
  });

  group('FormValidationMixin', () {
    testWidgets('a widget validates through the mixin and reads the result',
        (tester) async {
      late _FormState formState;

      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          return _Form(onState: (s) => formState = s);
        }),
      ));

      expect(formState.isFormValid, isTrue);

      formState.validateField('email', 'nope',
          _ScriptedValidator((_) => ValidationResult.invalid('bad')));
      expect(formState.hasPendingValidations, isTrue);

      await tester.pump(const Duration(milliseconds: 80));
      expect(formState.isFormValid, isFalse);

      formState.clearFieldValidation('email');
      expect(formState.isFormValid, isTrue);

      formState.validateField('email', 'nope',
          _ScriptedValidator((_) => ValidationResult.invalid('bad')));
      await tester.pump(const Duration(milliseconds: 80));
      formState.clearValidations();
      expect(formState.isFormValid, isTrue);
    });
  });
}

class _Form extends StatefulWidget {
  const _Form({required this.onState});

  final void Function(_FormState) onState;

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> with FormValidationMixin {
  @override
  void initState() {
    super.initState();
    widget.onState(this);
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}
