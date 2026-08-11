// `fileInput` — 23% covered, and the uncovered 77% was everything that
// happens after the user picks a file.
//
// The picker itself belongs to the platform, so it is replaced by a double
// that answers what the test says. Everything downstream of it is the
// runtime's own: the size limit that must SURFACE rather than drop a file, the
// count limit, the descriptor a document receives, and the difference between
// a cancelled dialog and a failed one. A file silently missing from an upload
// is the failure mode here, and it is invisible on screen.

import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/default_widgets.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for the platform picker. Extending `FilePicker` is what makes it
/// installable — the platform interface verifies the subclass token.
class _FakePicker extends FilePicker {
  _FakePicker();

  FilePickerResult? answer;
  Object? failWith;
  final calls = <Map<String, dynamic>>[];

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    dynamic Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    calls.add({
      'allowMultiple': allowMultiple,
      'withData': withData,
      'type': type,
      'allowedExtensions': allowedExtensions,
    });
    if (failWith != null) throw failWith!;
    return answer;
  }
}

PlatformFile file(String name, {int? size, Uint8List? bytes, String? path}) =>
    PlatformFile(
      name: name,
      size: size ?? bytes?.length ?? 0,
      bytes: bytes,
      path: path,
    );

void main() {
  late StateManager stateManager;
  late RenderContext context;
  late _FakePicker picker;

  setUp(() {
    picker = _FakePicker();
    FilePicker.platform = picker;

    stateManager = StateManager()..initialize(<String, dynamic>{});
    final registry = WidgetRegistry();
    DefaultWidgets.registerAll(registry);
    final bindingEngine = BindingEngine();
    final actionHandler = ActionHandler();
    context = RenderContext(
      renderer: Renderer(
        widgetRegistry: registry,
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

  Future<void> pump(WidgetTester tester, Map<String, dynamic> definition) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AnimatedBuilder(
          animation: stateManager,
          builder: (_, __) => context.renderer.renderWidget(definition, context),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> tapChoose(WidgetTester tester) async {
    await tester.tap(find.byType(OutlinedButton));
    await tester.pumpAndSettle();
  }

  Map<String, dynamic> input({Map<String, dynamic> extra = const {}}) => {
        'type': 'fileInput',
        'binding': 'files',
        ...extra,
      };

  List<dynamic> selected() =>
      stateManager.get<List<dynamic>>('files') ?? const [];

  group('picking', () {
    testWidgets('a chosen file becomes a descriptor in state', (tester) async {
      picker.answer = FilePickerResult([
        file('report.pdf', bytes: Uint8List.fromList([1, 2, 3])),
      ]);
      await pump(tester, input());

      await tapChoose(tester);

      expect(selected(), hasLength(1));
      final descriptor = selected().single as Map;
      expect(descriptor['name'], 'report.pdf');
      expect(descriptor['size'], 3);
      expect(descriptor['mimeType'], 'application/pdf',
          reason: 'a document uploading this reads the mime type; guessing '
              'octet-stream for a known extension makes the server guess too');
      expect(descriptor['bytes'],
          'data:application/pdf;base64,${base64Encode([1, 2, 3])}',
          reason: 'the bytes travel as a data uri because web has no path — '
              'this is the portable half of the contract');
    });

    testWidgets('a path is carried when the platform has one', (tester) async {
      picker.answer = FilePickerResult([
        file('a.txt', size: 2, path: '/tmp/a.txt'),
      ]);
      await pump(tester, input());

      await tapChoose(tester);
      expect((selected().single as Map)['path'], '/tmp/a.txt');
    });

    testWidgets('and is absent when it has none — deliberately',
        (tester) async {
      picker.answer = FilePickerResult([file('a.txt', size: 2)]);
      await pump(tester, input());

      await tapChoose(tester);
      expect((selected().single as Map).containsKey('path'), isFalse,
          reason: 'an empty string would read as a path that exists; the key '
              'being absent is what tells a document to use the bytes');
    });

    testWidgets('cancelling clears the selection rather than erroring',
        (tester) async {
      stateManager.set('files', [
        {'name': 'old.txt'}
      ]);
      picker.answer = null;
      await pump(tester, input(extra: {
        'onError': {
          'type': 'state',
          'action': 'set',
          'binding': 'errored',
          'value': true,
        },
      }));

      await tapChoose(tester);

      expect(selected(), isEmpty);
      expect(stateManager.get('errored'), isNull,
          reason: 'a cancelled dialog is a decision, not a failure — showing '
              'an error for it trains the user to ignore errors');
    });

    testWidgets('onChange carries the descriptors', (tester) async {
      picker.answer = FilePickerResult([file('a.txt', size: 1)]);
      await pump(tester, input(extra: {
        'onChange': {
          'type': 'state',
          'action': 'set',
          'binding': 'seen',
          'value': '{{event.value}}',
        },
      }));

      await tapChoose(tester);

      final seen = stateManager.get<List<dynamic>>('seen')!;
      expect((seen.single as Map)['name'], 'a.txt');
    });
  });

  group('the limits', () {
    testWidgets('a file over maxBytes is reported and left out', (tester) async {
      picker.answer = FilePickerResult([
        file('small.txt', size: 10),
        file('huge.bin', size: 5000),
      ]);
      await pump(tester, input(extra: {
        'maxBytes': 100,
        'onError': {
          'type': 'state',
          'action': 'set',
          'binding': 'error',
          'value': '{{event.message}}',
        },
      }));

      await tapChoose(tester);

      expect(selected().map((f) => (f as Map)['name']), ['small.txt']);
      expect(stateManager.get<String>('error'), contains('huge.bin'),
          reason: '§2.6.24 — an oversized file that simply disappears from the '
              'list is the worst outcome: the user believes it was attached');
    });

    testWidgets('maxFiles takes the first N', (tester) async {
      picker.answer = FilePickerResult([
        file('a.txt', size: 1),
        file('b.txt', size: 1),
        file('c.txt', size: 1),
      ]);
      await pump(tester, input(extra: {'multiple': true, 'maxFiles': 2}));

      await tapChoose(tester);

      expect(selected().map((f) => (f as Map)['name']), ['a.txt', 'b.txt']);
    });

    testWidgets('multiple is passed through to the picker', (tester) async {
      picker.answer = FilePickerResult([file('a.txt', size: 1)]);
      await pump(tester, input(extra: {'multiple': true}));

      await tapChoose(tester);
      expect(picker.calls.single['allowMultiple'], isTrue);
      expect(picker.calls.single['withData'], isTrue,
          reason: 'without the bytes there is nothing to upload on web');
    });

    testWidgets('accept becomes an extension filter, and a wildcard widens to '
        'any', (tester) async {
      picker.answer = FilePickerResult([file('a.png', size: 1)]);

      await pump(tester, input(extra: {
        'accept': ['.png', '.jpg'],
      }));
      await tapChoose(tester);
      expect(picker.calls.last['type'], FileType.custom);
      expect(picker.calls.last['allowedExtensions'], ['png', 'jpg']);

      await pump(tester, input(extra: {
        'accept': ['image/*'],
      }));
      await tapChoose(tester);
      expect(picker.calls.last['type'], FileType.any,
          reason: 'a mime pattern has no extension list — narrowing to an '
              'empty filter would let the user pick nothing at all');
      expect(picker.calls.last['allowedExtensions'], isNull);
    });
  });

  group('failures', () {
    testWidgets('a picker that throws is reported through onError',
        (tester) async {
      picker.failWith = StateError('no permission');
      await pump(tester, input(extra: {
        'onError': {
          'type': 'state',
          'action': 'set',
          'binding': 'error',
          'value': '{{event.message}}',
        },
      }));

      await tapChoose(tester);

      expect(stateManager.get<String>('error'), contains('no permission'),
          reason: 'the exception belongs in the document\'s error handler, '
              'not in the zone where nobody sees it');
      expect(selected(), isEmpty);
    });

    testWidgets('with no onError declared a failure is still not fatal',
        (tester) async {
      picker.failWith = StateError('no permission');
      await pump(tester, input());

      await tapChoose(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('the surface', () {
    testWidgets('the label is the button, and disabled means unpressable',
        (tester) async {
      await pump(tester, input(extra: {'label': 'Attach a receipt'}));
      expect(find.text('Attach a receipt'), findsOneWidget);

      await pump(tester, input(extra: {'enabled': false}));
      final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('with no label it still says what it does', (tester) async {
      await pump(tester, input());
      expect(find.text('Choose file'), findsOneWidget);
    });

    testWidgets('the current selection is listed by name and size',
        (tester) async {
      stateManager.set('files', [
        {'name': 'report.pdf', 'size': 2048},
      ]);
      await pump(tester, input());

      expect(find.textContaining('report.pdf'), findsOneWidget);
      expect(find.textContaining('2'), findsWidgets,
          reason: 'the size is what tells a user which of two same-named '
              'files they attached');
    });

    testWidgets('preview shows the image bytes back', (tester) async {
      final png = base64Encode(Uint8List.fromList(List.filled(8, 0)));
      stateManager.set('files', [
        {
          'name': 'a.png',
          'size': 8,
          'mimeType': 'image/png',
          'bytes': 'data:image/png;base64,$png',
        },
      ]);
      await pump(tester, input(extra: {'preview': true}));

      expect(find.byType(Image), findsOneWidget);
      tester.takeException(); // the bytes are not a real png
    });

    testWidgets('without preview no image is built', (tester) async {
      stateManager.set('files', [
        {'name': 'a.png', 'size': 8, 'bytes': 'data:image/png;base64,AAAA'},
      ]);
      await pump(tester, input());

      expect(find.byType(Image), findsNothing,
          reason: 'decoding every attachment a user picks is work the '
              'document did not ask for');
    });

    testWidgets('a bound value that is not a list shows nothing rather than '
        'throwing', (tester) async {
      stateManager.set('files', 'still loading');
      await pump(tester, input());

      expect(find.text('Choose file'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
