import 'dart:convert';
import 'package:mcp_server/mcp_server.dart';

/// Registers all showcase tools on the server.
void registerShowcaseTools(Server server, ShowcaseState state) {
  server.addTool(
    name: 'increment',
    description: 'Increment counter',
    inputSchema: {'type': 'object', 'properties': {}},
    handler: (_) async {
      state.counter++;
      return _ok({'counter': state.counter});
    },
  );

  server.addTool(
    name: 'decrement',
    description: 'Decrement counter',
    inputSchema: {'type': 'object', 'properties': {}},
    handler: (_) async {
      state.counter--;
      return _ok({'counter': state.counter});
    },
  );

  server.addTool(
    name: 'reset',
    description: 'Reset counter',
    inputSchema: {'type': 'object', 'properties': {}},
    handler: (_) async {
      state.counter = 0;
      return _ok({'counter': state.counter});
    },
  );

  server.addTool(
    name: 'toggleDarkMode',
    description: 'Toggle dark mode flag',
    inputSchema: {'type': 'object', 'properties': {}},
    handler: (_) async {
      state.darkMode = !state.darkMode;
      return _ok({'darkMode': state.darkMode});
    },
  );

  server.addTool(
    name: 'setSlider',
    description: 'Set slider value',
    inputSchema: {
      'type': 'object',
      'properties': {'value': {'type': 'number'}},
    },
    handler: (args) async {
      state.sliderValue = (args['value'] as num?)?.toDouble() ?? 0;
      return _ok({'sliderValue': state.sliderValue});
    },
  );

  server.addTool(
    name: 'submitForm',
    description: 'Submit form data',
    inputSchema: {
      'type': 'object',
      'properties': {
        'name': {'type': 'string'},
        'email': {'type': 'string'},
      },
    },
    handler: (args) async {
      final name = args['name'] as String? ?? '';
      final email = args['email'] as String? ?? '';
      state.formResult = 'Submitted: $name ($email)';
      return _ok({'formResult': state.formResult});
    },
  );

  server.addTool(
    name: 'selectItem',
    description: 'Select a list item',
    inputSchema: {
      'type': 'object',
      'properties': {'index': {'type': 'integer'}},
    },
    handler: (args) async {
      state.selectedIndex = args['index'] as int? ?? -1;
      return _ok({'selectedIndex': state.selectedIndex});
    },
  );
}

CallToolResult _ok(Map<String, dynamic> data) => CallToolResult(
      content: [TextContent(text: jsonEncode(data))],
      isError: false,
    );

/// Mutable state shared across tools and pages.
class ShowcaseState {
  int counter = 0;
  bool darkMode = false;
  double sliderValue = 50;
  String formResult = '';
  int selectedIndex = -1;
}
