// Spec §11 — Application metadata delivery through the runtime.
//
// Covers:
//   1. DSL root metadata seeds `runtime.appMetadata`.
//   2. `destroy` clears the cache back to null.
//   3. `notifications/resources/updated` for `ui://app/info` (extended
//      mode — payload inlined) replaces the cache and notifies listeners.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

void main() {
  test('TC-S11-01: initialize seeds appMetadata from DSL root', () async {
    final runtime = MCPUIRuntime();
    await runtime.initialize({
      'type': 'application',
      'id': 'com.example.demo',
      'title': 'Demo',
      'version': '1.0.0',
      'description': 'An example app',
      'icon': 'https://example.com/icon.png',
      'category': 'productivity',
      'publisher': {
        'name': 'Example Corp',
        'website': 'https://example.com',
      },
      'timestamps': {
        'createdAt': '2026-01-01T00:00:00Z',
        'updatedAt': '2026-04-18T00:00:00Z',
      },
      'initialRoute': '/',
      'routes': {'/': 'ui://page/home'},
    }, pageLoader: (_) async => {
          'type': 'page',
          'content': {'type': 'text', 'text': 'home'},
        });

    final meta = runtime.appMetadata.value;
    expect(meta, isNotNull);
    expect(meta!.id, equals('com.example.demo'));
    expect(meta.title, equals('Demo'));
    expect(meta.icon, equals('https://example.com/icon.png'));
    expect(meta.category, equals('productivity'));
    expect(meta.publisher?.name, equals('Example Corp'));
    expect(meta.publisher?.url, equals('https://example.com'));
    expect(meta.timestamps?.updatedAt?.toIso8601String(),
        equals('2026-04-18T00:00:00.000Z'));

    await runtime.destroy();
  });

  test('TC-S11-02: destroy resets appMetadata to null', () async {
    final runtime = MCPUIRuntime();
    await runtime.initialize({
      'type': 'application',
      'title': 'X',
      'version': '1.0.0',
      'icon': 'https://x/icon.png',
      'initialRoute': '/',
      'routes': {'/': 'ui://page/home'},
    }, pageLoader: (_) async => {
          'type': 'page',
          'content': {'type': 'text', 'text': 'home'},
        });
    expect(runtime.appMetadata.value, isNotNull);

    await runtime.destroy();
    expect(runtime.appMetadata.value, isNull);
  });

  test('TC-S11-03: page-only DSL leaves appMetadata null', () async {
    final runtime = MCPUIRuntime();
    await runtime.initialize({
      'type': 'page',
      'content': {'type': 'text', 'text': 'hello'},
    });
    expect(runtime.appMetadata.value, isNull);
    await runtime.destroy();
  });

  test('TC-S11-04: ui://app/info extended-mode update replaces cache',
      () async {
    final runtime = MCPUIRuntime();
    await runtime.initialize({
      'type': 'application',
      'title': 'Demo',
      'version': '1.0.0',
      'icon': 'https://example.com/v1.png',
      'initialRoute': '/',
      'routes': {'/': 'ui://page/home'},
    }, pageLoader: (_) async => {
          'type': 'page',
          'content': {'type': 'text', 'text': 'home'},
        });

    expect(runtime.appMetadata.value?.icon,
        equals('https://example.com/v1.png'));

    var notifyCount = 0;
    runtime.appMetadata.addListener(() => notifyCount++);

    // Extended-mode MCP notification (spec §6.4): content inlined as
    // `{ text: <json-string> }`.
    await runtime.handleNotification({
      'method': 'notifications/resources/updated',
      'params': {
        'uri': 'ui://app/info',
        'content': {
          'text': jsonEncode({
            'title': 'Demo',
            'version': '1.0.1',
            'icon': 'https://example.com/v2.png',
            'description': 'Updated description',
          }),
        },
      },
    });

    expect(notifyCount, equals(1));
    expect(runtime.appMetadata.value?.icon,
        equals('https://example.com/v2.png'));
    expect(runtime.appMetadata.value?.description,
        equals('Updated description'));

    await runtime.destroy();
  });

  test('TC-S11-05: ui://app/info standard-mode update uses resourceReader',
      () async {
    final runtime = MCPUIRuntime();
    await runtime.initialize({
      'type': 'application',
      'title': 'Demo',
      'version': '1.0.0',
      'icon': 'https://example.com/v1.png',
      'initialRoute': '/',
      'routes': {'/': 'ui://page/home'},
    }, pageLoader: (_) async => {
          'type': 'page',
          'content': {'type': 'text', 'text': 'home'},
        });

    await runtime.handleNotification(
      {
        'method': 'notifications/resources/updated',
        'params': {'uri': 'ui://app/info'},
      },
      resourceReader: (uri) async {
        expect(uri, equals('ui://app/info'));
        return jsonEncode({
          'title': 'Demo',
          'version': '1.0.2',
          'icon': 'https://example.com/v3.png',
        });
      },
    );

    expect(runtime.appMetadata.value?.icon,
        equals('https://example.com/v3.png'));

    await runtime.destroy();
  });
}
