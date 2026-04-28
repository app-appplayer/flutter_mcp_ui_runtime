import 'dart:async';
import 'dart:math';
import 'package:mcp_server/mcp_server.dart';

/// Real-time data page: resource subscription (standard + extended).
Map<String, dynamic> realtimePage(double temperature) => {
      'type': 'page',
      'metadata': {'title': 'Realtime', 'description': 'Resource subscription showcase'},
      'state': {
        'initial': {
          'temperature': temperature,
          'status': 'Not subscribed',
        },
      },
      'content': {
        'type': 'center',
        'child': {
          'type': 'linear',
          'direction': 'vertical',
          'alignment': 'center',
          'spacing': 16,
          'children': [
            {
              'type': 'text',
              'content': 'Realtime Subscription',
              'style': {'fontSize': 22, 'fontWeight': 'bold'},
            },
            {
              'type': 'card',
              'child': {
                'type': 'box',
                'padding': {'all': 24},
                'child': {
                  'type': 'linear',
                  'direction': 'vertical',
                  'alignment': 'center',
                  'spacing': 8,
                  'children': [
                    {'type': 'text', 'content': 'Temperature', 'style': {'fontSize': 14, 'color': '#666666'}},
                    {
                      'type': 'text',
                      'content': '{{temperature}}°C',
                      'style': {'fontSize': 48, 'fontWeight': 'bold', 'color': '#2196F3'},
                    },
                    {'type': 'text', 'content': '{{status}}', 'style': {'fontSize': 12, 'color': '#999999'}},
                  ],
                },
              },
            },
            {
              'type': 'linear',
              'direction': 'horizontal',
              'spacing': 8,
              'children': [
                {
                  'type': 'button',
                  'label': 'Subscribe',
                  'variant': 'filled',
                  'onTap': {
                    'type': 'resource',
                    'action': 'subscribe',
                    'uri': 'data://temperature',
                    'binding': 'temperature',
                  },
                },
                {
                  'type': 'button',
                  'label': 'Unsubscribe',
                  'variant': 'outlined',
                  'onTap': {
                    'type': 'resource',
                    'action': 'unsubscribe',
                    'uri': 'data://temperature',
                  },
                },
              ],
            },
            {
              'type': 'text',
              'content': 'Subscribe to see live temperature updates every second.',
              'style': {'fontSize': 12, 'color': '#999999'},
            },
          ],
        },
      },
    };

/// Manages temperature simulation and MCP resource.
class RealtimeManager {
  RealtimeManager(this.server);
  final Server server;
  double temperature = 20.0;
  Timer? _timer;

  void registerResources() {
    server.addResource(
      uri: 'data://temperature',
      name: 'Temperature',
      description: 'Live temperature data',
      mimeType: 'application/json',
      handler: (uri, params) async => _readTemp(),
    );
  }

  void startSimulation() {
    final rng = Random();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      temperature = 15.0 + rng.nextDouble() * 20.0;
      temperature = double.parse(temperature.toStringAsFixed(1));
      server.notifyResourceUpdated(
        'data://temperature',
        content: ResourceContent(
          uri: 'data://temperature',
          text: '{"temperature": $temperature}',
          mimeType: 'application/json',
        ),
      );
    });
  }

  void dispose() => _timer?.cancel();

  ReadResourceResult _readTemp() => ReadResourceResult(
        contents: [
          ResourceContentInfo(
            uri: 'data://temperature',
            mimeType: 'application/json',
            text: '{"temperature": $temperature}',
          ),
        ],
      );
}
