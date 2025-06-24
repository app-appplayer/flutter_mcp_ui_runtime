import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/widgets/widget_factory.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';

class TestWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    return Container();
  }
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