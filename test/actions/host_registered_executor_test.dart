/// `registerAction` is public, so a host must be able to supply what it asks
/// for. This is compiled against the barrel exactly as a consumer would.
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

class _HostExecutor extends ActionExecutor {
  bool ran = false;

  @override
  Future<ActionResult> execute(
    Map<String, dynamic> action,
    RenderContext context,
  ) async {
    ran = true;
    return ActionResult.error('not available here',
        errorCode: 'UNSUPPORTED_CAPABILITY');
  }
}

void main() {
  test('a host can define and register an action executor', () async {
    final runtime = MCPUIRuntime();
    await runtime.initialize(
      const {
        'type': 'page',
        'content': {'type': 'text', 'content': 'x'},
      },
      useCache: false,
      validateSchema: false,
    );

    // The point: this line does not compile unless both types are exported.
    runtime.registerAction('client.selectFile', _HostExecutor());

    await runtime.destroy();
  });
}
