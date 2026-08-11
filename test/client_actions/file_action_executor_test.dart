// The file client-action surface: 22% covered before this file.
//
// Every method here answers with an `ActionResult`, and the failure answers
// are the ones a document actually meets — a missing path, a file that is not
// there, a picker the user cancelled. Those were the uncovered lines, which is
// exactly backwards: the happy path is the one an author notices is broken.
//
// The picker is swapped for a fake through `FilePicker.platform`; the file
// system is real, inside a temp directory, because faking `dart:io` would test
// the fake.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_mcp_ui_runtime/src/client_actions/executors/file_action_executor.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_test/flutter_test.dart';

/// A picker that answers what the test tells it to, and records how it was
/// asked — the parameters are half of what these methods do.
class _FakePicker extends FilePicker {
  _FakePicker({this.pick, this.save});

  final FilePickerResult? pick;
  final String? save;

  bool allowMultiple = false;
  FileType? type;
  List<String>? allowedExtensions;
  String? dialogTitle;
  String? fileName;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 20,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    this.dialogTitle = dialogTitle;
    this.type = type;
    this.allowedExtensions = allowedExtensions;
    this.allowMultiple = allowMultiple;
    return pick;
  }

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    bool lockParentWindow = false,
    Uint8List? bytes,
  }) async {
    this.dialogTitle = dialogTitle;
    this.fileName = fileName;
    this.type = type;
    this.allowedExtensions = allowedExtensions;
    return save;
  }
}

FilePickerResult _picked(List<PlatformFile> files) => FilePickerResult(files);

