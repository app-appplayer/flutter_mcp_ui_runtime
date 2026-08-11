// The last of the unit-level surfaces nothing had called.
//
// Watch streams, the default dark theme, a decision that expires, the
// singleton door on the widget cache, an asset-loaded translation file. Each
// is small; each is the only path some caller takes.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mcp_ui_runtime/src/i18n/i18n_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/i18n/i18n_loader.dart';
import 'package:flutter_mcp_ui_runtime/src/optimization/widget_cache.dart';
import 'package:flutter_mcp_ui_runtime/src/permissions/permission_storage.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('watching a path', () {
    test('an updateAll that touches it reaches the watcher', () async {
      final state = StateManager()..initialize(<String, dynamic>{'a': 1});
      final seen = <dynamic>[];
      final sub = state.watch<dynamic>('a').listen(seen.add);

      // `updateAll` is the batch door — a document restoring a form writes
      // every field at once, and a watcher wired to one of them has to hear
      // about it the same as it would from `set`.
      state.updateAll(<String, dynamic>{'a': 2, 'b': 3});
      await Future<void>.delayed(Duration.zero);

      expect(seen, [2],
          reason: 'a stream that only fires for single writes leaves a screen '
              'stale after every batch');

      await sub.cancel();
      state.dispose();
    });
  });

  group('the default theme', () {
    tearDown(() => ThemeManager.instance.reset());

    test('a runtime with no theme at all still builds a dark one', () {
      final theme = ThemeManager.instance..reset();

      final dark = theme.toFlutterTheme(isDark: true);
      final light = theme.toFlutterTheme(isDark: false);

      expect(dark.colorScheme.brightness, Brightness.dark,
          reason: 'a document that declares no theme still runs on a device '
              'set to dark; falling back to the light definition puts black '
              'text on a black background');
      expect(dark.colorScheme.surface, isNot(light.colorScheme.surface));
    });
  });

  group('WidgetCache', () {
    test('the constructor door and the instance door are the same cache', () {
      expect(identical(WidgetCache(), WidgetCache.instance), isTrue,
          reason: 'two caches would each hold a copy of every widget, and the '
              'clear() on dispose would empty only one of them');
    });
  });

  group('a decision that expires', () {
    test('a denial with a lifetime carries its expiry', () {
      final decision = PermissionDecision.deny(
        remember: true,
        expiresIn: const Duration(minutes: 30),
        scope: '/workspace',
      );

      expect(decision.granted, isFalse);
      expect(decision.expiresAt, isNotNull,
          reason: 'a remembered "no" with no expiry is permanent — the user '
              'asked for half an hour, not for ever');
      expect(decision.expiresAt!.isAfter(DateTime.now()), isTrue);
      expect(decision.scope, '/workspace');
    });

    test('a denial with no lifetime does not invent one', () {
      final decision = PermissionDecision.deny(remember: true);
      expect(decision.expiresAt, isNull);
    });
  });

  group('translations loaded from an asset', () {
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', null);
      I18nManager.instance.clear();
    });

    test('a JSON asset is parsed and merged', () async {
      final payload = utf8.encode(jsonEncode(<String, dynamic>{
        'en': <String, dynamic>{'hello': 'Hello'},
      }));
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', (message) async {
        return ByteData.view(Uint8List.fromList(payload).buffer);
      });

      await I18nLoader.loadFromAsset('assets/i18n.json');

      I18nManager.instance.setLocale('en');
      expect(I18nManager.instance.translate('hello'), 'Hello',
          reason: 'the packaged-strings path is how most apps ship their '
              'translations; a silent failure here shows keys on every screen');
    });

    test('an asset that is not JSON is survived', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', (message) async {
        return ByteData.view(
            Uint8List.fromList(utf8.encode('<html>nope</html>')).buffer);
      });

      await expectLater(I18nLoader.loadFromAsset('assets/i18n.json'), completes,
          reason: 'a mis-packaged file must not take startup down with it');
    });
  });
}
