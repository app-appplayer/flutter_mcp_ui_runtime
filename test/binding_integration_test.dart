import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_expression.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/utils/json_path.dart';

// Minimal mock of RenderContext for testing
class MockRenderContext {
  final StateManager stateManager;
  
  MockRenderContext(this.stateManager);
  
  dynamic getValue(String path) {
    return stateManager.get(path);
  }
}

void main() {
  group('Binding Integration Tests', () {
    test('Complete flow: expression parsing + state access + evaluation', () {
      // 1. Set up state
      final stateManager = StateManager();
      stateManager.initialize({
        'canvasWidgets': ['widget1', 'widget2', 'widget3'],
        'emptyList': [],
      });
      
      // 2. Verify JsonPath works directly
      final state = stateManager.getState();
      expect(JsonPath.get(state, 'canvasWidgets.length'), 3);
      expect(JsonPath.get(state, 'emptyList.length'), 0);
      
      // 3. Verify StateManager.get works with .length
      expect(stateManager.get('canvasWidgets.length'), 3);
      expect(stateManager.get('emptyList.length'), 0);
      
      // 4. Test expression parsing
      final expr = BindingExpression.parse('canvasWidgets.length > 0');
      expect(expr.type, ExpressionType.comparison);
      expect(expr.left?.path, 'canvasWidgets.length');
      expect(expr.right?.value, 0);
      
      // 5. Test manual evaluation
      final context = MockRenderContext(stateManager);
      final leftValue = context.getValue(expr.left!.path);
      final rightValue = expr.right!.value;
      
      
      expect(leftValue, 3);
      expect(rightValue, 0);
      expect(leftValue > rightValue, true);
    });
    
    test('Edge case: empty list length comparison', () {
      final stateManager = StateManager();
      stateManager.initialize({
        'emptyList': [],
      });
      
      final expr = BindingExpression.parse('emptyList.length > 0');
      final context = MockRenderContext(stateManager);
      
      final leftValue = context.getValue(expr.left!.path);
      final rightValue = expr.right!.value;
      
      expect(leftValue, 0);
      expect(rightValue, 0);
      expect(leftValue > rightValue, false);
    });
  });
}