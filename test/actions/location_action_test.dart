/// `location` — spec §4.25, §7.3.6, §18.12 (Location Profile).
///
/// The paths worth pinning are the ones where being wrong costs the person
/// something they cannot take back. A runtime that hands a document a finer
/// position than it asked for, that answers a stored fix to avoid asking
/// again, or that stays silent when it has no port, has given away something
/// nobody weighed. So the ceiling, the refusal and the absent port are each
/// asserted directly.
library location_action_test;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/capabilities/runtime_capabilities.dart';
import 'package:flutter_mcp_ui_runtime/src/models/ui_definition.dart'
    show PermissionsConfig;
import 'package:flutter_mcp_ui_runtime/src/permissions/trust_level.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/runtime_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';

class _RecordingPort implements LocationPort {
  _RecordingPort(this._answer);

  final Object Function(LocationPrecision asked) _answer;
  final List<LocationPrecision> asked = <LocationPrecision>[];

  @override
  Future<Object> locate(LocationPrecision precision) async {
    asked.add(precision);
    return _answer(precision);
  }
}

class _ThrowingPort implements LocationPort {
  @override
  Future<Object> locate(LocationPrecision precision) async =>
      throw StateError('the platform is gone');
}

LocationFix _fix({
  double latitude = 37.5,
  double longitude = 127.0,
  double accuracyMeters = 12,
  LocationPrecision precision = LocationPrecision.fine,
}) =>
    LocationFix(
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: accuracyMeters,
      precision: precision,
      at: DateTime.utc(2026, 8, 27, 3, 4, 5),
    );

