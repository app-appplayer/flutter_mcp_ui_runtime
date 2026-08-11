// `client.exec` — the executor that starts a process on the user's machine.
//
// It had 0% coverage. Not a line of it had ever run in a test, including the
// argument parser that decides what actually gets executed and the
// `runInShell: false` that is the only thing standing between a document's
// string and a shell interpreting it.
//
// These run real processes. A fake would test the fake, and the properties
// worth checking here — that `;` does not chain, that `$HOME` does not expand,
// that a quoted argument stays one argument — exist precisely at the boundary
// a fake replaces.

@TestOn('mac-os || linux')
library;

import 'dart:io';

import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/client_actions/executors/shell_action_executor.dart';
import 'package:flutter_mcp_ui_runtime/src/platform/host_platform.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ShellActionExecutor executor;
  late RenderContext context;

  setUp(() {
    executor = ShellActionExecutor();
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

  Future<Map<String, dynamic>?> run(Map<String, dynamic> action) async {
    final result = await executor.exec(action, context);
    return result.success ? result.data as Map<String, dynamic> : null;
  }

  group('on the web', () {
    setUp(() => HostPlatform.override(name: 'web'));
    tearDown(HostPlatform.clearOverride);

    test('a shell command is refused by name rather than reported as run',
        () async {
      final result = await executor.exec(
          const {'command': '/bin/echo hello'}, context);

      expect(result.success, isFalse);
      expect(result.error, contains('not supported on web'),
          reason: 'a browser has no shell; answering with an empty success '
              'tells the document its command ran and produced nothing');
    });
  });

  group('a command that runs', () {
    test('its output, exit code and command name come back', () async {
      final data = await run({'command': '/bin/echo hello'});

      expect(data, isNotNull);
      expect(data!['stdout'], 'hello\n');
      expect(data['code'], 0);
      expect(data['success'], isTrue);
      expect(data['stderr'], '');
      expect(data['command'], '/bin/echo hello',
          reason: 'the document gets its own command back, which is what a '
              'log line or an error message is built from');
    });

    test('a non-zero exit is reported in the data, not as a failed action',
        () async {
      // Worth pinning: the ACTION succeeded — the runtime did run the command.
      // The command's own failure is data the document reads. Collapsing the
      // two would leave a document unable to tell "could not run it" from
      // "ran it and it said no".
      final result =
          await executor.exec({'command': '/bin/sh -c "exit 3"'}, context);

      expect(result.success, isTrue);
      final data = result.data as Map<String, dynamic>;
      expect(data['code'], 3);
      expect(data['success'], isFalse);
    });

    test('stderr is captured separately from stdout', () async {
      final data = await run({
        'command': '/bin/sh',
        'args': ['-c', 'echo out; echo err 1>&2'],
      });

      expect(data!['stdout'], contains('out'));
      expect(data['stderr'], contains('err'));
      expect(data['stdout'], isNot(contains('err')),
          reason: 'a document that shows stdout to a user must not have '
              'diagnostics mixed into it');
    });
  });

  group('what the command string is NOT allowed to do', () {
    // `runInShell: false` is a security decision with a comment above it and,
    // until now, nothing testing it. Each of these would be a command
    // injection if the string were handed to a shell.
    test('a semicolon does not chain a second command', () async {
      final marker = Directory.systemTemp
          .createTempSync('shell_probe')
          .uri
          .resolve('created-by-injection')
          .toFilePath();
      addTearDown(() {
        final f = File(marker);
        if (f.existsSync()) f.deleteSync();
      });

      final data = await run({'command': '/bin/echo hi ; touch $marker'});

      expect(data, isNotNull);
      expect(File(marker).existsSync(), isFalse,
          reason: 'the second command must never run — this is the whole '
              'reason for runInShell: false');
      expect(data!['stdout'], contains(';'),
          reason: 'the semicolon arrives as a literal argument to echo');
    });

    test('a variable is not expanded', () async {
      final data = await run({'command': r'/bin/echo $HOME'});
      expect(data!['stdout'].toString().trim(), r'$HOME',
          reason: 'expansion would leak the environment into a document that '
              'only asked to print a string');
    });

    test('a glob is not expanded', () async {
      final data = await run({'command': '/bin/echo *'});
      expect(data!['stdout'].toString().trim(), '*');
    });

    test('a pipe is not a pipe', () async {
      final data = await run({'command': '/bin/echo a | wc -l'});
      expect(data!['stdout'], contains('|'));
    });
  });

  group('how the command is split', () {
    test('double quotes keep a spaced argument together', () async {
      final data = await run({'command': '/bin/echo "one two"'});
      expect(data!['stdout'], 'one two\n');
    });

    test('single quotes do the same', () async {
      final data = await run({'command': "/bin/echo 'one two'"});
      expect(data!['stdout'], 'one two\n');
    });

    test('runs of spaces do not produce empty arguments', () async {
      // `echo a  b` with an empty argument between would print two spaces.
      final data = await run({'command': '/bin/echo a  b'});
      expect(data!['stdout'], 'a b\n');
    });

    test('an explicit args list is passed through verbatim', () async {
      // The safe form: the document says what the arguments ARE rather than
      // writing a string for something to split.
      final data = await run({
        'command': '/bin/echo',
        'args': ['one two', r'$HOME', ';'],
      });
      expect(data!['stdout'], 'one two \$HOME ;\n');
    });

    test('an args list is preferred over anything in the command string',
        () async {
      final data = await run({
        'command': '/bin/echo',
        'args': ['fromArgs'],
      });
      expect(data!['stdout'], 'fromArgs\n');
    });
  });

  group('the working directory', () {
    test('the command runs inside it', () async {
      final dir = Directory.systemTemp.createTempSync('shell_cwd');
      addTearDown(() => dir.deleteSync(recursive: true));

      final data = await run({'command': '/bin/pwd', 'cwd': dir.path});

      expect(data!['stdout'].toString().trim(),
          dir.resolveSymbolicLinksSync(),
          reason: 'a command that ignored cwd would read and write in '
              'whatever directory the host happened to be started from');
    });

    test('`workingDir` is accepted as well as `cwd`', () async {
      final dir = Directory.systemTemp.createTempSync('shell_cwd');
      addTearDown(() => dir.deleteSync(recursive: true));

      final data = await run({'command': '/bin/pwd', 'workingDir': dir.path});
      expect(data!['stdout'].toString().trim(), dir.resolveSymbolicLinksSync());
    });

    test('a directory that does not exist is refused before anything runs',
        () async {
      final result = await executor.exec(
        {'command': '/bin/echo hi', 'cwd': '/no/such/directory'},
        context,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('/no/such/directory'),
          reason: 'naming the path is the difference between a fixable error '
              'and "failed to execute"');
    });
  });

  group('the environment', () {
    test('declared variables reach the process', () async {
      final data = await run({
        'command': '/bin/sh',
        'args': ['-c', r'echo $PROBE_VALUE'],
        'environment': {'PROBE_VALUE': 'from-the-document'},
      });

      expect(data!['stdout'].toString().trim(), 'from-the-document');
    });

    test('non-string values are stringified rather than dropped', () async {
      final data = await run({
        'command': '/bin/sh',
        'args': ['-c', r'echo $PROBE_NUM'],
        'environment': {'PROBE_NUM': 42},
      });
      expect(data!['stdout'].toString().trim(), '42');
    });

    test('an environment that is not a map is ignored, not fatal', () async {
      final data = await run({
        'command': '/bin/echo hi',
        'environment': 'not-a-map',
      });
      expect(data!['stdout'], 'hi\n');
    });
  });

  group('what cannot be run', () {
    test('no command at all is refused by name', () async {
      final result = await executor.exec(<String, dynamic>{}, context);
      expect(result.success, isFalse);
      expect(result.error, contains('Command'));
    });

    test('an empty command is refused', () async {
      final result = await executor.exec({'command': ''}, context);
      expect(result.success, isFalse);
      expect(result.error, contains('Command'));
    });

    test('a command of nothing but spaces is refused as malformed', () async {
      final result = await executor.exec({'command': '   '}, context);
      expect(result.success, isFalse);
      expect(result.error, contains('Invalid command format'),
          reason: 'this is the branch where the parser produced no parts — '
              'starting a process with an empty executable would be worse');
    });

    test('an executable that is not there is reported, not thrown', () async {
      final result =
          await executor.exec({'command': '/no/such/binary'}, context);
      expect(result.success, isFalse);
      expect(result.error, contains('Failed to execute'));
    });

    test('a command that runs too long is killed and reported', () async {
      final started = DateTime.now();
      final result = await executor.exec(
        {'command': '/bin/sleep 30', 'timeout': 300},
        context,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('timed out'));
      expect(DateTime.now().difference(started).inSeconds, lessThan(10),
          reason: 'the timeout has to actually kill the process — a document '
              'that waited out the full 30 seconds would look frozen');
    });
  });
}
