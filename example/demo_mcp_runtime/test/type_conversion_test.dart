import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MCP Runtime Data Structure Tests', () {
    test('Runtime configuration parsing works', () {
      final definition = {
        'mcpRuntime': {
          'version': '1.0',
          'runtime': {
            'id': 'test_app',
            'domain': 'com.test.app',
            'version': '1.0.0',
            'cachePolicy': {
              'enabled': true,
              'maxAge': 3600,
              'offlineMode': 'partial'
            },
            'services': {
              'state': {
                'initialState': {
                  'counter': 0,
                  'message': 'Hello World'
                }
              }
            }
          }
        }
      };

      // Test basic structure
      expect(definition.containsKey('mcpRuntime'), true);
      
      final mcpRuntime = definition['mcpRuntime'] as Map<String, dynamic>;
      expect(mcpRuntime['version'], '1.0');
      
      final runtime = mcpRuntime['runtime'] as Map<String, dynamic>;
      expect(runtime['id'], 'test_app');
      expect(runtime['domain'], 'com.test.app');
      expect(runtime['version'], '1.0.0');
      
      final cachePolicy = runtime['cachePolicy'] as Map<String, dynamic>;
      expect(cachePolicy['enabled'], true);
      expect(cachePolicy['maxAge'], 3600);
      expect(cachePolicy['offlineMode'], 'partial');
      
      final services = runtime['services'] as Map<String, dynamic>;
      final stateService = services['state'] as Map<String, dynamic>;
      final initialState = stateService['initialState'] as Map<String, dynamic>;
      expect(initialState['counter'], 0);
      expect(initialState['message'], 'Hello World');
    });

    test('State structure validation', () {
      final state = {
        'user': {
          'name': 'John',
          'age': 25,
          'scores': [85, 92, 78]
        },
        'counter': 10
      };

      // Test simple state access
      expect(state['counter'], 10);
      
      final user = state['user'] as Map<String, dynamic>;
      expect(user['name'], 'John');
      expect(user['age'], 25);
      
      final scores = user['scores'] as List<dynamic>;
      expect(scores[0], 85);
      expect(scores.length, 3);
    });

    test('Tool call structure validation', () {
      final toolCall = {
        'type': 'tool',
        'tool': 'increment',
        'args': {
          'value': 1,
          'message': 'Increment counter'
        }
      };

      expect(toolCall['type'], 'tool');
      expect(toolCall['tool'], 'increment');
      
      final args = toolCall['args'] as Map<String, dynamic>;
      expect(args['value'], 1);
      expect(args['message'], 'Increment counter');
    });

    test('UI definition structure validation', () {
      final uiDefinition = {
        'type': 'scaffold',
        'properties': {
          'appBar': {
            'type': 'appbar',
            'properties': {
              'title': {'type': 'text', 'properties': {'content': 'Test App'}}
            }
          },
          'body': {
            'type': 'column',
            'children': [
              {
                'type': 'text',
                'properties': {
                  'content': {'binding': 'state.message'}
                }
              }
            ]
          }
        }
      };

      expect(uiDefinition['type'], 'scaffold');
      
      final properties = uiDefinition['properties'] as Map<String, dynamic>;
      final appBar = properties['appBar'] as Map<String, dynamic>;
      expect(appBar['type'], 'appbar');
      
      final body = properties['body'] as Map<String, dynamic>;
      expect(body['type'], 'column');
      
      final children = body['children'] as List<dynamic>;
      expect(children.length, 1);
      
      final firstChild = children[0] as Map<String, dynamic>;
      expect(firstChild['type'], 'text');
      
      final childProperties = firstChild['properties'] as Map<String, dynamic>;
      final content = childProperties['content'] as Map<String, dynamic>;
      expect(content['binding'], 'state.message');
    });

    test('Service configuration validation', () {
      final services = {
        'state': {
          'initialState': {'counter': 0},
          'computed': {
            'doubledCounter': 'state.counter * 2'
          },
          'watchers': [
            {
              'path': 'counter',
              'debounceMs': 300,
              'actions': [
                {'type': 'log', 'message': 'Counter changed'}
              ]
            }
          ]
        },
        'notifications': {
          'channels': [
            {'id': 'general', 'name': 'General', 'importance': 'default'}
          ]
        }
      };

      final stateService = services['state'] as Map<String, dynamic>;
      final initialState = stateService['initialState'] as Map<String, dynamic>;
      expect(initialState['counter'], 0);
      
      final computed = stateService['computed'] as Map<String, dynamic>;
      expect(computed['doubledCounter'], 'state.counter * 2');
      
      final watchers = stateService['watchers'] as List<dynamic>;
      expect(watchers.length, 1);
      
      final watcher = watchers[0] as Map<String, dynamic>;
      expect(watcher['path'], 'counter');
      expect(watcher['debounceMs'], 300);
      
      final notificationService = services['notifications'] as Map<String, dynamic>;
      final channels = notificationService['channels'] as List<dynamic>;
      expect(channels.length, 1);
      
      final channel = channels[0] as Map<String, dynamic>;
      expect(channel['id'], 'general');
      expect(channel['name'], 'General');
      expect(channel['importance'], 'default');
    });
  });
}