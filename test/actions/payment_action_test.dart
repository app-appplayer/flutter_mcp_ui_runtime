/// `payment` — spec §4.24, §7.3.5, §18.11 (Payment Profile).
///
/// The paths worth pinning are the ones where being wrong costs money. A
/// runtime that turns a cancel into `onSuccess`, or that answers silence when
/// it has no payment port, hands the document a claim it cannot support: the
/// document's `onSuccess` is what opens a door. So every non-success outcome
/// is asserted to reach `onError` with a code that names it, and the success
/// path is asserted to carry nothing more than `status`.
library payment_action_test;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart' show MCPUIRuntime;
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/capabilities/runtime_capabilities.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/models/ui_definition.dart'
    show PermissionsConfig;
import 'package:flutter_mcp_ui_runtime/src/permissions/trust_level.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/runtime_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';

void main() {
  late ActionHandler actions;
  late RenderContext context;
  late StateManager state;
  late List<List<String>> calls;
  late List<num?> amounts;
  late _RecordingPaymentPort port;
  late RuntimeEngine engine;

  setUp(() async {
    final registry = WidgetRegistry();
    state = StateManager();
    state.initialize({
      'seller': 'euid_from_state',
      'item': 'wash-premium',
      'msg': '',
      'started': false,
    });
    final binding = BindingEngine();
    final theme = ThemeManager();
    actions = ActionHandler();
    engine = RuntimeEngine(enableDebugMode: false);
    await engine.initialize(definition: {
      'type': 'page',
      'content': {'type': 'box'},
    });
    context = RenderContext(
      renderer: Renderer(
        widgetRegistry: registry,
        bindingEngine: binding,
        actionHandler: actions,
        stateManager: state,
      ),
      stateManager: state,
      bindingEngine: binding,
      actionHandler: actions,
      themeManager: theme,
      engine: engine,
    );
    calls = [];
    amounts = [];
  });

  tearDown(() => engine.destroy());

  void wirePort(PaymentPort p) {
    engine.capabilities = RuntimeCapabilities(payment: p);
  }

  void portReturning(PaymentOutcome outcome) {
    port = _RecordingPaymentPort(outcome, calls, amounts);
    wirePort(port);
  }

  Map<String, dynamic> payment({
    Object? seller = 'euid_shop',
    Object? itemId = 'wash-premium',
    Object? amount,
    Map<String, dynamic>? onSuccess,
    Map<String, dynamic>? onError,
  }) =>
      {
        'type': 'payment',
        if (seller != null) 'seller': seller,
        if (itemId != null) 'itemId': itemId,
        if (amount != null) 'amount': amount,
        if (onSuccess != null) 'onSuccess': onSuccess,
        if (onError != null) 'onError': onError,
      };

  group('§4.24.1 — the host owns everything but the two declared fields', () {
    test('the port receives seller and itemId, resolved from bindings', () async {
      portReturning(PaymentOutcome.success);

      await actions.execute(
        payment(seller: '{{seller}}', itemId: '{{item}}'),
        context,
      );

      expect(calls, [
        ['euid_from_state', 'wash-premium']
      ]);
    });

    test('success carries status and nothing else', () async {
      portReturning(PaymentOutcome.success);

      final result = await actions.execute(payment(), context);

      expect(result.success, isTrue);
      expect(result.data, {'status': 'success'});
    });

    test('onSuccess sees {{event.status}}', () async {
      portReturning(PaymentOutcome.success);

      await actions.execute(
        payment(onSuccess: {
          'type': 'state',
          'action': 'set',
          'binding': 'msg',
          'value': '{{event.status}}',
        }),
        context,
      );

      expect(state.get('msg'), 'success');
    });
  });

  group('§4.24.1 — no outcome but success reaches onSuccess', () {
    test('cancel is PAYMENT_CANCELLED on onError, never onSuccess', () async {
      portReturning(PaymentOutcome.cancel);

      final result = await actions.execute(
        payment(
          onSuccess: {
            'type': 'state',
            'action': 'set',
            'binding': 'started',
            'value': true,
          },
          onError: {
            'type': 'state',
            'action': 'set',
            'binding': 'msg',
            'value': '{{event.code}}',
          },
        ),
        context,
      );

      expect(result.success, isFalse);
      expect(result.errorCode, 'PAYMENT_CANCELLED');
      expect(state.get('msg'), 'PAYMENT_CANCELLED');
      expect(state.get('started'), isFalse,
          reason: 'a cancelled payment must not run onSuccess');
    });

    test('an outcome this version does not know is PAYMENT_UNKNOWN', () async {
      portReturning(PaymentOutcome.unknown);

      final result = await actions.execute(payment(), context);

      expect(result.success, isFalse);
      expect(result.errorCode, 'PAYMENT_UNKNOWN');
    });

    test('a port that throws is PAYMENT_UNKNOWN, not a failure claim', () async {
      wirePort(_ThrowingPaymentPort());

      final result = await actions.execute(payment(), context);

      expect(result.success, isFalse);
      expect(result.errorCode, 'PAYMENT_UNKNOWN',
          reason: 'the host may have opened the surface before failing');
    });

    test('a host that could not open reports PAYMENT_UNAVAILABLE', () async {
      portReturning(PaymentOutcome.unavailable);

      final result = await actions.execute(payment(), context);

      expect(result.success, isFalse);
      expect(result.errorCode, 'PAYMENT_UNAVAILABLE');
    });
  });

  group('§18.11.3 — a runtime with no payment port refuses visibly', () {
    test('no port is PAYMENT_UNAVAILABLE through onError, not a no-op', () async {
      final result = await actions.execute(
        payment(onError: {
          'type': 'state',
          'action': 'set',
          'binding': 'msg',
          'value': '{{event.code}}',
        }),
        context,
      );

      expect(result.success, isFalse);
      expect(result.errorCode, 'PAYMENT_UNAVAILABLE');
      expect(state.get('msg'), 'PAYMENT_UNAVAILABLE',
          reason: 'the document has to be able to tell it was refused');
    });

    test('the refusal is not the generic unknown-action-type error', () async {
      final result = await actions.execute(payment(), context);

      expect(result.error, isNot(contains('Unknown action type')));
    });
  });

  group('§7.3.5 — the document does not get to name a seller untrusted', () {
    test('untrusted refuses before the port is called', () async {
      portReturning(PaymentOutcome.success);
      actions.setPermissionsConfig(PermissionsConfig());
      actions.permissionManager!.trustLevel = TrustLevel.untrusted;

      final result = await actions.execute(payment(), context);

      expect(result.success, isFalse);
      expect(result.errorCode, 'PAYMENT_UNAVAILABLE');
      expect(calls, isEmpty, reason: 'refused before reaching the host');
    });

    test('basic trust dispatches', () async {
      portReturning(PaymentOutcome.success);
      actions.setPermissionsConfig(PermissionsConfig());
      actions.permissionManager!.trustLevel = TrustLevel.basic;

      final result = await actions.execute(payment(), context);

      expect(result.success, isTrue);
      expect(calls, hasLength(1));
    });

    test('a document with no permissions block still dispatches', () async {
      portReturning(PaymentOutcome.success);

      final result = await actions.execute(payment(), context);

      expect(result.success, isTrue,
          reason: 'unknown trust is not untrusted; defaulting it would '
              'refuse every ordinary document');
    });
  });

  group('§4.24.2 — who is being paid', () {
    test('a document that names a seller has it passed through', () async {
      portReturning(PaymentOutcome.success);

      await actions.execute(payment(seller: 'euid_named'), context);

      expect(calls.single.first, 'euid_named');
    });

    test('a document with no seller reaches the host with none', () async {
      // The device case: who is paid follows from which device served the
      // document, and the host establishes that by verifying it.
      portReturning(PaymentOutcome.success);

      final result = await actions.execute(payment(seller: null), context);

      expect(result.success, isTrue);
      expect(calls.single.first, '<unnamed>',
          reason: 'the runtime must not invent a party');
    });

    test('a seller binding that resolves to nothing is the same as absent',
        () async {
      portReturning(PaymentOutcome.success);

      await actions.execute(payment(seller: '{{missing}}'), context);

      expect(calls.single.first, '<unnamed>',
          reason: 'an empty string would be a party named ""');
    });
  });

  group('§4.24.3 — amounts', () {
    test('an amount is carried to the host untouched', () async {
      portReturning(PaymentOutcome.success);

      await actions.execute(payment(amount: 12000), context);

      expect(amounts, [12000]);
    });

    test('no amount is carried when the document sends none', () async {
      portReturning(PaymentOutcome.success);

      await actions.execute(payment(), context);

      expect(amounts, [null]);
    });

    test('an amount resolves from a binding', () async {
      state.set('tip', 3500);
      portReturning(PaymentOutcome.success);

      await actions.execute(payment(amount: '{{tip}}'), context);

      expect(amounts, [3500]);
    });

    test('zero and negative are refused before the host is reached', () async {
      portReturning(PaymentOutcome.success);

      for (final bad in [0, -1]) {
        final result = await actions.execute(payment(amount: bad), context);
        expect(result.success, isFalse, reason: '$bad is not a price');
      }
      expect(calls, isEmpty);
    });

    test('a non-numeric amount is refused, not sent as text', () async {
      portReturning(PaymentOutcome.success);

      final result = await actions.execute(payment(amount: 'free'), context);

      expect(result.success, isFalse);
      expect(calls, isEmpty);
    });
  });

  group('required fields', () {
    test('a missing itemId is an error and does not reach the host', () async {
      portReturning(PaymentOutcome.success);

      final result = await actions.execute(payment(itemId: null), context);

      expect(result.success, isFalse);
      expect(calls, isEmpty);
    });

    test('an unknown sub-action is refused', () async {
      portReturning(PaymentOutcome.success);

      final result = await actions.execute(
        {...payment(), 'action': 'refund'},
        context,
      );

      expect(result.success, isFalse);
      expect(calls, isEmpty);
    });
  });

  group('§18.11 — a runtime declares what it can do', () {
    test('a wired port declares the capability', () {
      expect(
        const RuntimeCapabilities().declared,
        isNot(contains(RuntimeCapability.payment)),
      );
      expect(
        RuntimeCapabilities(payment: _RecordingPaymentPort(
                PaymentOutcome.success, [], []))
            .declared,
        contains(RuntimeCapability.payment),
      );
    });
  });

  group('load gate — a bundle carrying payment has to open', () {
    // The action-type enum lives in the generated widget schema, which runs
    // over every definition at load (`validateSchema: true`). A `payment`
    // absent from that enum would not be a missing feature: the whole
    // document would be rejected before it rendered.
    test('a page whose button carries payment passes schema validation',
        () async {
      final runtime = MCPUIRuntime();
      addTearDown(runtime.destroy);

      await runtime.initialize(
        {
          'type': 'page',
          'content': {
            'type': 'button',
            'label': 'Pay',
            'onTap': {
              'type': 'payment',
              'seller': 'euid_shop',
              'itemId': 'wash-premium',
            },
          },
        },
        validateSchema: true,
      );

      expect(runtime.isInitialized, isTrue);
    });
  });
}

class _RecordingPaymentPort implements PaymentPort {
  _RecordingPaymentPort(this.outcome, this.calls, this.amounts);

  final PaymentOutcome outcome;
  final List<List<String>> calls;
  final List<num?> amounts;

  @override
  Future<PaymentOutcome> checkout(PaymentRequest request) async {
    calls.add([request.seller ?? '<unnamed>', request.itemId]);
    amounts.add(request.amount);
    return outcome;
  }
}

class _ThrowingPaymentPort implements PaymentPort {
  @override
  Future<PaymentOutcome> checkout(PaymentRequest request) async {
    throw StateError('deep link handler died');
  }
}
