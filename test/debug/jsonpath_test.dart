import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/utils/json_path.dart';

void main() {
  test('JsonPath.get with array length', () {
    final data = {
      'todos': ['Task 1', 'Task 2', 'Task 3']
    };
    
    final result = JsonPath.get(data, 'todos.length');
    expect(result, 3);
  });
}