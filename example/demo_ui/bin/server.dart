import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mcp_server/mcp_server.dart';

import '../lib/theme/showcase_theme.dart';
import '../lib/tools/showcase_tools.dart';
import '../lib/pages/layout_page.dart';
import '../lib/pages/display_page.dart';
import '../lib/pages/input_page.dart';
import '../lib/pages/list_page.dart';
import '../lib/pages/advanced_page.dart';
import '../lib/pages/realtime_page.dart';
import '../lib/pages/dialog_page.dart';
import '../lib/pages/form_page.dart';
import '../lib/pages/interactive_page.dart';
import '../lib/pages/dashboard_page.dart';

void main() async {
  try {
    const config = McpServerConfig(
      name: 'MCP UI Showcase',
      version: '1.0.0',
      capabilities: ServerCapabilities(
        tools: ToolsCapability(listChanged: true),
        resources: ResourcesCapability(listChanged: true, subscribe: true),
        logging: LoggingCapability(),
      ),
      enableDebugLogging: false,
    );

    final server = McpServer.createServer(config);
    final transport = McpServer.createStdioTransport().get();
    server.connect(transport);

    final state = ShowcaseState();
    final realtime = RealtimeManager(server);

    // Register tools
    registerShowcaseTools(server, state);

    // Register page resources
    _registerPages(server, state, realtime);

    // Start realtime simulation
    realtime.registerResources();
    realtime.startSimulation();

    await Completer<void>().future;
  } catch (e, st) {
    stderr.writeln('Error: $e\n$st');
    exit(1);
  }
}

void _registerPages(Server server, ShowcaseState state, RealtimeManager realtime) {
  // Application definition
  server.addResource(
    uri: 'ui://app',
    name: 'UI Showcase',
    description: 'MCP UI DSL widget showcase',
    mimeType: 'application/json',
    handler: (uri, params) async => _json(uri, _appDefinition(realtime)),
  );

  // Individual pages
  server.addResource(
    uri: 'ui://pages/layout',
    name: 'Layout',
    description: 'Layout widget showcase page',
    mimeType: 'application/json',
    handler: (uri, params) async => _json(uri, layoutPage()),
  );

  server.addResource(
    uri: 'ui://pages/display',
    name: 'Display',
    description: 'Display widget showcase page',
    mimeType: 'application/json',
    handler: (uri, params) async => _json(uri, displayPage()),
  );

  server.addResource(
    uri: 'ui://pages/input',
    name: 'Input',
    description: 'Input widget showcase page',
    mimeType: 'application/json',
    handler: (uri, params) async => _json(uri, inputPage()),
  );

  server.addResource(
    uri: 'ui://pages/list',
    name: 'List & Grid',
    description: 'List and grid widget showcase page',
    mimeType: 'application/json',
    handler: (uri, params) async => _json(uri, listPage()),
  );

  server.addResource(
    uri: 'ui://pages/advanced',
    name: 'Advanced',
    description: 'Advanced widget showcase page',
    mimeType: 'application/json',
    handler: (uri, params) async => _json(uri, advancedPage()),
  );

  server.addResource(
    uri: 'ui://pages/dialog',
    name: 'Dialog',
    description: 'Dialog widget showcase page',
    mimeType: 'application/json',
    handler: (uri, params) async => _json(uri, dialogPage()),
  );

  server.addResource(
    uri: 'ui://pages/form',
    name: 'Form',
    description: 'Form widget showcase page',
    mimeType: 'application/json',
    handler: (uri, params) async => _json(uri, formPage()),
  );

  server.addResource(
    uri: 'ui://pages/interactive',
    name: 'Interactive',
    description: 'Interactive widget showcase page',
    mimeType: 'application/json',
    handler: (uri, params) async => _json(uri, interactivePage()),
  );

  server.addResource(
    uri: 'ui://pages/realtime',
    name: 'Realtime',
    description: 'Realtime subscription showcase page',
    mimeType: 'application/json',
    handler: (uri, params) async => _json(uri, realtimePage(realtime.temperature)),
  );
}

Map<String, dynamic> _appDefinition(RealtimeManager realtime) => {
      'type': 'application',
      'title': 'UI Showcase',
      'version': '1.0.0',
      'initialRoute': '/layout',
      'theme': showcaseTheme(),
      'dashboard': dashboardDefinition(),
      'navigation': {
        'type': 'drawer',
        'items': [
          {'title': 'Layout', 'icon': 'dashboard', 'route': '/layout'},
          {'title': 'Display', 'icon': 'text_fields', 'route': '/display'},
          {'title': 'Input', 'icon': 'touch_app', 'route': '/input'},
          {'title': 'Form', 'icon': 'assignment', 'route': '/form'},
          {'title': 'List & Grid', 'icon': 'list', 'route': '/list'},
          {'title': 'Dialog', 'icon': 'chat_bubble', 'route': '/dialog'},
          {'title': 'Interactive', 'icon': 'pan_tool', 'route': '/interactive'},
          {'title': 'Advanced', 'icon': 'auto_awesome', 'route': '/advanced'},
          {'title': 'Realtime', 'icon': 'sensors', 'route': '/realtime'},
        ],
      },
      'routes': {
        '/layout': 'ui://pages/layout',
        '/display': 'ui://pages/display',
        '/input': 'ui://pages/input',
        '/form': 'ui://pages/form',
        '/list': 'ui://pages/list',
        '/dialog': 'ui://pages/dialog',
        '/interactive': 'ui://pages/interactive',
        '/advanced': 'ui://pages/advanced',
        '/realtime': 'ui://pages/realtime',
      },
      'state': {
        'initial': {
          'appName': 'MCP UI Showcase',
          'temperature': realtime.temperature,
          'status': 'Online',
        },
      },
    };

ReadResourceResult _json(String uri, Map<String, dynamic> data) =>
    ReadResourceResult(
      contents: [
        ResourceContentInfo(
          uri: uri,
          mimeType: 'application/json',
          text: jsonEncode(data),
        ),
      ],
    );
