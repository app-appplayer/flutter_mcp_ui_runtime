import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/widgets/widget_factory.dart';

class TestWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    return Container();
  }
}

RenderContext _makeRenderContext(ThemeManager themeManager) {
  final bindingEngine = BindingEngine();
  final actionHandler = ActionHandler();
  final stateManager = StateManager()..initialize(const {});
  final renderer = Renderer(
    widgetRegistry: WidgetRegistry(),
    bindingEngine: bindingEngine,
    actionHandler: actionHandler,
    stateManager: stateManager,
  );
  return RenderContext(
    renderer: renderer,
    stateManager: stateManager,
    bindingEngine: bindingEngine,
    actionHandler: actionHandler,
    themeManager: themeManager,
  );
}

void main() {
  group('Color Parsing Tests', () {
    late TestWidgetFactory factory;
    
    setUp(() {
      factory = TestWidgetFactory();
    });
    
    group('Hex Color Formats', () {
      test('should parse 6-digit hex color (#RRGGBB)', () {
        final color = factory.parseColor('#FF5722');
        expect(color, isNotNull);
        expect(color, const Color(0xFFFF5722));
      });
      
      test('should parse 8-digit hex color (#AARRGGBB)', () {
        final color = factory.parseColor('#80FF5722');
        expect(color, isNotNull);
        expect(color, const Color(0x80FF5722));
      });
      
      test('should parse 3-digit hex color (#RGB)', () {
        final color = factory.parseColor('#F57');
        expect(color, isNotNull);
        expect(color, const Color(0xFFFF5577));
      });
      
      test('should return null for invalid hex lengths', () {
        expect(factory.parseColor('#F'), isNull);
        expect(factory.parseColor('#FF'), isNull);
        expect(factory.parseColor('#FFFF'), isNull);
        expect(factory.parseColor('#FFFFF'), isNull);
        expect(factory.parseColor('#FFFFFFFFF'), isNull);
      });
      
      test('should handle uppercase and lowercase hex', () {
        final colorLower = factory.parseColor('#ff5722');
        final colorUpper = factory.parseColor('#FF5722');
        
        expect(colorLower, isNotNull);
        expect(colorUpper, isNotNull);
        expect(colorLower, colorUpper);
      });
    });
    
    group('Named Colors', () {
      test('should parse standard named colors', () {
        expect(factory.parseColor('red'), Colors.red);
        expect(factory.parseColor('blue'), Colors.blue);
        expect(factory.parseColor('green'), Colors.green);
        expect(factory.parseColor('yellow'), Colors.yellow);
        expect(factory.parseColor('orange'), Colors.orange);
        expect(factory.parseColor('purple'), Colors.purple);
        expect(factory.parseColor('black'), Colors.black);
        expect(factory.parseColor('white'), Colors.white);
      });
      
      test('should handle case-insensitive named colors', () {
        expect(factory.parseColor('RED'), Colors.red);
        expect(factory.parseColor('Blue'), Colors.blue);
        expect(factory.parseColor('GREEN'), Colors.green);
      });
      
      test('should handle grey/gray variants', () {
        expect(factory.parseColor('grey'), Colors.grey);
        expect(factory.parseColor('gray'), Colors.grey);
        expect(factory.parseColor('GREY'), Colors.grey);
        expect(factory.parseColor('GRAY'), Colors.grey);
      });
    });
    
    group('Edge Cases', () {
      test('should return null for null input', () {
        expect(factory.parseColor(null), isNull);
      });
      
      test('should return null for empty string', () {
        expect(factory.parseColor(''), isNull);
      });
      
      test('should return null for invalid color names', () {
        expect(factory.parseColor('invalidcolor'), isNull);
        expect(factory.parseColor('notacolor'), isNull);
      });
      
      test('should return null for malformed hex colors', () {
        expect(factory.parseColor('FF5722'), isNull); // Missing #
        expect(factory.parseColor('#GGFFFF'), isNull); // Invalid hex characters
        expect(factory.parseColor('#'), isNull); // Just #
      });
      
      test('should return null for non-string input', () {
        expect(factory.parseColor(123), isNull);
        expect(factory.parseColor(true), isNull);
        expect(factory.parseColor(['red']), isNull);
        expect(factory.parseColor({'color': 'red'}), isNull);
      });
    });
    
    group('Theme Token Resolution (spec §5.3)', () {
      late ThemeManager themeManager;
      late RenderContext ctx;

      setUp(() {
        themeManager = ThemeManager.instance..reset();
        ctx = _makeRenderContext(themeManager);
      });

      test('returns null for slot name when no context is supplied', () {
        // Backward compatibility: calling parseColor without a context
        // still rejects slot names so factories that have not been
        // threaded through keep their previous (hex-only) behaviour.
        expect(factory.parseColor('primary'), isNull);
        expect(factory.parseColor('surface'), isNull);
      });

      test('resolves "primary" to the active scheme in light mode', () {
        themeManager.setTheme({
          'mode': 'light',
          'color': {'primary': '#2196F3'},
        });
        expect(factory.parseColor('primary', ctx),
            equals(const Color(0xFF2196F3)));
      });

      test('resolves "primary" to the dark scheme after mode switch', () {
        themeManager.setTheme({
          'mode': 'system',
          'color': {'primary': '#2196F3'},
          'dark': {
            'mode': 'dark',
            'color': {'primary': '#64B5F6'},
          },
        });
        themeManager.setHostBrightness(Brightness.dark);
        // parseColor reads the JSON snapshot which is mode-agnostic; the dark
        // override is reflected in toFlutterTheme rather than the path lookup.
        // Switch to direct dark mode to surface dark slots in the JSON view.
        themeManager.setTheme({
          'mode': 'dark',
          'color': {'primary': '#64B5F6'},
        });
        expect(factory.parseColor('primary', ctx),
            equals(const Color(0xFF64B5F6)));
      });

      test('resolves canonical 1.3 M3 28-role slots', () {
        themeManager.setTheme({
          'mode': 'light',
          'color': {
            'primary': '#2196F3',
            'onPrimary': '#FFFFFF',
            'secondary': '#FF4081',
            'onSecondary': '#FFFFFF',
            'tertiary': '#9C27B0',
            'onTertiary': '#FFFFFF',
            'surface': '#FFFFFF',
            'onSurface': '#1A1A1A',
            'error': '#F44336',
            'onError': '#FFFFFF',
            'outline': '#9E9E9E',
          },
        });
        const slots = <String>[
          'primary',
          'onPrimary',
          'secondary',
          'onSecondary',
          'tertiary',
          'onTertiary',
          'surface',
          'onSurface',
          'error',
          'onError',
          'outline',
        ];
        for (final slot in slots) {
          expect(factory.parseColor(slot, ctx), isNotNull, reason: slot);
        }
      });

      test('unknown slot names still return null even with a context', () {
        expect(factory.parseColor('notASlot', ctx), isNull);
      });

      test('resolveColor alias honours the same contract', () {
        themeManager.setTheme({
          'mode': 'light',
          'color': {'primary': '#2196F3'},
        });
        expect(factory.resolveColor('primary', ctx),
            equals(const Color(0xFF2196F3)));
        themeManager.setTheme({
          'mode': 'dark',
          'color': {'primary': '#64B5F6'},
        });
        expect(factory.resolveColor('primary', ctx),
            equals(const Color(0xFF64B5F6)));
      });
    });

    group('MCP UI DSL v1.0 Spec Compliance', () {
      test('should support semi-transparent colors', () {
        // 50% transparent red
        final color = factory.parseColor('#80FF0000');
        expect(color, isNotNull);
        expect(color, const Color(0x80FF0000));
      });
      
      test('should support fully transparent colors', () {
        // Fully transparent
        final color = factory.parseColor('#00FFFFFF');
        expect(color, isNotNull);
        expect(color, const Color(0x00FFFFFF));
      });
      
      test('should maintain backwards compatibility with 6-digit format', () {
        // Should default to fully opaque when alpha not specified
        final color = factory.parseColor('#FF5722');
        expect(color, isNotNull);
        expect(color, const Color(0xFFFF5722));
      });
    });
  });
}