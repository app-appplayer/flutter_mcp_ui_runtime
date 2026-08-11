// The shared readers every factory calls.
//
// One unread shape here is that shape unread on every widget at once: these
// are the helpers a factory uses instead of casting, and each of them exists
// because a cast in its place painted an error box over a widget during
// ordinary editing.

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/widgets/widget_factory.dart';
import 'package:flutter_test/flutter_test.dart';

/// A factory that exists only to reach the protected helpers.
class _Probe extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) =>
      const SizedBox.shrink();
}

void main() {
  late StateManager stateManager;
  late RenderContext context;
  late _Probe probe;

  setUp(() {
    stateManager = StateManager()..initialize(<String, dynamic>{});
    final bindingEngine = BindingEngine();
    final actionHandler = ActionHandler();
    probe = _Probe();
    ThemeManager.instance.reset();
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

  group('constraints', () {
    test('every side is read, and the missing ones stay unbounded', () {
      final constraints = probe.parseConstraints({
        'minWidth': 10,
        'maxWidth': 200,
      })!;

      expect(constraints.minWidth, 10);
      expect(constraints.maxWidth, 200);
      expect(constraints.minHeight, 0.0);
      expect(constraints.maxHeight, double.infinity,
          reason: 'a missing max that defaults to zero collapses the widget '
              'instead of leaving it free');
    });

    test('all four together', () {
      final constraints = probe.parseConstraints({
        'minWidth': 1,
        'minHeight': 2,
        'maxWidth': 3,
        'maxHeight': 4,
      })!;

      expect(constraints, const BoxConstraints(
        minWidth: 1,
        minHeight: 2,
        maxWidth: 3,
        maxHeight: 4,
      ));
    });

    test('nothing, or something that is not a map, is no constraint at all',
        () {
      expect(probe.parseConstraints(null), isNull);
      expect(probe.parseConstraints('tight'), isNull);
    });
  });

  group('shape tokens', () {
    test('a numeric theme entry becomes a uniform rounded rectangle', () {
      ThemeManager.instance.setTheme({
        'shape': {'medium': 12},
      });

      final shape = probe.parseShapeToken('medium', context)!
          as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(12));
    });

    test('a `uniform` shape map is read', () {
      // Directly rather than through a token: how the theme STORES a
      // map-form shape entry is the theme manager's business, and this is
      // the shape reader either path ends in.
      final shape =
          probe.parseThemeShapeMap({'uniform': 8})! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(8));
    });

    test('a per-corner map is read, in both spellings', () {
      final logical = probe.parseThemeShapeMap({
        'topStart': 4,
        'bottomEnd': 8,
      })! as RoundedRectangleBorder;

      expect(
          logical.borderRadius,
          const BorderRadius.only(
            topLeft: Radius.circular(4),
            bottomRight: Radius.circular(8),
          ));

      final physical = probe.parseThemeShapeMap({
        'topLeft': 4,
        'bottomRight': 8,
      })! as RoundedRectangleBorder;

      expect(physical.borderRadius, logical.borderRadius,
          reason: 'the logical names are the RTL-aware spelling of the same '
              'corners; a theme written either way has to produce one shape');
    });

    test('an unknown token, or an empty shape map, is no shape', () {
      expect(probe.parseShapeToken('nonsense', context), isNull);
      expect(probe.parseShapeToken(null, context), isNull);
      expect(probe.parseShapeToken('', context), isNull);
      expect(probe.parseThemeShapeMap(null), isNull);
      expect(probe.parseThemeShapeMap(<String, dynamic>{}), isNull);
    });
  });

  group('the tolerant readers', () {
    test('a bool reads through a binding, and from the string forms', () {
      stateManager.set('showGrid', true);

      expect(readBool('{{showGrid}}', context), isTrue,
          reason: 'a setting that reverts to its default the moment it is '
              'bound is a setting that can never be toggled');
      expect(readBool(true, context), isTrue);
      expect(readBool('true', context), isTrue);
      expect(readBool(' FALSE ', context), isFalse,
          reason: 'a value carried from a form field or a query string is '
              'still the author\'s answer');
      expect(readBool(1, context), isTrue);
      expect(readBool(0, context), isFalse);
      expect(readBool('maybe', context), isNull);
      expect(readBool(null, context), isNull);
    });

    test('a number reads through a binding and from a numeric string', () {
      stateManager.set('size', 12);

      expect(readNumber('{{size}}', context), 12);
      expect(readNumber('14.5', context), 14.5);
      expect(readNumber(null, context), isNull);
      expect(readNumber('large', context), isNull);
    });

    test('an action slot takes one action or a list of them', () {
      final single = probe.actionsOf(
          {'type': 'state', 'action': 'set', 'binding': 'a'}, context);
      expect(single, hasLength(1));

      final many = probe.actionsOf([
        {'type': 'state', 'action': 'set', 'binding': 'a'},
        {'type': 'state', 'action': 'set', 'binding': 'b'},
      ], context);
      expect(many, hasLength(2),
          reason: 'the list form is what the registry declares; casting to a '
              'single map renders an error box for it');

      expect(probe.actionsOf(null, context), isEmpty);
    });

    test('a list slot reads a list, a binding to one, and nothing else', () {
      stateManager.set('rows', [1, 2, 3]);

      expect(probe.listOf('{{rows}}', context), [1, 2, 3]);
      expect(probe.listOf([1, 2], context), [1, 2]);
      expect(probe.listOf('still loading', context), isNull,
          reason: 'a wrong-shaped value reads as absent — which is what the '
              'widget draws for no data anyway — rather than as an exception '
              'on screen');
      expect(probe.listOf(null, context), isNull);
    });
  });

  group('extractProperties', () {
    test('the widget type is not one of the widget\'s properties', () {
      final properties =
          probe.extractProperties({'type': 'box', 'color': '#FF0000'});

      expect(properties.containsKey('type'), isFalse);
      expect(properties['color'], '#FF0000');
    });

    test('the original definition is not modified', () {
      final definition = {'type': 'box', 'color': '#FF0000'};
      probe.extractProperties(definition);

      expect(definition.containsKey('type'), isTrue,
          reason: 'a factory that strips the type from the caller\'s map '
              'breaks the second render of a cached definition');
    });
  });
}
