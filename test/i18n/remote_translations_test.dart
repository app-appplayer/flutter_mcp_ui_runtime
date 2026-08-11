// Translations fetched from a `remoteUrl`.
//
// This is the path a document takes when its strings live on the server rather
// than in the bundle, and it could not be tested at all: the fetch went
// through the top-level `http.get`, so the only way to reach it was a real
// network call. That is a gap in the design rather than a fact about the code,
// so the manager now takes a client — and these are the answers it has to
// handle: a body that parses, a body that does not, and a server that refuses.

import 'dart:convert';

import 'package:flutter_mcp_ui_runtime/src/i18n/i18n_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late I18nManager i18n;

  setUp(() {
    i18n = I18nManager.instance;
    i18n.clear();
  });

  tearDown(() {
    I18nManager.httpClient = http.Client();
    I18nManager.instance.clear();
  });

  test('a remote bundle is merged and readable', () async {
    I18nManager.httpClient = MockClient((request) async {
      expect(request.url.toString(), 'https://cdn.example.com/i18n.json');
      return http.Response(
        jsonEncode({
          'en': {'greeting': 'Hello'},
          'ko': {'greeting': '안녕'},
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await i18n.loadTranslations(<String, dynamic>{
      'fallbackLocale': 'en',
      'remoteUrl': 'https://cdn.example.com/i18n.json',
    });

    i18n.setLocale('ko');
    expect(i18n.translate('greeting'), '안녕',
        reason: 'a document whose strings live on the server shows keys '
            'instead of words when this path quietly does nothing');

    i18n.setLocale('en');
    expect(i18n.translate('greeting'), 'Hello');
  });

  // MEASURED, not assumed: a remote file REPLACES a locale wholesale rather
  // than merging into it. `remoteUrl` is not in the spec — §12 defines the
  // inline `translations` map and nothing about a remote source — so this is
  // an implementation choice with no written rule behind it. Pinned as it
  // behaves, with the question recorded rather than "fixed" by guessing.
  test('a remote locale replaces that locale, and leaves the others alone',
      () async {
    I18nManager.httpClient = MockClient((_) async => http.Response(
          jsonEncode({
            'en': {'remote': 'from the server'}
          }),
          200,
        ));

    await i18n.loadTranslations(<String, dynamic>{
      'fallbackLocale': 'en',
      'translations': {
        'en': {'local': 'from the bundle'},
        'ko': {'local': '번들에서'},
      },
      'remoteUrl': 'https://cdn.example.com/i18n.json',
    });

    expect(i18n.translate('remote'), 'from the server');
    expect(i18n.translate('local'), 'local',
        reason: 'the bundle key is GONE for the locale the remote file also '
            'carries — the remote map is assigned over it. Whether that is '
            'right is a spec question; that it happens is measured here so a '
            'change to it cannot pass unnoticed');

    i18n.setLocale('ko');
    expect(i18n.translate('local'), '번들에서',
        reason: 'a locale the remote file never mentions keeps everything the '
            'bundle shipped');
  });

  test('a refusal leaves the bundle strings intact', () async {
    I18nManager.httpClient =
        MockClient((_) async => http.Response('nope', 503));

    await i18n.loadTranslations(<String, dynamic>{
      'fallbackLocale': 'en',
      'translations': {
        'en': {'local': 'from the bundle'}
      },
      'remoteUrl': 'https://cdn.example.com/i18n.json',
    });

    expect(i18n.translate('local'), 'from the bundle',
        reason: 'a server that is down must not take the strings the document '
            'shipped with — the screen still has to read');
  });

  test('a body that is not translations is survived', () async {
    I18nManager.httpClient =
        MockClient((_) async => http.Response('<html>404</html>', 200));

    await i18n.loadTranslations(<String, dynamic>{
      'fallbackLocale': 'en',
      'translations': {
        'en': {'local': 'from the bundle'}
      },
      'remoteUrl': 'https://cdn.example.com/i18n.json',
    });

    expect(i18n.translate('local'), 'from the bundle',
        reason: 'a captive-portal HTML page answered with 200 is the classic '
            'shape here, and it must not take the app down');
  });
}
