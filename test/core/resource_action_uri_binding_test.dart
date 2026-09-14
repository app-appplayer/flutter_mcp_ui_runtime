// A resource action's `uri` is a string field like any other (§3.1), so a
// page that watches its own identifier writes `state://rider/{{rider}}` and
// the runtime subscribes to the resolved address. Reported from a dispatch
// sample where the server received the template text verbatim while the same
// document's tool params resolved.

import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/runtime_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ActionHandler actionHandler;
  late RuntimeEngine engine;
  late RenderContext context;

  setUp(() {
    actionHandler = ActionHandler();
    final stateManager = StateManager()
      ..initialize(<String, dynamic>{'rider': 'r7'});
    final bindingEngine = BindingEngine();
    engine = RuntimeEngine();
    final renderer = Renderer(
      widgetRegistry: WidgetRegistry(),
      bindingEngine: bindingEngine,
      actionHandler: actionHandler,
      stateManager: stateManager,
    );
    context = RenderContext(
      renderer: renderer,
      stateManager: stateManager,
      bindingEngine: bindingEngine,
      actionHandler: actionHandler,
      themeManager: ThemeManager(),
      engine: engine,
    );
  });

  test('subscribe resolves a binding in uri before it reaches the host',
      () async {
    String? seen;
    engine.setResourceHandlers(
      onResourceSubscribe: (uri, binding) async => seen = uri,
    );

    final result = await actionHandler.execute(<String, dynamic>{
      'type': 'resource',
      'action': 'subscribe',
      'uri': 'state://rider/{{rider}}',
      'binding': 'ride',
    }, context);

    expect(result.success, isTrue);
    expect(seen, 'state://rider/r7');
    // The registration is keyed by the resolved uri too: that is the uri a
    // `notifications/resources/updated` will name.
    expect(engine.getBindingForUri('state://rider/r7'), 'ride');
    expect(engine.getBindingForUri('state://rider/{{rider}}'), isNull);
  });

  test('a variable from an enclosing scope resolves the same way', () async {
    String? seen;
    engine.setResourceHandlers(
      onResourceSubscribe: (uri, binding) async => seen = uri,
    );
    final itemContext = context.createChildContext(
      variables: <String, dynamic>{
        'item': <String, dynamic>{'id': 'd3'},
      },
    );

    await actionHandler.execute(<String, dynamic>{
      'type': 'resource',
      'action': 'subscribe',
      'uri': 'state://driver/{{item.id}}',
      'binding': 'car',
    }, itemContext);

    expect(seen, 'state://driver/d3');
  });

  test('unsubscribe and read resolve uri as well', () async {
    String? unsubscribed;
    String? read;
    engine.setResourceHandlers(
      onResourceUnsubscribe: (uri) async => unsubscribed = uri,
      onResourceRead: (uri, binding) async => read = uri,
    );

    await actionHandler.execute(<String, dynamic>{
      'type': 'resource',
      'action': 'unsubscribe',
      'uri': 'state://rider/{{rider}}',
    }, context);
    await actionHandler.execute(<String, dynamic>{
      'type': 'resource',
      'action': 'read',
      'uri': 'state://rider/{{rider}}',
      'binding': 'ride',
    }, context);

    expect(unsubscribed, 'state://rider/r7');
    expect(read, 'state://rider/r7');
  });

  test('a literal uri is unchanged', () async {
    String? seen;
    engine.setResourceHandlers(
      onResourceSubscribe: (uri, binding) async => seen = uri,
    );

    await actionHandler.execute(<String, dynamic>{
      'type': 'resource',
      'action': 'subscribe',
      'uri': 'ui://sensors/temperature',
      'binding': 'temperature',
    }, context);

    expect(seen, 'ui://sensors/temperature');
  });
}
