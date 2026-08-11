// The parts of the binding engine no test had asked about.
//
// The engine was at 80% covered while four defects shipped out of it, so the
// number was never the point — but the uncovered lines turned out to hold the
// same kind of thing the consumers found: conversions that answer a wrong type
// quietly, method spellings that exist beside the function spellings, and
// namespace resolvers that answer null when nothing is wired.
//
// Each test here names the behaviour it pins rather than the line it covers.

import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late BindingEngine engine;
  late RenderContext context;

  RenderContext contextWith(Map<String, dynamic> state) {
    final stateManager = StateManager()..initialize(Map.of(state));
    engine = BindingEngine();
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

  setUp(() {
    context = contextWith({
      'count': 3,
      'ratio': 0.5,
      'flag': true,
      'name': 'Ada',
      'numeric': '42',
      'decimal': '2.5',
      'notANumber': 'abc',
      'rows': [
        {'label': 'a', 'v': 3, 'ok': true, 'status': 'done'},
        {'label': 'b', 'v': 4, 'ok': false, 'status': 'open'},
        {'label': 'c', 'v': 5, 'ok': true, 'status': 'done'},
      ],
      'numbers': [1, 2, 3],
      'empty': <dynamic>[],
    });
  });

  group('the resolvers are reachable from outside', () {
    test('each namespace resolver is exposed for a host to configure', () {
      // A host wires permissions and channels into these; a private field with
      // no accessor would leave the namespaces permanently empty.
      expect(engine.permissionBindingResolver, isNotNull);
      expect(engine.channelBindingResolver, isNotNull);
      expect(engine.clientBindingResolver, isNotNull);
      expect(engine.resourceBindingResolver, isNotNull);
      expect(engine.syncBindingResolver, isNotNull);
    });

    test('an unwired namespace answers null rather than throwing', () {
      // §3.4: "If no scope matches, the expression evaluates to null". A
      // document that reads a namespace the host never wired must render, not
      // crash — this is the one that decides whether a bundle opens at all on
      // a host with fewer capabilities.
      for (final path in [
        '{{permissions.camera.capture}}',
        '{{channels.telemetry.active}}',
        '{{resources.report.data}}',
        '{{sync.status}}',
        '{{client.platform}}',
      ]) {
        expect(() => context.resolve<dynamic>(path), returnsNormally,
            reason: '$path must not throw on an unwired host');
      }
    });
  });

  group('type conversion', () {
    test('a numeric string reaches a number slot', () {
      expect(context.resolve<int>('{{numeric}}'), 42);
      expect(context.resolve<double>('{{decimal}}'), 2.5);
    });

    test('an int reaches a double slot and back', () {
      expect(context.resolve<double>('{{count}}'), 3.0);
      expect(context.resolve<int>('{{ratio}}'), 0,
          reason: '0.5 truncates rather than rounding — pinned, not endorsed');
    });

    test('a string that is not a number answers the type default, not a throw',
        () {
      // A wrong-typed binding is an authoring mistake. Answering 0 keeps the
      // screen up; throwing takes the page down, which is what the tolerant
      // readers were introduced to stop.
      expect(context.resolve<int>('{{notANumber}}'), 0);
      expect(context.resolve<double>('{{notANumber}}'), 0.0);
      expect(context.resolve<int?>('{{notANumber}}'), isNull,
          reason: 'a nullable slot gets null instead of a made-up zero');
    });

    test('anything reaches a String slot', () {
      expect(context.resolve<String>('{{count}}'), '3');
      expect(context.resolve<String>('{{flag}}'), 'true');
    });

    test('a string or an int reaches a bool slot', () {
      final ctx = contextWith({'yes': 'true', 'no': 'False', 'one': 1, 'zero': 0});
      expect(ctx.resolve<bool>('{{yes}}'), isTrue);
      expect(ctx.resolve<bool>('{{no}}'), isFalse);
      expect(ctx.resolve<bool>('{{one}}'), isTrue);
      expect(ctx.resolve<bool>('{{zero}}'), isFalse);
    });

    test('a missing path fills a non-nullable slot with its zero', () {
      expect(context.resolve<String>('{{nothing}}'), '');
      expect(context.resolve<int>('{{nothing}}'), 0);
      expect(context.resolve<double>('{{nothing}}'), 0.0);
      expect(context.resolve<bool>('{{nothing}}'), isFalse);
    });
  });

  group('method spellings sit beside the function spellings', () {
    test('filter by property, by property/value, and by config object', () {
      expect((context.resolve<List<dynamic>>("{{rows.filter('ok')}}")).length, 2,
          reason: "the truthy shorthand, in the method spelling");
      expect(
        (context.resolve<List<dynamic>>("{{rows.filter('status', 'open')}}"))
            .length,
        1,
      );
      // The object shorthand (`filter({property: …, value: …})`) exists in the
      // runtime's own code but NOT in §3.6.2, and the argument parser tracks
      // parentheses rather than braces, so the literal never arrives as a map.
      // Left unasserted deliberately: pinning an unspecified form would freeze
      // whichever answer it happens to give.
    });

    test('reduce by lambda, by property, and over bare numbers', () {
      expect(context.resolve<dynamic>('{{rows.reduce(r => r.v)}}'), 12);
      expect(context.resolve<dynamic>("{{rows.reduce('v')}}"), 12,
          reason: 'property reduction sums that property');
      expect(context.resolve<dynamic>('{{numbers.reduce()}}'), 6,
          reason: 'no argument sums the numbers themselves');
    });

    test('a method the engine does not know answers null', () {
      expect(context.resolve<dynamic>('{{rows.somersault()}}'), isNull);
    });

    test('length, isEmpty and first read a list', () {
      expect(context.resolve<dynamic>('{{rows.length}}'), 3);
      expect(context.resolve<dynamic>('{{empty.isEmpty}}'), isTrue);
      expect(context.resolve<dynamic>('{{rows.isNotEmpty}}'), isTrue);
      expect((context.resolve<dynamic>('{{rows.first}}') as Map)['label'], 'a');
      expect((context.resolve<dynamic>('{{rows.last}}') as Map)['label'], 'c');
    });

    test('first and last on an empty list are null, not an exception', () {
      expect(context.resolve<dynamic>('{{empty.first}}'), isNull);
      expect(context.resolve<dynamic>('{{empty.last}}'), isNull);
    });
  });

  group('string methods', () {
    test('case, trim, contains, substring', () {
      final ctx = contextWith({'text': '  Hello World  '});
      expect(ctx.resolve<dynamic>('{{text.trim()}}'), 'Hello World');
      expect(ctx.resolve<dynamic>('{{name.toUpperCase()}}'), isNull,
          reason: 'a path that is not in this state answers null');
    });

    test('the same operations on a real string', () {
      final ctx = contextWith({'text': 'Hello World'});
      expect(ctx.resolve<dynamic>('{{text.toUpperCase()}}'), 'HELLO WORLD');
      expect(ctx.resolve<dynamic>('{{text.toLowerCase()}}'), 'hello world');
      expect(ctx.resolve<dynamic>("{{text.contains('World')}}"), isTrue);
      expect(ctx.resolve<dynamic>('{{text.substring(0, 5)}}'), 'Hello');
      expect(ctx.resolve<dynamic>('{{text.substring(6)}}'), 'World');
      expect(ctx.resolve<dynamic>('{{text.length}}'), 11);
    });

    test('toStringAsFixed on a number', () {
      final ctx = contextWith({'price': 12.345});
      expect(ctx.resolve<dynamic>('{{price.toStringAsFixed(2)}}'), '12.35');
      expect(ctx.resolve<dynamic>('{{price.toString()}}'), '12.345');
    });
  });

  group('transforms', () {
    test('the registered ones shape a resolved value', () {
      final ctx = contextWith({'name': 'ada', 'n': 2.7, 'when': '2026-08-08T09:05:00Z'});
      expect(ctx.resolve<dynamic>('{{name | uppercase}}'), 'ADA');
      expect(ctx.resolve<dynamic>('{{name | capitalize}}'), 'Ada');
      expect(ctx.resolve<dynamic>('{{n | round}}'), 3);
      expect(ctx.resolve<dynamic>('{{n | floor}}'), 2);
      expect(ctx.resolve<dynamic>('{{n | ceil}}'), 3);
      expect(ctx.resolve<dynamic>('{{when | date}}'), '2026-08-08');
    });

    test('a host can register its own', () {
      final ctx = contextWith({'name': 'ada'});
      engine.registerTransform('shout', (value) => '${value}!');
      expect(ctx.resolve<dynamic>('{{name | shout}}'), 'ada!');
    });
  });

  group('the sandbox bounds an aggregate', () {
    test('a list longer than maxIterations is capped, not walked', () {
      final ctx = contextWith({
        'many': [for (var i = 0; i < 50; i++) i],
      });
      engine.sandbox = const ExpressionSandbox(maxIterations: 10);
      expect(ctx.resolve<dynamic>('{{many.reduce()}}'), 45,
          reason: 'the first 10 (0..9) sum to 45; the rest are not read');
    });

    test('a sandbox can be built from a document block', () {
      final sandbox = ExpressionSandbox.fromJson({
        'timeout': 50,
        'maxDepth': 4,
        'maxIterations': 7,
        'maxMemoryBytes': 128,
      });
      expect(sandbox.timeout, 50);
      expect(sandbox.maxDepth, 4);
      expect(sandbox.maxIterations, 7);
      expect(sandbox.maxMemoryBytes, 128);

      final defaults = ExpressionSandbox.fromJson(const {});
      expect(defaults.timeout, 1000);
      expect(defaults.maxIterations, 10000);
    });
  });
}
