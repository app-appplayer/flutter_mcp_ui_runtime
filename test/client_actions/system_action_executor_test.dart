// `client.system`, `client.clipboard` and `client.notification`.
//
// 0% covered before this file: not one of the three had ever been called. Two
// of them exist mainly to REFUSE — the runtime posts no OS notification and
// reads no image from the clipboard — and a refusal that is never exercised is
// the easiest thing in a codebase to accidentally turn back into a silent
// success. §6.13.1 is the rule at stake: a capability that was not performed
// is reported as not performed, never as `{shown: true}`.
//
// The clipboard is driven through the real platform channel with a recording
// handler, which is how Flutter itself tests it: `Clipboard.setData` has no
// other observable effect in a test binding.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/client_actions/executors/system_action_executor.dart';
import 'package:flutter_mcp_ui_runtime/src/platform/host_platform.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SystemActionExecutor executor;
  late RenderContext context;

  /// What the platform is holding, as far as the runtime can tell.
  String? clipboard;
  bool clipboardThrows = false;

  setUp(() {
    executor = SystemActionExecutor();
    clipboard = null;
    clipboardThrows = false;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (clipboardThrows) {
        throw PlatformException(code: 'clipboard-unavailable');
      }
      switch (call.method) {
        case 'Clipboard.setData':
          clipboard = (call.arguments as Map)['text'] as String?;
          return null;
        case 'Clipboard.getData':
          return clipboard == null ? null : <String, dynamic>{'text': clipboard};
      }
      return null;
    });

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
      buildContext: null,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('client.system — system info', () {
    test('reports the platform it is actually running on', () async {
      final result = await executor.getSystemInfo(const {}, context);
      expect(result.success, isTrue);

      final info = result.data as Map<String, dynamic>;
      final expected = Platform.isMacOS
          ? 'macos'
          : Platform.isLinux
              ? 'linux'
              : Platform.isWindows
                  ? 'windows'
                  : 'unknown';
      expect(info['platform'], expected,
          reason: 'a document branches on this to decide what it can ask for; '
              'the wrong name sends it down the wrong branch');
      expect(info['isWeb'], isFalse);
    });

    test('locale and locales come from the platform dispatcher', () async {
      final info =
          (await executor.getSystemInfo(const {}, context)).data as Map;
      expect(info['locale'], isA<String>());
      expect(info['locale'], isNotEmpty);
      expect(info['locales'], isA<List<String>>());
    });

    test('a `properties` list narrows the answer to exactly those keys',
        () async {
      final result = await executor.getSystemInfo(
        const {'properties': ['platform', 'isWeb']},
        context,
      );
      final info = result.data as Map<String, dynamic>;

      expect(info.keys, unorderedEquals(<String>['platform', 'isWeb']));
      expect(info.containsKey('locale'), isFalse,
          reason: 'the filter exists so a document can ask for one fact '
              'without receiving the device inventory');
    });

    test('a property nobody knows about is omitted rather than answered null',
        () async {
      final result = await executor.getSystemInfo(
        const {'properties': ['platform', 'bloodType']},
        context,
      );
      final info = result.data as Map<String, dynamic>;

      expect(info.keys, ['platform']);
      expect(info.containsKey('bloodType'), isFalse,
          reason: 'a null under the asked-for key would read as "this device '
              'has no such value", which is a different claim');
    });

    test('an empty `properties` list is treated as no filter', () async {
      final result =
          await executor.getSystemInfo(const {'properties': []}, context);
      final info = result.data as Map<String, dynamic>;
      expect(info.keys, contains('locale'));
    });
  });

  group('client.clipboard — text', () {
    test('write then read round-trips through the platform', () async {
      final written = await executor
          .clipboardWrite(const {'content': 'copied text'}, context);
      expect(written.success, isTrue);
      expect(clipboard, 'copied text',
          reason: 'the write has to reach the platform channel; a success '
              'that never called it means nothing was copied');

      final read = await executor.clipboardRead(const {}, context);
      final data = read.data as Map<String, dynamic>;
      expect(data['text'], 'copied text');
      expect(data['hasContent'], isTrue);
      expect(data['format'], 'text');
    });

    test('`text` is accepted as well as `content`', () async {
      // CA-04: the spec says `content`, the earlier implementation said
      // `text`. Both have to work or documents written against either break.
      await executor.clipboardWrite(const {'text': 'via text key'}, context);
      expect(clipboard, 'via text key');
    });

    test('an empty clipboard is reported as empty, not as a failure', () async {
      final read = await executor.clipboardRead(const {}, context);
      final data = read.data as Map<String, dynamic>;

      expect(read.success, isTrue);
      expect(data['text'], isNull);
      expect(data['hasContent'], isFalse,
          reason: '`hasContent` is what a document branches on — an empty '
              'clipboard is an ordinary state, not an error');
    });

    test('a write with no content at all is refused by name', () async {
      final result = await executor.clipboardWrite(const {}, context);
      expect(result.success, isFalse);
      expect(result.error, contains('Content'));
      expect(clipboard, isNull);
    });

    test('a platform failure is reported rather than thrown', () async {
      clipboardThrows = true;

      final read = await executor.clipboardRead(const {}, context);
      expect(read.success, isFalse);
      expect(read.error, contains('Failed to read clipboard'));

      final write =
          await executor.clipboardWrite(const {'content': 'x'}, context);
      expect(write.success, isFalse);
      expect(write.error, contains('Failed to write to clipboard'));
    });
  });

  // The device-info switch has an arm per platform, and a test process is
  // only ever one of them. `HostPlatform.override` is the seam that lets the
  // other arms run — and on a host whose plugin is not there, what matters is
  // that the answer still arrives with the platform named rather than the
  // whole call failing.
  group('client.system on other platforms', () {
    tearDown(HostPlatform.clearOverride);

    for (final platform in const ['windows', 'linux', 'android', 'ios']) {
      test('$platform still answers, with the platform named', () async {
        HostPlatform.override(name: platform);

        final result = await executor.getSystemInfo(const {}, context);
        final info = result.data as Map<String, dynamic>;

        expect(result.success, isTrue,
            reason: 'the device plugin is absent in a test process, so this '
                'is also the "device info could not be read" path — the rest '
                'of the answer (platform, locale, screen) is still owed to '
                'the document');
        expect(info['platform'], platform);
        expect(info['isWeb'], isFalse);
      });
    }

    test('on the web it does not go looking for a device at all', () async {
      HostPlatform.override(name: 'web');

      final result = await executor.getSystemInfo(const {}, context);
      final info = result.data as Map<String, dynamic>;

      expect(info['isWeb'], isTrue);
      expect(info.containsKey('model'), isFalse,
          reason: 'there is no device plugin on the web; asking anyway is how '
              'a browser tab ends up reporting a phone');
    });
  });

  group('client.clipboard — the shapes that are refused', () {
    test('an html write with no content is refused by name', () async {
      final result =
          await executor.clipboardWrite(const {'format': 'html'}, context);

      expect(result.success, isFalse);
      expect(result.error, contains('Content parameter is required'),
          reason: 'the format branch has its own required-content check, and '
              'a null written to the board silently clears it');
    });
  });

  group('client.clipboard — html and image', () {
    test('an html write stores the text flavour and says so', () async {
      final result = await executor.clipboardWrite(
        const {'format': 'html', 'content': '<b>bold</b>'},
        context,
      );
      final data = result.data as Map<String, dynamic>;

      expect(clipboard, '<b>bold</b>');
      expect(data['format'], 'html');
      expect(data['note'], contains('text flavour'),
          reason: 'the document asked for HTML and got plain text — the '
              'difference has to travel with the answer');
    });

    test('an html read answers the text flavour, with the same caveat',
        () async {
      clipboard = '<i>on the board</i>';
      final result =
          await executor.clipboardRead(const {'format': 'html'}, context);
      final data = result.data as Map<String, dynamic>;

      expect(data['text'], '<i>on the board</i>');
      expect(data['format'], 'html');
      expect(data['note'], isNotNull);
    });

    test('an image read is refused with UNSUPPORTED, not reported empty',
        () async {
      // §6.13.1, and the exact wording of the comment in the executor:
      // `hasContent: false` would read as "the clipboard is empty", which is a
      // different fact from "this runtime cannot look".
      final result =
          await executor.clipboardRead(const {'format': 'image'}, context);

      expect(result.success, isFalse);
      expect(result.errorCode, 'UNSUPPORTED');
      expect(result.errorDetails?['format'], 'image');
    });

    test('an image write is refused', () async {
      final result = await executor.clipboardWrite(
        const {'format': 'image', 'content': 'data:...'},
        context,
      );
      expect(result.success, isFalse);
      expect(result.error, contains('Image clipboard write'));
    });

    test('an unknown format falls back to text rather than failing', () async {
      final result = await executor.clipboardWrite(
        const {'format': 'runes', 'content': 'plain'},
        context,
      );
      expect(result.success, isTrue);
      expect(clipboard, 'plain');
    });
  });

  group('client.notification', () {
    test('is refused as UNSUPPORTED, and never claims the user saw anything',
        () async {
      final result = await executor.showNotification(
        const {'title': 'Build finished', 'message': 'All green'},
        context,
      );

      expect(result.success, isFalse);
      expect(result.errorCode, 'UNSUPPORTED');
      expect(result.errorDetails?['shown'], isFalse,
          reason: 'this is the whole point: a document that reads success as '
              '"the user was told" will not fall back to its in-app '
              'notification widget, and the message reaches no one');
      expect(result.error, contains('in-app'),
          reason: 'the message names the fallback, which is what makes the '
              'refusal actionable rather than a dead end');
    });

    test('it carries back what it was asked to show, under both spellings',
        () async {
      // CA-05: `message`/`severity` per spec, `body` from the earlier
      // implementation. A host wiring its own notifier reads these out of the
      // error details, so both spellings have to arrive.
      final spec = await executor.showNotification(
        const {'title': 'T', 'message': 'M', 'severity': 'warning'},
        context,
      );
      expect(spec.errorDetails?['body'], 'M');
      expect(spec.errorDetails?['severity'], 'warning');

      final legacy = await executor
          .showNotification(const {'title': 'T', 'body': 'B'}, context);
      expect(legacy.errorDetails?['body'], 'B');
      expect(legacy.errorDetails?.containsKey('severity'), isFalse,
          reason: 'an absent severity must not be invented');
    });

    test('with nothing declared it still refuses, with defaults', () async {
      final result = await executor.showNotification(const {}, context);
      expect(result.success, isFalse);
      expect(result.errorDetails?['title'], 'Notification');
      expect(result.errorDetails?['body'], '');
    });
  });
}
