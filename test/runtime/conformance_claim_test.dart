// The runtime's conformance claim in the shape of spec §18.8, with the
// Profiles of §18.1.
//
// `ConformanceChecker` answered a v1.0 question — core / standard / advanced,
// by which widgets are registered — that no 1.4 document or host asks. §18.8
// says what a claim is, and §18.8 also says a runtime MUST NOT list a Profile
// it does not satisfy: Composition is claimed only when a host wired a
// definition resolver, Payment and Location only when their ports are wired.

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

class _Payment implements PaymentPort {
  @override
  Future<PaymentOutcome> checkout(PaymentRequest request) async =>
      throw UnimplementedError();
}

class _Location implements LocationPort {
  @override
  Future<Object> locate(LocationPrecision precision) async =>
      throw UnimplementedError();
}

class _Media implements MediaPort {
  @override
  Future<MediaSession> open({
    required AssetRef source,
    required AssetBytesReader readBytes,
    required bool isVideo,
    bool wantsWaveform = false,
    bool loop = false,
    bool muted = false,
    double volume = 1.0,
  }) async =>
      throw UnimplementedError();

  @override
  Widget? videoSurface(MediaSession session) => null;
}

Widget? _surface(BuildContext context, Map<String, dynamic> properties,
        SurfaceEvents events, SurfaceAssets assets) =>
    null;

void main() {
  late MCPUIRuntime runtime;

  setUp(() async {
    runtime = MCPUIRuntime(enableDebugMode: false);
    await runtime.initialize({
      'type': 'page',
      'content': {'type': 'text', 'content': 'x'},
    });
  });
  tearDown(() => runtime.dispose());

  test('a runtime with nothing wired claims what it implements itself', () {
    expect(runtime.conformanceClaim.profiles, [
      DslProfile.core,
      DslProfile.client,
      DslProfile.bundle,
      DslProfile.template,
    ]);
  });

  test('Advanced only with the behaviours its widgets depict (§18.5)', () {
    // Every catalogue widget is registered, but a player that cannot play, a
    // browser that cannot load and a map without tiles are chrome — §18.5
    // says a runtime in that state is not conformant at this level.
    expect(runtime.conformanceClaim.profiles,
        isNot(contains(DslProfile.advanced)));
    runtime.engine.capabilities = RuntimeCapabilities(
      media: _Media(),
      mediaSupportsVideo: true,
      webViewBuilder: _surface,
      mapBuilder: _surface,
      pdfBuilder: _surface,
    );
    expect(runtime.conformanceClaim.profiles, contains(DslProfile.advanced));
  });

  test('the catalogue is §10.1', () {
    final repo = Directory.current.path.split('/packages/')[0];
    final spec = File('$repo/specs/mcp_ui_dsl/spec/1.4/10_Advanced_Widgets.md');
    if (!spec.existsSync()) return; // outside the workspace
    final text = spec.readAsStringSync();
    final catalog = text.substring(
        text.indexOf('## 10.1 '), text.indexOf('## 10.2 '));
    final names = RegExp(r'^\| `([a-zA-Z]+)`', multiLine: true)
        .allMatches(catalog)
        .map((m) => m.group(1)!)
        .toSet();
    expect(advancedCatalog.toSet(), names);
  });

  test('Composition only with a definition resolver', () {
    expect(runtime.conformanceClaim.profiles,
        isNot(contains(DslProfile.composition)));
    runtime.registerDefinitionResolver((ref, origin) async => const {});
    expect(runtime.conformanceClaim.profiles, contains(DslProfile.composition));
  });

  test('Payment and Location only with their ports', () {
    expect(runtime.conformanceClaim.profiles,
        isNot(anyOf(contains(DslProfile.payment), contains(DslProfile.location))));
    runtime.engine.capabilities =
        RuntimeCapabilities(payment: _Payment(), location: _Location());
    expect(runtime.conformanceClaim.profiles,
        containsAll([DslProfile.payment, DslProfile.location]));
  });

  test('the JSON form is the §18.8 shape', () {
    final json = runtime.conformanceClaim.toJson();
    final claim = json['mcp_ui_dsl'] as Map<String, dynamic>;
    expect(claim['profiles'], ['Core', 'Client', 'Bundle', 'Template']);
    expect(claim['version'], '1.4');
    expect(claim['implementation'], 'flutter_mcp_ui_runtime');
    expect(claim['version_implementation'], runtimePackageVersion);
    expect(claim['optional'], isA<Map<String, dynamic>>());
  });

  test('the implementation version is the package version', () {
    final pubspec = File('pubspec.yaml').readAsLinesSync();
    final line = pubspec.firstWhere((l) => l.startsWith('version: '));
    expect(runtimePackageVersion, line.substring('version: '.length).trim(),
        reason: 'bump runtimePackageVersion with pubspec.yaml');
  });
}
