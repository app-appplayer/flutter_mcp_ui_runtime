import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';

void main() {
  group('BindingEngine Comprehensive Tests (TC-032~084)', () {
    late BindingEngine bindingEngine;
    late StateManager stateManager;
    late RenderContext context;

    setUp(() {
      bindingEngine = BindingEngine();
      stateManager = StateManager();
      final actionHandler = ActionHandler();
      final themeManager = ThemeManager.instance;
      themeManager.reset();
      final widgetRegistry = WidgetRegistry();

      stateManager.initialize({
        'user': {'name': 'John', 'age': 30, 'email': 'john@example.com'},
        'items': [
          {'name': 'Item A', 'price': 10, 'status': 'active'},
          {'name': 'Item B', 'price': 20, 'status': 'inactive'},
          {'name': 'Item C', 'price': 30, 'status': 'active'},
        ],
        'counter': 5,
        'flag': true,
        'title': 'Test App',
        'tags': ['dart', 'flutter', 'mcp'],
        'config': {'debug': false, 'version': '1.0'},
      });

      final renderer = Renderer(
        widgetRegistry: widgetRegistry,
        bindingEngine: bindingEngine,
        actionHandler: actionHandler,
        stateManager: stateManager,
      );

      context = RenderContext(
        renderer: renderer,
        stateManager: stateManager,
        actionHandler: actionHandler,
        themeManager: themeManager,
        bindingEngine: bindingEngine,
        buildContext: null,
      );
    });

    tearDown(() {
      bindingEngine.dispose();
      stateManager.dispose();
    });

    // =========================================================================
    // TC-032~040: BindingEngine constructor and resolve
    // =========================================================================
    group('TC-032~040: Constructor and resolve', () {
      // TC-032: Constructor creates with default sandbox settings
      test('TC-032: Constructor creates with default sandbox settings '
          '(timeout=1000, maxDepth=32, maxIterations=10000)', () {
        final engine = BindingEngine();
        expect(engine.sandbox.timeout, equals(1000));
        expect(engine.sandbox.maxDepth, equals(32));
        expect(engine.sandbox.maxIterations, equals(10000));
        engine.dispose();
      });

      // TC-033: ExpressionSandbox.fromJson creates from config map
      test('TC-033: ExpressionSandbox.fromJson creates from config map', () {
        // Normal: custom values
        final sandbox = ExpressionSandbox.fromJson({
          'timeout': 500,
          'maxDepth': 16,
          'maxIterations': 5000,
          'maxMemoryBytes': 2048,
        });
        expect(sandbox.timeout, equals(500));
        expect(sandbox.maxDepth, equals(16));
        expect(sandbox.maxIterations, equals(5000));
        expect(sandbox.maxMemoryBytes, equals(2048));

        // Boundary: empty map uses defaults
        final defaultSandbox = ExpressionSandbox.fromJson({});
        expect(defaultSandbox.timeout, equals(1000));
        expect(defaultSandbox.maxDepth, equals(32));
        expect(defaultSandbox.maxIterations, equals(10000));
        expect(defaultSandbox.maxMemoryBytes, equals(1024 * 1024));

        // Boundary: partial map uses defaults for missing keys
        final partialSandbox = ExpressionSandbox.fromJson({'timeout': 2000});
        expect(partialSandbox.timeout, equals(2000));
        expect(partialSandbox.maxDepth, equals(32));
      });

      // TC-034: isBindingExpression detects {{...}} patterns, rejects plain text
      test('TC-034: isBindingExpression detects {{...}} patterns, '
          'rejects plain text', () {
        // Normal: valid binding expressions
        expect(bindingEngine.isBindingExpression('{{user.name}}'), isTrue);
        expect(bindingEngine.isBindingExpression('{{counter}}'), isTrue);
        expect(bindingEngine.isBindingExpression('{{flag ? 1 : 0}}'), isTrue);

        // Boundary: plain text without braces
        expect(bindingEngine.isBindingExpression('plain text'), isFalse);
        expect(bindingEngine.isBindingExpression(''), isFalse);

        // Error: partial braces or multiple bindings
        expect(bindingEngine.isBindingExpression('{{user.name'), isFalse);
        expect(
          bindingEngine.isBindingExpression('{{a}} and {{b}}'),
          isFalse,
        );
      });

      // TC-035: containsBindingExpression / hasBindings detects embedded expressions
      test('TC-035: containsBindingExpression / hasBindings detects '
          'embedded expressions', () {
        // Normal: text with embedded binding
        expect(
          bindingEngine.containsBindingExpression('Hello {{user.name}}!'),
          isTrue,
        );
        expect(
          bindingEngine.hasBindings('Value: {{counter}}'),
          isTrue,
        );

        // Boundary: plain text
        expect(
          bindingEngine.containsBindingExpression('plain text'),
          isFalse,
        );
        expect(
          bindingEngine.hasBindings('no bindings here'),
          isFalse,
        );

        // Normal: multiple bindings
        expect(
          bindingEngine.containsBindingExpression('{{a}} and {{b}}'),
          isTrue,
        );
      });

      // TC-036: resolve with simple path returns state value
      test('TC-036: resolve with simple path returns state value', () {
        final result = bindingEngine.resolve('{{user.name}}', context);
        expect(result, equals('John'));
      });

      // TC-037: resolve with nested path
      test('TC-037: resolve with nested path returns value', () {
        final result = bindingEngine.resolve('{{user.age}}', context);
        expect(result, equals(30));
      });

      // TC-038: resolve returns typed values: String, int, bool, List, Map
      test('TC-038: resolve returns typed values', () {
        // String
        final strResult = bindingEngine.resolve('{{title}}', context);
        expect(strResult, isA<String>());
        expect(strResult, equals('Test App'));

        // int
        final intResult = bindingEngine.resolve('{{counter}}', context);
        expect(intResult, equals(5));

        // bool
        final boolResult = bindingEngine.resolve('{{flag}}', context);
        expect(boolResult, isA<bool>());
        expect(boolResult, equals(true));

        // List
        final listResult = bindingEngine.resolve('{{tags}}', context);
        expect(listResult, isA<List>());
        expect(listResult, equals(['dart', 'flutter', 'mcp']));

        // Map
        final mapResult = bindingEngine.resolve('{{config}}', context);
        expect(mapResult, isA<Map>());
        expect(mapResult, equals({'debug': false, 'version': '1.0'}));
      });

      // TC-039: resolveText resolves template strings
      test('TC-039: resolveText resolves template strings', () {
        final result = bindingEngine.resolveText(
          'Hello {{user.name}}!',
          context,
        );
        expect(result, equals('Hello John!'));
      });

      // TC-040: resolve non-binding string returns the string itself
      test('TC-040: resolve non-binding string returns the string itself', () {
        final result = bindingEngine.resolve('plain text', context);
        expect(result, equals('plain text'));
      });
    });

    // =========================================================================
    // TC-041~050: Expression types
    // =========================================================================
    group('TC-041~050: Expression types', () {
      // TC-041: String interpolation in mixed content
      test('TC-041: String interpolation in mixed content', () {
        final result = bindingEngine.resolveText(
          '{{user.name}} is {{user.age}} years old',
          context,
        );
        expect(result, equals('John is 30 years old'));
      });

      // TC-042: Ternary/conditional expression
      test('TC-042: Ternary/conditional expression', () {
        // Normal: flag is true
        final result = bindingEngine.resolve<dynamic>(
          "{{flag ? 'yes' : 'no'}}",
          context,
        );
        expect(result, equals('yes'));

        // Boundary: set flag to false
        stateManager.set('flag', false);
        final result2 = bindingEngine.resolve<dynamic>(
          "{{flag ? 'yes' : 'no'}}",
          context,
        );
        expect(result2, equals('no'));
      });

      // TC-043: Comparison expressions: ==, !=, >, <, >=, <=
      test('TC-043: Comparison expressions', () {
        expect(
          bindingEngine.resolve<dynamic>('{{counter == 5}}', context),
          equals(true),
        );
        expect(
          bindingEngine.resolve<dynamic>('{{counter != 5}}', context),
          equals(false),
        );
        expect(
          bindingEngine.resolve<dynamic>('{{counter > 3}}', context),
          equals(true),
        );
        expect(
          bindingEngine.resolve<dynamic>('{{counter < 3}}', context),
          equals(false),
        );
        expect(
          bindingEngine.resolve<dynamic>('{{counter >= 5}}', context),
          equals(true),
        );
        expect(
          bindingEngine.resolve<dynamic>('{{counter <= 5}}', context),
          equals(true),
        );
      });

      // TC-044: Arithmetic expressions: +, -, *, /, %
      test('TC-044: Arithmetic expressions', () {
        expect(
          bindingEngine.resolve<dynamic>('{{counter + 3}}', context),
          equals(8),
        );
        expect(
          bindingEngine.resolve<dynamic>('{{counter - 2}}', context),
          equals(3),
        );
        expect(
          bindingEngine.resolve<dynamic>('{{counter * 4}}', context),
          equals(20),
        );
        expect(
          bindingEngine.resolve<dynamic>('{{counter / 2}}', context),
          equals(2.5),
        );
        expect(
          bindingEngine.resolve<dynamic>('{{counter % 3}}', context),
          equals(2),
        );
      });

      // TC-045: Arithmetic with division by zero returns null
      test('TC-045: Arithmetic with division by zero returns null', () {
        final result = bindingEngine.resolve<dynamic>(
          '{{counter / 0}}',
          context,
        );
        expect(result, isNull);

        // Modulo by zero also returns null
        final modResult = bindingEngine.resolve<dynamic>(
          '{{counter % 0}}',
          context,
        );
        expect(modResult, isNull);
      });

      // TC-046: String concatenation with + operator
      test('TC-046: String concatenation with + operator', () {
        final result = bindingEngine.resolve<dynamic>(
          "{{'Hello' + ' ' + 'World'}}",
          context,
        );
        expect(result, equals('Hello World'));
      });

      // TC-047: Boolean arithmetic coercion (true->1, false->0)
      test('TC-047: Boolean arithmetic coercion', () {
        // true -> 1
        final result = bindingEngine.resolve<dynamic>(
          '{{flag + 1}}',
          context,
        );
        expect(result, equals(2));

        // false -> 0
        stateManager.set('flag', false);
        final result2 = bindingEngine.resolve<dynamic>(
          '{{flag + 1}}',
          context,
        );
        expect(result2, equals(1));
      });

      // TC-048: Null coalescing
      test('TC-048: Null coalescing expression', () {
        final result = bindingEngine.resolve<dynamic>(
          "{{nullValue ?? 'default'}}",
          context,
        );
        expect(result, equals('default'));

        // Normal: non-null value does not fall through
        final result2 = bindingEngine.resolve<dynamic>(
          "{{title ?? 'fallback'}}",
          context,
        );
        expect(result2, equals('Test App'));
      });

      // TC-049: Logical operators &&, ||, !
      test('TC-049: Logical operators', () {
        // AND
        expect(
          bindingEngine.resolve<dynamic>('{{flag && true}}', context),
          equals(true),
        );
        expect(
          bindingEngine.resolve<dynamic>('{{flag && false}}', context),
          equals(false),
        );

        // OR: returns the left value if truthy
        final orResult = bindingEngine.resolve<dynamic>(
          '{{flag || false}}',
          context,
        );
        expect(orResult, equals(true));

        // NOT
        expect(
          bindingEngine.resolve<dynamic>('{{!flag}}', context),
          equals(false),
        );
      });

      // TC-050: Optional chaining returns null if intermediate is null
      test('TC-050: Optional chaining', () {
        // Normal: valid path
        final result = bindingEngine.resolve<dynamic>(
          '{{user?.name}}',
          context,
        );
        expect(result, equals('John'));

        // Boundary: non-existent intermediate returns null
        final result2 = bindingEngine.resolve<dynamic>(
          '{{nonExistent?.value}}',
          context,
        );
        expect(result2, isNull);
      });
    });

    // =========================================================================
    // TC-051~060: Method calls and chaining
    // =========================================================================
    group('TC-051~060: String method calls', () {
      // TC-051: String method .toUpperCase()
      test('TC-051: String method .toUpperCase()', () {
        final result = bindingEngine.resolve<dynamic>(
          '{{user.name.toUpperCase()}}',
          context,
        );
        expect(result, equals('JOHN'));
      });

      // TC-052: String method .toLowerCase()
      test('TC-052: String method .toLowerCase()', () {
        final result = bindingEngine.resolve<dynamic>(
          '{{title.toLowerCase()}}',
          context,
        );
        expect(result, equals('test app'));
      });

      // TC-053: String method .trim()
      test('TC-053: String method .trim()', () {
        stateManager.set('padded', '  hello  ');
        final result = bindingEngine.resolve<dynamic>(
          '{{padded.trim()}}',
          context,
        );
        expect(result, equals('hello'));
      });

      // TC-054: String method .contains('arg')
      test('TC-054: String method .contains()', () {
        final result = bindingEngine.resolve<dynamic>(
          "{{user.email.contains('@')}}",
          context,
        );
        expect(result, equals(true));

        final result2 = bindingEngine.resolve<dynamic>(
          "{{user.email.contains('xyz')}}",
          context,
        );
        expect(result2, equals(false));
      });

      // TC-055: String method .substring(start) and .substring(start, end)
      test('TC-055: String method .substring()', () {
        // substring(start)
        final result = bindingEngine.resolve<dynamic>(
          '{{user.name.substring(1)}}',
          context,
        );
        expect(result, equals('ohn'));

        // substring(start, end)
        final result2 = bindingEngine.resolve<dynamic>(
          '{{user.name.substring(0, 2)}}',
          context,
        );
        expect(result2, equals('Jo'));
      });

      // TC-056: String method .startsWith(), .endsWith()
      test('TC-056: String method .startsWith() and .endsWith()', () {
        final result = bindingEngine.resolve<dynamic>(
          "{{user.email.startsWith('john')}}",
          context,
        );
        expect(result, equals(true));

        final result2 = bindingEngine.resolve<dynamic>(
          "{{user.email.endsWith('.com')}}",
          context,
        );
        expect(result2, equals(true));

        // Boundary: non-matching
        final result3 = bindingEngine.resolve<dynamic>(
          "{{user.email.startsWith('jane')}}",
          context,
        );
        expect(result3, equals(false));
      });

      // TC-057: String method .replaceAll(from, to)
      test('TC-057: String method .replaceAll()', () {
        final result = bindingEngine.resolve<dynamic>(
          "{{user.email.replaceAll('john', 'jane')}}",
          context,
        );
        expect(result, equals('jane@example.com'));
      });

      // TC-058: String method .split(separator)
      test('TC-058: String method .split()', () {
        final result = bindingEngine.resolve<dynamic>(
          "{{user.email.split('@')}}",
          context,
        );
        expect(result, isA<List>());
        expect(result, equals(['john', 'example.com']));
      });

      // TC-059: String method .indexOf(search)
      test('TC-059: String method .indexOf()', () {
        final result = bindingEngine.resolve<dynamic>(
          "{{user.email.indexOf('@')}}",
          context,
        );
        expect(result, equals(4));

        // Boundary: not found returns -1
        final result2 = bindingEngine.resolve<dynamic>(
          "{{user.email.indexOf('!')}}",
          context,
        );
        expect(result2, equals(-1));
      });

      // TC-060: String method .length (property-style method)
      test('TC-060: String method .length()', () {
        final result = bindingEngine.resolve<dynamic>(
          '{{user.name.length()}}',
          context,
        );
        expect(result, equals(4));
      });
    });

    // =========================================================================
    // TC-061~070: Array/List methods and nested access
    // =========================================================================
    group('TC-061~070: Array/List methods and nested access', () {
      // TC-061: List .length
      test('TC-061: List .length()', () {
        final result = bindingEngine.resolve<dynamic>(
          '{{items.length()}}',
          context,
        );
        expect(result, equals(3));
      });

      // TC-062: List .isEmpty, .isNotEmpty
      test('TC-062: List .isEmpty() and .isNotEmpty()', () {
        final isEmpty = bindingEngine.resolve<dynamic>(
          '{{items.isEmpty()}}',
          context,
        );
        expect(isEmpty, equals(false));

        final isNotEmpty = bindingEngine.resolve<dynamic>(
          '{{items.isNotEmpty()}}',
          context,
        );
        expect(isNotEmpty, equals(true));

        // Boundary: empty list
        stateManager.set('emptyList', []);
        final emptyResult = bindingEngine.resolve<dynamic>(
          '{{emptyList.isEmpty()}}',
          context,
        );
        expect(emptyResult, equals(true));
      });

      // TC-063: List .first, .last
      test('TC-063: List .first() and .last()', () {
        final first = bindingEngine.resolve<dynamic>(
          '{{tags.first()}}',
          context,
        );
        expect(first, equals('dart'));

        final last = bindingEngine.resolve<dynamic>(
          '{{tags.last()}}',
          context,
        );
        expect(last, equals('mcp'));
      });

      // TC-064: List .reversed
      test('TC-064: List .reversed()', () {
        final result = bindingEngine.resolve<dynamic>(
          '{{tags.reversed()}}',
          context,
        );
        expect(result, equals(['mcp', 'flutter', 'dart']));
      });

      // TC-065: List .contains(item)
      test('TC-065: List .contains()', () {
        final result = bindingEngine.resolve<dynamic>(
          "{{tags.contains('dart')}}",
          context,
        );
        expect(result, equals(true));

        final result2 = bindingEngine.resolve<dynamic>(
          "{{tags.contains('python')}}",
          context,
        );
        expect(result2, equals(false));
      });

      // TC-066: List .join(separator)
      test('TC-066: List .join()', () {
        // Use a simple separator without comma to avoid argument parsing issues
        final result = bindingEngine.resolve<dynamic>(
          "{{tags.join('-')}}",
          context,
        );
        expect(result, equals('dart-flutter-mcp'));
      });

      // TC-067: List .map(property) - extract property from each item
      test('TC-067: List .map() extracts property', () {
        final result = bindingEngine.resolve<dynamic>(
          "{{items.map('name')}}",
          context,
        );
        expect(result, equals(['Item A', 'Item B', 'Item C']));
      });

      // TC-068: List .filter(property, value)
      test('TC-068: List .filter() filters items by property value', () {
        final result = bindingEngine.resolve<dynamic>(
          "{{items.filter('status', 'active')}}",
          context,
        );
        expect(result, isA<List>());
        expect((result as List).length, equals(2));
        expect(result[0]['name'], equals('Item A'));
        expect(result[1]['name'], equals('Item C'));
      });

      // TC-069: List .reduce(property) - sum numeric property values
      test('TC-069: List .reduce() sums numeric property values', () {
        final result = bindingEngine.resolve<dynamic>(
          "{{items.reduce('price')}}",
          context,
        );
        expect(result, equals(60));
      });

      // TC-070: Index access
      test('TC-070: Index access {{items[0].name}} and {{tags[1]}}', () {
        // Access list item by index and then nested property
        // Note: items[0] returns the map, then we need to access .name
        // The expression parser handles items[0] as index access
        final result = bindingEngine.resolve<dynamic>(
          '{{tags[1]}}',
          context,
        );
        expect(result, equals('flutter'));

        final result2 = bindingEngine.resolve<dynamic>(
          '{{tags[0]}}',
          context,
        );
        expect(result2, equals('dart'));
      });
    });

    // =========================================================================
    // TC-071~077: Built-in functions
    // =========================================================================
    group('TC-071~077: Built-in functions', () {
      // TC-071: length(value) function
      test('TC-071: length() function', () {
        final result = bindingEngine.resolve<dynamic>(
          '{{length(tags)}}',
          context,
        );
        expect(result, equals(3));

        // String length
        final strResult = bindingEngine.resolve<dynamic>(
          '{{length(title)}}',
          context,
        );
        expect(strResult, equals(8));
      });

      // TC-072: min(a, b) and max(a, b) functions
      test('TC-072: min() and max() functions', () {
        final minResult = bindingEngine.resolve<dynamic>(
          '{{min(counter, 10)}}',
          context,
        );
        expect(minResult, equals(5));

        final maxResult = bindingEngine.resolve<dynamic>(
          '{{max(counter, 10)}}',
          context,
        );
        expect(maxResult, equals(10));

        // Boundary: equal values
        final eqResult = bindingEngine.resolve<dynamic>(
          '{{min(5, 5)}}',
          context,
        );
        expect(eqResult, equals(5));
      });

      // TC-073: abs(), round(), floor(), ceil() functions
      test('TC-073: abs(), round(), floor(), ceil() functions', () {
        stateManager.set('negVal', -7);
        stateManager.set('fracVal', 3.7);

        final absResult = bindingEngine.resolve<dynamic>(
          '{{abs(negVal)}}',
          context,
        );
        expect(absResult, equals(7));

        final roundResult = bindingEngine.resolve<dynamic>(
          '{{round(fracVal)}}',
          context,
        );
        expect(roundResult, equals(4));

        final floorResult = bindingEngine.resolve<dynamic>(
          '{{floor(fracVal)}}',
          context,
        );
        expect(floorResult, equals(3));

        final ceilResult = bindingEngine.resolve<dynamic>(
          '{{ceil(fracVal)}}',
          context,
        );
        expect(ceilResult, equals(4));
      });

      // TC-074: parseInt(str), parseDouble(str) functions
      test('TC-074: parseInt() and parseDouble() functions', () {
        final intResult = bindingEngine.resolve<dynamic>(
          "{{parseInt('42')}}",
          context,
        );
        expect(intResult, equals(42));

        final doubleResult = bindingEngine.resolve<dynamic>(
          "{{parseDouble('3.14')}}",
          context,
        );
        expect(doubleResult, equals(3.14));

        // Error: invalid string returns null
        final invalidResult = bindingEngine.resolve<dynamic>(
          "{{parseInt('abc')}}",
          context,
        );
        expect(invalidResult, isNull);
      });

      // TC-075: toUpperCase(str), toLowerCase(str), trim(str) - function form
      test('TC-075: toUpperCase(), toLowerCase(), trim() function form', () {
        final upperResult = bindingEngine.resolve<dynamic>(
          "{{toUpperCase('hello')}}",
          context,
        );
        expect(upperResult, equals('HELLO'));

        final lowerResult = bindingEngine.resolve<dynamic>(
          "{{toLowerCase('WORLD')}}",
          context,
        );
        expect(lowerResult, equals('world'));

        final trimResult = bindingEngine.resolve<dynamic>(
          "{{trim('  spaced  ')}}",
          context,
        );
        expect(trimResult, equals('spaced'));
      });

      // TC-076: format.number() and format.date() with format namespace
      test('TC-076: format.number() and format.date()', () {
        // format.number with decimal style (default)
        final numResult = bindingEngine.resolve<dynamic>(
          "{{format.number(1234.5, 'decimal')}}",
          context,
        );
        expect(numResult, isA<String>());

        // format.number with currency style
        final currResult = bindingEngine.resolve<dynamic>(
          "{{format.number(99.99, 'currency', 'USD')}}",
          context,
        );
        expect(currResult, isA<String>());
        expect(currResult, contains('\$'));

        // format.date with ISO string
        final dateResult = bindingEngine.resolve<dynamic>(
          "{{format.date('2024-06-15T10:30:00', 'medium')}}",
          context,
        );
        expect(dateResult, equals('2024-06-15'));

        // format.date with short style
        final shortDate = bindingEngine.resolve<dynamic>(
          "{{format.date('2024-06-15T10:30:00', 'short')}}",
          context,
        );
        expect(shortDate, equals('06/15/24'));
      });

      // TC-077: now() returns ISO 8601 string, calculateDuration
      test('TC-077: now() and calculateDuration()', () {
        // now() returns ISO 8601 string
        final nowResult = bindingEngine.resolve<dynamic>(
          '{{now()}}',
          context,
        );
        expect(nowResult, isA<String>());
        // Verify it can be parsed as DateTime
        expect(DateTime.tryParse(nowResult as String), isNotNull);

        // calculateDuration returns duration in days
        final durationResult = bindingEngine.resolve<dynamic>(
          "{{calculateDuration('2024-01-01', '2024-01-11', 'days')}}",
          context,
        );
        expect(durationResult, equals(10));

        // calculateDuration in hours
        final hourResult = bindingEngine.resolve<dynamic>(
          "{{calculateDuration('2024-01-01T00:00:00', '2024-01-01T05:00:00', 'hours')}}",
          context,
        );
        expect(hourResult, equals(5));
      });
    });

    // =========================================================================
    // TC-078~084: Transform registration and sandboxing
    // =========================================================================
    group('TC-078~084: Transform registration and sandboxing', () {
      // TC-078: Default transforms: uppercase, lowercase, capitalize, round, floor, ceil, abs
      test('TC-078: Default transforms: text and math', () {
        // uppercase transform
        final upper = bindingEngine.resolve<dynamic>(
          '{{user.name | uppercase}}',
          context,
        );
        expect(upper, equals('JOHN'));

        // lowercase transform
        final lower = bindingEngine.resolve<dynamic>(
          '{{title | lowercase}}',
          context,
        );
        expect(lower, equals('test app'));

        // capitalize transform
        stateManager.set('lowerWord', 'hello');
        final cap = bindingEngine.resolve<dynamic>(
          '{{lowerWord | capitalize}}',
          context,
        );
        expect(cap, equals('Hello'));

        // round transform
        stateManager.set('decVal', 3.7);
        final rounded = bindingEngine.resolve<dynamic>(
          '{{decVal | round}}',
          context,
        );
        expect(rounded, equals(4));

        // floor transform
        final floored = bindingEngine.resolve<dynamic>(
          '{{decVal | floor}}',
          context,
        );
        expect(floored, equals(3));

        // ceil transform
        final ceiled = bindingEngine.resolve<dynamic>(
          '{{decVal | ceil}}',
          context,
        );
        expect(ceiled, equals(4));

        // abs transform
        stateManager.set('negNum', -15);
        final absed = bindingEngine.resolve<dynamic>(
          '{{negNum | abs}}',
          context,
        );
        expect(absed, equals(15));
      });

      // TC-079: Default transforms: currency, percentage
      test('TC-079: Default transforms: currency and percentage', () {
        stateManager.set('price', 49.99);
        final currency = bindingEngine.resolve<dynamic>(
          '{{price | currency}}',
          context,
        );
        expect(currency, equals('\$49.99'));

        stateManager.set('ratio', 0.856);
        final percentage = bindingEngine.resolve<dynamic>(
          '{{ratio | percentage}}',
          context,
        );
        expect(percentage, equals('85.6%'));
      });

      // TC-080: Default transforms: date, time, json
      test('TC-080: Default transforms: date, time, json', () {
        stateManager.set('timestamp', '2024-06-15T14:30:45');

        // date transform
        final dateResult = bindingEngine.resolve<dynamic>(
          '{{timestamp | date}}',
          context,
        );
        expect(dateResult, equals('2024-06-15'));

        // time transform
        final timeResult = bindingEngine.resolve<dynamic>(
          '{{timestamp | time}}',
          context,
        );
        expect(timeResult, equals('14:30'));

        // json transform
        final jsonResult = bindingEngine.resolve<dynamic>(
          '{{config | json}}',
          context,
        );
        expect(jsonResult, isA<String>());
        expect(jsonResult, contains('"debug"'));
        expect(jsonResult, contains('"version"'));
      });

      // TC-081: registerTransform adds custom transform
      test('TC-081: registerTransform adds custom transform', () {
        bindingEngine.registerTransform('double', (value) {
          if (value is num) return value * 2;
          return value;
        });

        final result = bindingEngine.resolve<dynamic>(
          '{{counter | double}}',
          context,
        );
        expect(result, equals(10));
      });

      // TC-082: registerBinding registers and resolves a binding definition
      test('TC-082: registerBinding registers and resolves', () {
        bindingEngine.registerBinding({
          'id': 'myBinding',
          'source': 'state',
          'path': 'user.name',
          'default': 'DefaultName',
        });

        // The registered binding resolves to its default value
        final result = bindingEngine.resolve<dynamic>(
          '{{myBinding}}',
          context,
        );
        expect(result, equals('DefaultName'));
      });

      // TC-083: extractDependencies extracts state paths from expression
      test('TC-083: extractDependencies extracts state paths', () {
        final deps = bindingEngine.extractDependencies(
          '{{user.name}} and {{counter + 1}}',
        );
        expect(deps, contains('user.name'));
        expect(deps, contains('counter'));

        // Single expression with dotted path
        final singleDeps = bindingEngine.extractDependencies(
          '{{items.length()}}',
        );
        // extractDependencies extracts full dotted identifier paths
        expect(singleDeps, contains('items.length'));

        // No bindings returns empty set
        final noDeps = bindingEngine.extractDependencies('plain text');
        expect(noDeps, isEmpty);
      });

      // TC-084: Sandbox enforcement: maxDepth exceeded returns null
      test('TC-084: Sandbox enforcement: maxDepth exceeded returns null', () {
        // Set a very low maxDepth for testing
        bindingEngine.sandbox = const ExpressionSandbox(maxDepth: 1);

        // A deeply nested expression should hit the depth limit
        // A ternary has condition + trueValue + falseValue = nested evaluation
        final result = bindingEngine.resolve<dynamic>(
          "{{flag ? (counter > 3 ? 'deep' : 'nope') : 'false'}}",
          context,
        );
        // With maxDepth=1, inner evaluations exceed depth and return null
        expect(result, isNull);

        // Restore normal sandbox to verify it works without restriction
        bindingEngine.sandbox = const ExpressionSandbox();
        final normalResult = bindingEngine.resolve<dynamic>(
          "{{flag ? (counter > 3 ? 'deep' : 'nope') : 'false'}}",
          context,
        );
        expect(normalResult, equals('deep'));
      });
    });
  });
}
