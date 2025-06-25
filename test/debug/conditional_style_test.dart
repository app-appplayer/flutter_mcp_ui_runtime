import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/optimization/widget_cache.dart';

void main() {
  group('Conditional Style Test', () {
    late MCPUIRuntime runtime;
    
    setUp(() {
      // Clean up any previous test state
      NavigationActionExecutor.clearGlobalNavigationHandler();
      ThemeManager.instance.reset();
      I18nManager.instance.clear();
      WidgetCache.instance.clear();
      runtime = MCPUIRuntime();
    });
    
    tearDown(() async {
      await runtime.destroy();
      // Clean up after test
      NavigationActionExecutor.clearGlobalNavigationHandler();
      ThemeManager.instance.reset();
      I18nManager.instance.clear();
      WidgetCache.instance.clear();
    });
    
    testWidgets('should apply conditional color', (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'runtime': {
          'services': {
            'state': {
              'initialState': {
                'status': 'pending',
              },
            },
          },
        },
        'content': {
          'type': 'text',
          'content': 'Status: {{status}}',
          'style': {
            'color': '{{status == "success" ? "#4CAF50" : (status == "error" ? "#F44336" : "#FF9800")}}',
          },
        },
      });
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: runtime.buildUI(),
          ),
        ),
      );
      
      await tester.pump();
      
      final text = tester.widget<Text>(find.text('Status: pending'));
      print('Text widget found: ${text.data}');
      print('Text style: ${text.style}');
      print('Text color: ${text.style?.color}');
      
      // Should have orange color for pending status
      expect(text.style?.color, const Color(0xFFFF9800));
    });
  });
}