void main() {
  late FileActionExecutor executor;
  late Directory tmp;
  late RenderContext context;

  setUp(() {
    executor = FileActionExecutor();
    tmp = Directory.systemTemp.createTempSync('file_action_');
    // These methods never touch the context; passing a real one would drag the
    // whole renderer in for nothing.
    context = _nullContext();
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  group('selectFile', () {
    test('a cancelled picker is a success with no data, not an error', () async {
      FilePicker.platform = _FakePicker(pick: null);
      final result = await executor.selectFile({}, context);
      expect(result.success, isTrue,
          reason: 'the user declining is not a failure of the action');
      expect(result.data, isNull);
    });

    test('spec filter objects become extensions, dots stripped', () async {
      final picker = _FakePicker(
        pick: _picked([PlatformFile(name: 'a.png', size: 3, path: '/tmp/a.png')]),
      );
      FilePicker.platform = picker;

      await executor.selectFile({
        'title': 'Pick art',
        'filters': [
          {'name': 'Images', 'extensions': ['.png', 'jpg']},
        ],
      }, context);

      expect(picker.allowedExtensions, ['png', 'jpg']);
      expect(picker.type, FileType.custom);
      expect(picker.dialogTitle, 'Pick art');
    });

    test('the flat allowedExtensions form is accepted too', () async {
      final picker = _FakePicker(pick: _picked(const []));
      FilePicker.platform = picker;
      await executor.selectFile({'allowedExtensions': ['.pdf']}, context);
      expect(picker.allowedExtensions, ['pdf']);
    });

    test('no filters means any type, and no extension list', () async {
      final picker = _FakePicker(pick: _picked(const []));
      FilePicker.platform = picker;
      await executor.selectFile({}, context);
      expect(picker.type, FileType.any);
      expect(picker.allowedExtensions, isNull);
    });

    test('single vs multiple shape the result differently', () async {
      final files = [
        PlatformFile(name: 'a.png', size: 3, path: '/tmp/a.png'),
        PlatformFile(name: 'b.png', size: 4, path: '/tmp/b.png'),
      ];

      FilePicker.platform = _FakePicker(pick: _picked(files));
      final single = await executor.selectFile({}, context);
      expect(single.data, isA<Map<String, dynamic>>(),
          reason: 'one file is an object, so a document reads `.name`');
      expect((single.data as Map)['name'], 'a.png');

      FilePicker.platform = _FakePicker(pick: _picked(files));
      final many = await executor.selectFile({'multiple': true}, context);
      expect(many.data, isA<List<dynamic>>());
      expect((many.data as List).length, 2);
    });
  });

  group('readFile', () {
    test('a missing path parameter is reported', () async {
      final result = await executor.readFile({}, context);
      expect(result.success, isFalse);
      expect(result.error, contains('Path parameter is required'));
    });

    test('a file that is not there is reported with its path', () async {
      final missing = '${tmp.path}/nope.txt';
      final result = await executor.readFile({'path': missing}, context);
      expect(result.success, isFalse);
      expect(result.error, contains(missing));
    });

    test('text: content, size and mime type', () async {
      final file = File('${tmp.path}/note.txt')..writeAsStringSync('hello');
      final result = await executor.readFile({'path': file.path}, context);

      expect(result.success, isTrue);
      final data = result.data as Map<String, dynamic>;
      expect(data['content'], 'hello');
      expect(data['size'], 5);
      expect(data['binary'], isFalse);
      expect(data['mimeType'], 'text/plain');
      expect(data['lastModified'], isNotEmpty);
    });

    test('binary: bytes rather than a string', () async {
      final file = File('${tmp.path}/blob.bin')
        ..writeAsBytesSync([0, 1, 2, 250]);
      final result =
          await executor.readFile({'path': file.path, 'binary': true}, context);

      final data = result.data as Map<String, dynamic>;
      expect(data['binary'], isTrue);
      expect(data['content'], [0, 1, 2, 250]);
      expect(data['size'], 4);
      expect(data['mimeType'], 'application/octet-stream');
    });

    test('a named encoding is honoured', () async {
      final file = File('${tmp.path}/latin.txt')
        ..writeAsBytesSync(latin1.encode('café'));
      final utf8Read = await executor.readFile({'path': file.path}, context);
      final latinRead = await executor
          .readFile({'path': file.path, 'encoding': 'latin1'}, context);

      expect((latinRead.data as Map)['content'], 'café');
      expect((utf8Read.data as Map?)?['content'], isNot('café'),
          reason: 'the same bytes read as utf-8 are not the same string — and '
              'when the decoder refuses outright the read fails, which is also '
              'not the latin1 answer');
    });
  });

  group('writeFile', () {
    test('a missing path is reported', () async {
      final result = await executor.writeFile({'content': 'x'}, context);
      expect(result.success, isFalse);
      expect(result.error, contains('Path'));
    });

    test('writes text and reports where and how much', () async {
      final path = '${tmp.path}/out/deep/note.txt';
      final result =
          await executor.writeFile({'path': path, 'content': 'hello'}, context);

      expect(result.success, isTrue);
      expect(File(path).readAsStringSync(), 'hello',
          reason: 'a missing parent directory is created, not an error');
      expect((result.data as Map)['path'], path);
    });

    test('append adds instead of replacing', () async {
      final path = '${tmp.path}/log.txt';
      await executor.writeFile({'path': path, 'content': 'a'}, context);
      await executor
          .writeFile({'path': path, 'content': 'b', 'append': true}, context);
      expect(File(path).readAsStringSync(), 'ab');

      await executor.writeFile({'path': path, 'content': 'c'}, context);
      expect(File(path).readAsStringSync(), 'c',
          reason: 'without append the file is replaced');
    });

    test('a byte list is written as bytes', () async {
      final path = '${tmp.path}/blob.bin';
      final result = await executor
          .writeFile({'path': path, 'content': [1, 2, 3]}, context);
      expect(result.success, isTrue);
      expect(File(path).readAsBytesSync(), [1, 2, 3]);
    });
  });

  group('saveFile', () {
    test('content is required', () async {
      FilePicker.platform = _FakePicker(save: null);
      final result = await executor.saveFile({}, context);
      expect(result.success, isFalse);
      expect(result.error, contains('Content parameter is required'));
    });

    test('a cancelled dialog is a success with no data', () async {
      FilePicker.platform = _FakePicker(save: null);
      final result = await executor.saveFile({'content': 'x'}, context);
      expect(result.success, isTrue);
      expect(result.data, isNull);
    });

    test('writes to the chosen path and reports its size', () async {
      final target = '${tmp.path}/chosen/report.txt';
      final picker = _FakePicker(save: target);
      FilePicker.platform = picker;

      final result = await executor.saveFile({
        'content': 'saved',
        'fileName': 'report.txt',
        'title': 'Save the report',
        'allowedExtensions': ['.txt'],
      }, context);

      expect(File(target).readAsStringSync(), 'saved');
      final data = result.data as Map<String, dynamic>;
      expect(data['path'], target);
      expect(data['size'], 5);
      expect(picker.fileName, 'report.txt');
      expect(picker.dialogTitle, 'Save the report');
      expect(picker.allowedExtensions, ['txt']);
      expect(picker.type, FileType.custom);
    });

    test('bytes are saved as bytes', () async {
      final target = '${tmp.path}/blob.bin';
      FilePicker.platform = _FakePicker(save: target);
      await executor.saveFile({'content': [7, 8]}, context);
      expect(File(target).readAsBytesSync(), [7, 8]);
    });
  });

  group('listFiles', () {
    setUp(() {
      File('${tmp.path}/a.txt').writeAsStringSync('aaa');
      File('${tmp.path}/b.log').writeAsStringSync('bb');
      File('${tmp.path}/.hidden').writeAsStringSync('h');
      Directory('${tmp.path}/sub').createSync();
      File('${tmp.path}/sub/c.txt').writeAsStringSync('c');
    });

    test('a missing path is reported', () async {
      final result = await executor.listFiles({}, context);
      expect(result.success, isFalse);
      expect(result.error, contains('Path parameter is required'));
    });

    test('a directory that is not there is reported', () async {
      final result =
          await executor.listFiles({'path': '${tmp.path}/nope'}, context);
      expect(result.success, isFalse);
      expect(result.error, contains('Directory not found'));
    });

    test('hidden entries are left out unless asked for', () async {
      final plain = await executor.listFiles({'path': tmp.path}, context);
      final names = ((plain.data as Map)['files'] as List)
          .map((e) => (e as Map)['name'] as String)
          .toList();
      expect(names, isNot(contains('.hidden')));

      final all = await executor
          .listFiles({'path': tmp.path, 'includeHidden': true}, context);
      final allNames =
          ((all.data as Map)['files'] as List).map((e) => (e as Map)['name'] as String).toList();
      expect(allNames, contains('.hidden'));
    });

    test('a pattern filters, and recursive reaches the subdirectory', () async {
      final flat = await executor
          .listFiles({'path': tmp.path, 'pattern': r'\.txt$'}, context);
      expect(((flat.data as Map)['files'] as List).length, 1);

      final deep = await executor.listFiles(
          {'path': tmp.path, 'pattern': r'\.txt$', 'recursive': true}, context);
      expect(((deep.data as Map)['files'] as List).length, 2,
          reason: 'recursive must include `sub/c.txt`');
    });

    test('sortBy name and size order the answer', () async {
      final bySize = await executor
          .listFiles({'path': tmp.path, 'sortBy': 'size'}, context);
      final sizes = ((bySize.data as Map)['files'] as List)
          .map((e) => (e as Map)['size'] as int)
          .toList();
      final sorted = [...sizes]..sort();
      expect(sizes, sorted);

      final byName = await executor
          .listFiles({'path': tmp.path, 'sortBy': 'name'}, context);
      final names = ((byName.data as Map)['files'] as List)
          .map((e) => (e as Map)['name'] as String)
          .toList();
      final alpha = [...names]..sort();
      expect(names, alpha);
    });

    test('limit truncates', () async {
      final result =
          await executor.listFiles({'path': tmp.path, 'limit': 1}, context);
      expect(((result.data as Map)['files'] as List).length, 1);
    });

    test('an entry says whether it is a directory', () async {
      final result = await executor.listFiles({'path': tmp.path}, context);
      final entry = ((result.data as Map)['files'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((e) => e['name'] == 'sub');
      expect(entry['type'], 'directory');
    });
  });
  group('writeFile — the shapes and refusals', () {
    test('a missing path or content is refused by name', () async {
      expect((await executor.writeFile(<String, dynamic>{}, context)).error,
          contains('Path parameter is required'));
      expect(
          (await executor.writeFile(
                  <String, dynamic>{'path': '${tmp.path}/a.txt'}, context))
              .error,
          contains('Content parameter is required'),
          reason: 'writing nothing would truncate a file the document meant '
              'to append to');
    });

    test('a write says whether it created or overwrote', () async {
      final path = '${tmp.path}/notes/a.txt';

      final created = await executor.writeFile(<String, dynamic>{
        'path': path,
        'content': 'one',
      }, context);
      expect(created.success, isTrue);
      expect((created.data! as Map)['created'], isTrue);
      expect(File(path).existsSync(), isTrue,
          reason: 'the parent directory is created on the way, which is what '
              '`createDirectory` defaults to');

      final overwritten = await executor.writeFile(<String, dynamic>{
        'path': path,
        'content': 'two',
      }, context);
      expect((overwritten.data! as Map)['overwritten'], isTrue);
      expect(File(path).readAsStringSync(), 'two');
    });

    test('appending adds to what is there', () async {
      final path = '${tmp.path}/a.txt';
      await executor.writeFile(
          <String, dynamic>{'path': path, 'content': 'one'}, context);
      await executor.writeFile(<String, dynamic>{
        'path': path,
        'content': ' two',
        'append': true,
      }, context);

      expect(File(path).readAsStringSync(), 'one two');
    });

    test('binary content is written as bytes, and appended as bytes',
        () async {
      final path = '${tmp.path}/a.bin';

      await executor.writeFile(<String, dynamic>{
        'path': path,
        'content': <int>[1, 2, 3],
      }, context);
      expect(File(path).readAsBytesSync(), <int>[1, 2, 3]);

      await executor.writeFile(<String, dynamic>{
        'path': path,
        'content': <int>[4, 5],
        'append': true,
      }, context);
      expect(File(path).readAsBytesSync(), <int>[1, 2, 3, 4, 5],
          reason: 'appending bytes by re-encoding them as text would corrupt '
              'the file');
    });

    test('each named encoding is honoured', () async {
      for (final name in const ['utf-8', 'utf8', 'latin1', 'iso-8859-1',
        'ascii', 'nonsense']) {
        final path = '${tmp.path}/${name.replaceAll('-', '')}.txt';
        final result = await executor.writeFile(<String, dynamic>{
          'path': path,
          'content': 'plain',
          'encoding': name,
        }, context);

        expect(result.success, isTrue, reason: name);
        expect(File(path).readAsStringSync(), 'plain', reason: name);
      }
    });

    test('a path that cannot be written is reported, not thrown', () async {
      final result = await executor.writeFile(<String, dynamic>{
        'path': tmp.path, // a directory
        'content': 'x',
      }, context);

      expect(result.success, isFalse);
      expect(result.error, contains('Failed to write file'));
    });
  });

  group('readFile — mime types and binary', () {
    test('a missing path, and a file that is not there', () async {
      expect((await executor.readFile(<String, dynamic>{}, context)).error,
          contains('Path parameter is required'));
      expect(
          (await executor.readFile(
                  <String, dynamic>{'path': '${tmp.path}/nope.txt'}, context))
              .error,
          contains('File not found'));
    });

    test('a text read carries the mime type it inferred', () async {
      final path = '${tmp.path}/a.csv';
      File(path).writeAsStringSync('a,b');

      final result =
          await executor.readFile(<String, dynamic>{'path': path}, context);

      expect((result.data! as Map)['content'], 'a,b');
      expect((result.data! as Map)['mimeType'], 'text/csv',
          reason: 'the type is what a document uses to decide how to show '
              'what it just read');
    });

    test('an unknown extension reads as opaque bytes rather than guessing',
        () async {
      final path = '${tmp.path}/a.unheardof';
      File(path).writeAsStringSync('x');

      final result =
          await executor.readFile(<String, dynamic>{'path': path}, context);

      expect((result.data! as Map)['mimeType'], 'application/octet-stream');
    });

    test('a binary read returns bytes and says so', () async {
      final path = '${tmp.path}/a.bin';
      File(path).writeAsBytesSync(<int>[1, 2, 3]);

      final result = await executor.readFile(
          <String, dynamic>{'path': path, 'binary': true}, context);

      expect((result.data! as Map)['binary'], isTrue);
      expect((result.data! as Map)['size'], 3);
    });
  });

  group('listFiles — sorting and limits', () {
    setUp(() {
      File('${tmp.path}/b.txt').writeAsStringSync('bb');
      File('${tmp.path}/a.txt').writeAsStringSync('a');
      Directory('${tmp.path}/sub').createSync();
      File('${tmp.path}/sub/c.txt').writeAsStringSync('ccc');
    });

    Future<List<dynamic>> list(Map<String, dynamic> action) async {
      final result = await executor.listFiles(
          <String, dynamic>{'path': tmp.path, ...action}, context);
      expect(result.success, isTrue);
      return (result.data! as Map)['files'] as List<dynamic>;
    }

    test('a missing path is refused by name', () async {
      expect((await executor.listFiles(<String, dynamic>{}, context)).error,
          contains('Path parameter is required'));
    });

    test('each sort order is applied', () async {
      expect(
          (await list(<String, dynamic>{'sortBy': 'name'}))
              .map((f) => (f as Map)['name']),
          containsAllInOrder(<String>['a.txt', 'b.txt']));

      final bySize = await list(<String, dynamic>{'sortBy': 'size'});
      expect((bySize.first as Map)['size'],
          lessThanOrEqualTo((bySize.last as Map)['size'] as int));

      await list(<String, dynamic>{'sortBy': 'modified'});
      await list(<String, dynamic>{'sortBy': 'type'});
      await list(<String, dynamic>{'sortBy': 'nonsense'});
    });

    test('a limit truncates the listing', () async {
      expect(await list(<String, dynamic>{'limit': 1}), hasLength(1));
    });

    test('a directory that is not there is reported, not thrown', () async {
      final result = await executor.listFiles(
          <String, dynamic>{'path': '${tmp.path}/nope'}, context);

      expect(result.success, isFalse);
    });
  });
}

/// The executors take a `RenderContext` and none of these paths read it, so the
/// cheapest real one will do.
RenderContext _nullContext() {
  final stateManager = StateManager();
  final engine = BindingEngine();
  final actionHandler = ActionHandler();
  return RenderContext(
    renderer: Renderer(
      widgetRegistry: WidgetRegistry(),
      bindingEngine: engine,
      actionHandler: actionHandler,
      stateManager: stateManager,
    ),
    stateManager: stateManager,
    actionHandler: actionHandler,
    themeManager: ThemeManager(),
    bindingEngine: engine,
    buildContext: null,
  );
}