void main() {
  late ActionHandler actions;
  late RenderContext context;
  late StateManager state;
  late RuntimeEngine engine;

  setUp(() async {
    final registry = WidgetRegistry();
    state = StateManager();
    state.initialize({'want': 'fine', 'where': '', 'msg': ''});
    final binding = BindingEngine();
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
      themeManager: ThemeManager(),
      engine: engine,
    );
  });

  tearDown(() => engine.destroy());

  Map<String, dynamic> location({
    Object? precision,
    Map<String, dynamic>? onSuccess,
    Map<String, dynamic>? onError,
  }) =>
      {
        'type': 'location',
        if (precision != null) 'precision': precision,
        if (onSuccess != null) 'onSuccess': onSuccess,
        if (onError != null) 'onError': onError,
      };

  group('§4.25.1 — what comes back', () {
    test('a fix carries the position, what it cost, and when', () async {
      engine.capabilities =
          RuntimeCapabilities(location: _RecordingPort((_) => _fix()));

      final r = await actions.execute(location(precision: 'fine'), context);

      expect(r.data!['latitude'], 37.5);
      expect(r.data!['longitude'], 127.0);
      expect(r.data!['accuracyMeters'], 12);
      expect(r.data!['precision'], 'fine');
      // A position without a time cannot be told from a stale one.
      expect(r.data!['at'], '2026-08-27T03:04:05.000Z');
    });

    test('a refusal is an answer, with its own code', () async {
      engine.capabilities = RuntimeCapabilities(
        location: _RecordingPort((_) => LocationFailure.denied),
      );

      final r = await actions.execute(location(), context);

      expect(r.success, isFalse);
      expect(r.errorCode, 'LOCATION_DENIED');
    });

    test('no fix and no port answer differently from a refusal', () async {
      engine.capabilities = RuntimeCapabilities(
        location: _RecordingPort((_) => LocationFailure.unavailable),
      );
      expect((await actions.execute(location(), context)).errorCode,
          'LOCATION_UNAVAILABLE');
    });

    test('a port that threw claims nothing', () async {
      engine.capabilities = RuntimeCapabilities(location: _ThrowingPort());

      final r = await actions.execute(location(), context);

      expect(r.success, isFalse);
      expect(r.errorCode, 'LOCATION_UNAVAILABLE');
    });
  });

  group('§4.25.2 — precision is a ceiling', () {
    test('coarse is the default, so asking softly asks for less', () async {
      final port = _RecordingPort((_) => _fix(precision: LocationPrecision.coarse));
      engine.capabilities = RuntimeCapabilities(location: port);

      await actions.execute(location(), context);

      expect(port.asked, [LocationPrecision.coarse]);
    });

    test('a spelling nobody recognises reads as coarse, not as fine', () async {
      // The ceiling is a safety property: the safe reading of an unknown value
      // is the narrower one.
      final port = _RecordingPort((_) => _fix(precision: LocationPrecision.coarse));
      engine.capabilities = RuntimeCapabilities(location: port);

      await actions.execute(location(precision: 'exact'), context);

      expect(port.asked, [LocationPrecision.coarse]);
    });

    test('the precision is resolved from bindings', () async {
      final port = _RecordingPort((_) => _fix());
      engine.capabilities = RuntimeCapabilities(location: port);

      await actions.execute(location(precision: '{{want}}'), context);

      expect(port.asked, [LocationPrecision.fine]);
    });

    test('coarser than asked is fine — the document must not assume', () async {
      engine.capabilities = RuntimeCapabilities(
        location: _RecordingPort((_) => _fix(precision: LocationPrecision.coarse)),
      );

      final r = await actions.execute(location(precision: 'fine'), context);

      expect(r.success, isTrue);
      expect(r.data!['precision'], 'coarse');
    });

    test('finer than asked never reaches the document', () async {
      // The last place this can be caught. A document that asked coarse and
      // was handed a street address now holds it, and nobody weighed that.
      engine.capabilities = RuntimeCapabilities(
        location: _RecordingPort((_) => _fix(precision: LocationPrecision.fine)),
      );

      final r = await actions.execute(location(precision: 'coarse'), context);

      expect(r.success, isFalse);
      expect(r.errorCode, 'LOCATION_UNAVAILABLE');
    });
  });

  group('§4.25.3 — asking again is asking again', () {
    test('two dispatches are two questions', () async {
      // A stored answer returned to avoid asking is a stale position wearing
      // the look of a current one.
      final port = _RecordingPort((_) => _fix());
      engine.capabilities = RuntimeCapabilities(location: port);

      await actions.execute(location(precision: 'fine'), context);
      await actions.execute(location(precision: 'fine'), context);

      expect(port.asked, hasLength(2));
    });
  });

  group('§18.12.3 — a runtime that does not claim the Profile', () {
    test('an unwired port is reported, never silent', () async {
      engine.capabilities = const RuntimeCapabilities();

      final r = await actions.execute(location(), context);

      expect(r.success, isFalse);
      expect(r.errorCode, 'LOCATION_UNAVAILABLE');
    });
  });

  group('§7.3.6 — untrusted renders and nothing more', () {
    test('an untrusted document is refused before the port is reached',
        () async {
      final port = _RecordingPort((_) => _fix());
      engine.capabilities = RuntimeCapabilities(location: port);
      actions.setPermissionsConfig(PermissionsConfig());
      actions.permissionManager!.trustLevel = TrustLevel.untrusted;

      final r = await actions.execute(location(), context);

      expect(r.errorCode, 'LOCATION_UNAVAILABLE');
      expect(port.asked, isEmpty, reason: 'the port must not be asked at all');
    });
  });

  group('trust that is simply unknown is not untrusted', () {
    test('a document with no permissions block still asks', () async {
      // Defaulting unknown trust to untrusted would refuse every ordinary
      // document — the same reading `payment` settled on.
      //
      // Answering coarse because that is what an unspecified `precision`
      // asks for: a fine answer here would be refused by the ceiling, which
      // is a different check than the one this test is making.
      final port =
          _RecordingPort((_) => _fix(precision: LocationPrecision.coarse));
      engine.capabilities = RuntimeCapabilities(location: port);

      expect((await actions.execute(location(), context)).success, isTrue);
      expect(port.asked, hasLength(1));
    });
  });

  group('unknown sub-actions', () {
    test('a sub-action nobody defined is refused', () async {
      engine.capabilities =
          RuntimeCapabilities(location: _RecordingPort((_) => _fix()));

      final r = await actions.execute(
        {'type': 'location', 'action': 'watch'},
        context,
      );

      expect(r.success, isFalse);
    });
  });
}
