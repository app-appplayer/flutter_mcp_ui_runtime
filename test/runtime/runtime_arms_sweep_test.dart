// Runtime paths nothing had walked.
//
// A state write that arrives with a `page.` prefix, a progress bar that
// announces itself to a screen reader, a computed expression the author got
// wrong, the asset loader the runtime uses when nothing has replaced it. Each
// belongs to a different subsystem and each fails the same way: silently, in
// a place the author cannot see from the document.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mcp_ui_runtime/src/accessibility/live_regions.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/assets/asset_ref.dart';
import 'package:flutter_mcp_ui_runtime/src/assets/asset_resolver.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/computed_property.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_watcher.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('a state write that carries a scope prefix', () {
    late StateManager stateManager;
    late RenderContext context;

    setUp(() {
      stateManager = StateManager()..initialize(<String, dynamic>{});
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
    });

    test('`page.` and `state.` reach the same place as the bare path', () {
      // §3.5 / §17.2.5 — the three spellings name one target. A prefix that
      // was stripped in the reader and kept in the writer produces a document
      // that writes `page.count` and reads `count` as unchanged, which looks
      // like a binding that does not update.
      context.setState('page.count', 1);
      expect(stateManager.get('count'), 1);

      context.setState('state.count', 2);
      expect(stateManager.get('count'), 2,
          reason: '`state.` is the §17.2.5 spelling and must not create a '
              'second variable literally named "state.count"');

      expect(stateManager.get('page.count'), isNull);
      expect(stateManager.get('state.count'), isNull);
    });

    test('`local.` stays out of shared state', () {
      context.setState('local.draft', 'typing');

      expect(context.localVariables['draft'], 'typing');
      expect(stateManager.get('draft'), isNull,
          reason: 'page-local scratch that leaks into app state is how one '
              'page\'s half-typed value shows up on another');
    });
  });

  group('a watcher built from configuration', () {
    test('reads its path and debounce, and its handler is safe to call',
        () async {
      final watcher = StateWatcher.fromConfig(<String, dynamic>{
        'path': 'user.name',
        'debounceMs': 250,
      });

      expect(watcher.path, 'user.name');
      expect(watcher.debounceMs, 250);

      // The configured form carries a placeholder handler until a host wires
      // actions to it. Calling it has to be harmless — the watcher is
      // installed either way, and a handler that threw would take down the
      // state write that triggered it.
      await expectLater(watcher.onChange('new', 'old'), completes);
    });

    test('a config with no debounce declares none', () {
      expect(
          StateWatcher.fromConfig(<String, dynamic>{'path': 'a'}).debounceMs, 0);
    });
  });

  group('a computed property the author got wrong', () {
    test('answers null instead of throwing out of the build', () {
      // `items[key]` reads as an index; `key` is not one. This is an ordinary
      // typo, and it happens while a page is being rendered — throwing here
      // takes down the whole document over one expression.
      final property = ComputedProperty.fromExpression('bad', '{{items[key]}}');

      final value = property.computeAndCache(<String, dynamic>{
        'items': <dynamic>[1, 2, 3],
        'key': 'first',
      });

      expect(value, isNull,
          reason: 'the property has no value, and the page keeps drawing '
              'everything else');
    });

    test('a well-formed one still computes', () {
      final property = ComputedProperty.fromExpression('total', '{{a}}');
      expect(property.computeAndCache(<String, dynamic>{'a': 42}), 42);
    });
  });

  group('the default asset loader', () {
    // Nothing in this file replaces it, so this is the shipped one.
    final shipped = AssetResolver.rootBundleLoader;

    tearDown(() {
      AssetResolver.rootBundleLoader = shipped;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', null);
    });

    test('reads bytes through the app bundle', () async {
      // Every other test in this suite replaces the loader, so the one the
      // runtime actually ships with had never run. A packaged image that
      // cannot be read shows as a missing asset on a real device and as
      // nothing at all here.
      AssetResolver.rootBundleLoader = shipped;
      final payload = Uint8List.fromList(utf8.encode('PNGDATA'));
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', (message) async {
        return ByteData.view(payload.buffer);
      });

      final bytes = await AssetResolver.builtin
          .bytesFor(AssetRef.parse('assets/logo.png')!);

      expect(bytes, isNotNull);
      expect(utf8.decode(bytes!), 'PNGDATA');
    });
  });

  group('a progress bar that announces itself', () {
    testWidgets('repeats the percentage as the value moves', (tester) async {
      final announced = <String>[];
      tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<
          dynamic>(SystemChannels.accessibility, (message) async {
        final data = message as Map<dynamic, dynamic>;
        if (data['type'] == 'announce') {
          announced.add((data['data'] as Map)['message'] as String);
        }
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<dynamic>(
              SystemChannels.accessibility, null));

      Future<void> pumpAt(double value) => tester.pumpWidget(MaterialApp(
            home: AccessibleProgressIndicator(
              value: value,
              label: 'Upload',
              announcementInterval: const Duration(milliseconds: 50),
            ),
          ));

      await pumpAt(0.25);
      await tester.pump();
      expect(announced, contains('Upload: 25%'),
          reason: 'a screen-reader user gets no progress from a bar they '
              'cannot see; the first reading is the one that says work '
              'started');

      // Progress arrives far faster than anyone can listen to it.
      for (final v in <double>[0.3, 0.35, 0.4, 0.5, 0.6, 0.8]) {
        await pumpAt(v);
        await tester.pump();
      }

      expect(announced, hasLength(1),
          reason: 'announcing on every change is what `announcementInterval` '
              'exists to prevent — a reader that says the percentage on '
              'every frame talks over the rest of the page');

      await tester.pump(const Duration(milliseconds: 60));
      expect(announced, contains('Upload: 80%'),
          reason: 'and once the interval passes it reports where things '
              'actually are — announcing once and going quiet reads as a '
              'stall');

      final before = announced.length;
      await tester.pump(const Duration(milliseconds: 60));
      expect(announced.length, before,
          reason: 'an unchanged value must not be repeated');

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    });
  });
}
