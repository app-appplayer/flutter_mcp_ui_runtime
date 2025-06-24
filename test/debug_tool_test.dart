import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

void main() {
  testWidgets('debug tool call test', (WidgetTester tester) async {
    final runtime = MCPUIRuntime();
    String? toolName;
    Map<String, dynamic>? toolArgs;
    
    await runtime.initialize({
      'type': 'page',
      'content': {
        'type': 'button',
        'label': 'Call Tool',
        'click': {
          'type': 'tool',
          'tool': 'uiTool',
          'params': {'action': 'click'},
        },
      },
    });
    
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: runtime.buildUI(
            onToolCall: (tool, args) {
              print('onToolCall received: tool=$tool, args=$args');
              toolName = tool;
              toolArgs = args;
            },
          ),
        ),
      ),
    );
    await tester.pump();
    
    print('Finding button...');
    final button = find.text('Call Tool');
    print('Button found: ${button.evaluate().isNotEmpty}');
    
    print('Tapping button...');
    await tester.tap(button);
    await tester.pump();
    
    print('After tap: toolName=$toolName, toolArgs=$toolArgs');
    
    expect(toolName, 'uiTool');
    expect(toolArgs, {'action': 'click'});
  });
}