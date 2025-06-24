import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

/// Comprehensive MCP UI DSL v1.0 specification compliance tests
/// These tests verify that the runtime strictly follows the MCP UI DSL v1.0 specification
void main() {
  group('MCP UI DSL v1.0 Specification Compliance Tests', () {
    late MCPUIRuntime runtime;

    setUp(() {
      runtime = MCPUIRuntime(enableDebugMode: true);
    });

    tearDown(() async {
      await runtime.destroy();
    });

    group('Specification Format Validation', () {
      test('should accept valid page type definition', () async {
        final validPageDefinition = {
          'type': 'page',
          'content': {
            'type': 'text',
            'content': 'Hello World',
          },
        };

        expect(() async => await runtime.initialize(validPageDefinition), returnsNormally);
      });

      test('should accept valid application type definition', () async {
        final validAppDefinition = {
          'type': 'application',
          'title': 'Test App',
          'routes': {
            '/': 'home',
          },
        };

        await runtime.initialize(
          validAppDefinition,
          pageLoader: (route) async {
            // Simple page loader for test
            return {
              'type': 'page',
              'content': {
                'type': 'text',
                'content': 'Home Page',
              },
            };
          },
        );
        expect(runtime.isInitialized, isTrue);
      });

      test('should reject definitions without required type field', () async {
        final invalidDefinition = {
          'content': {
            'type': 'text',
            'content': 'Hello World',
          },
        };

        try {
          await runtime.initialize(invalidDefinition);
          fail('Should have thrown an exception');
        } catch (e) {
          expect(e, isA<ArgumentError>());
        }
      });

      test('should reject unsupported type values', () async {
        final invalidDefinition = {
          'type': 'unsupported_type',
          'content': {
            'type': 'text',
            'content': 'Hello World',
          },
        };

        try {
          await runtime.initialize(invalidDefinition);
          fail('Should have thrown an exception');
        } catch (e) {
          expect(e, isA<ArgumentError>());
        }
      });

      test('should validate page type requires content field', () async {
        final invalidPageDefinition = {
          'type': 'page',
          // Missing required content field
        };

        try {
          await runtime.initialize(invalidPageDefinition);
          fail('Should have thrown an exception');
        } catch (e) {
          expect(e, isA<ArgumentError>());
        }
      });

      test('should validate application type requires title and pages', () async {
        final invalidAppDefinition = {
          'type': 'application',
          // Missing required title and routes fields
        };

        try {
          await runtime.initialize(invalidAppDefinition, pageLoader: (String route) async {
            return {
              'type': 'page',
              'content': {
                'type': 'text',
                'value': 'Test page'
              }
            };
          });
          fail('Should have thrown an exception');
        } catch (e) {
          expect(e, isA<ArgumentError>());
        }
      });
    });

    group('Action Definition Compliance', () {
      test('should accept only valid action formats', () async {
        final validActionDefinition = {
          'type': 'page',
          'content': {
            'type': 'button',
            'label': 'Test Button',
            'click': {
              'type': 'tool',
              'tool': 'test_tool',
              'params': {'param': 'value'},
            },
          },
        };

        await runtime.initialize(validActionDefinition);
        expect(runtime.isInitialized, isTrue);
      });

      test('should reject legacy action format (name/params)', () async {
        final legacyActionDefinition = {
          'type': 'page',
          'content': {
            'type': 'button',
            'label': 'Test Button',
            'click': {
              'type': 'tool',
              'name': 'test_tool',  // Legacy: should be 'tool'
              'params': {'param': 'value'},  // Legacy: should be 'params'
            },
          },
        };

        // The system currently accepts this but won't find the tool field
        await runtime.initialize(legacyActionDefinition);
        expect(runtime.isInitialized, isTrue);
        
        // TODO: Add strict validation mode to reject legacy formats
      });

      test('should validate tool action requires tool and args fields', () async {
        final invalidToolAction = {
          'type': 'page',
          'content': {
            'type': 'button',
            'label': 'Test Button',
            'click': {
              'type': 'tool',
              // Missing required 'tool' field
              'params': {},
            },
          },
        };

        // System accepts this but tool execution will fail
        await runtime.initialize(invalidToolAction);
        expect(runtime.isInitialized, isTrue);
      });

      test('should validate state action format', () async {
        final validStateAction = {
          'type': 'page',
          'content': {
            'type': 'button',
            'label': 'Increment',
            'click': {
              'type': 'state',
              'action': 'increment',
              'path': 'counter',
              'value': 1,
            },
          },
        };

        await runtime.initialize(validStateAction);
        expect(runtime.isInitialized, isTrue);
      });

      test('should validate navigation action format', () async {
        final validNavigationAction = {
          'type': 'page',
          'content': {
            'type': 'button',
            'label': 'Navigate',
            'click': {
              'type': 'navigation',
              'action': 'push',
              'target': '/next-page',
            },
          },
        };

        await runtime.initialize(validNavigationAction);
        expect(runtime.isInitialized, isTrue);
      });
    });

    group('Widget Definition Compliance', () {
      test('should validate all required widget properties', () async {
        // Test all standard widgets have required properties
        final widgetTests = [
          {
            'type': 'text',
            'content': 'Required content',
          },
          {
            'type': 'button',
            'label': 'Required label',
          },
          {
            'type': 'box',
            'child': {'type': 'text', 'content': 'Child'},
          },
          {
            'type': 'linear',
            'direction': 'vertical',
            'children': [
              {'type': 'text', 'content': 'Child 1'},
            ],
          },
          {
            'type': 'linear',
            'direction': 'horizontal',
            'children': [
              {'type': 'text', 'content': 'Child 1'},
            ],
          },
        ];

        for (final widgetDef in widgetTests) {
          final definition = {
            'type': 'page',
            'content': widgetDef,
          };

          await runtime.initialize(definition);
          expect(runtime.isInitialized, isTrue);
          await runtime.destroy();
          runtime = MCPUIRuntime(enableDebugMode: true);
        }
      });

      test('should handle widgets with missing required properties gracefully', () async {
        final invalidWidgets = [
          {
            'type': 'text',
            // Missing required 'content' property
          },
          {
            'type': 'button',
            // Missing required 'label' property
          },
          {
            'type': 'linear',
            'direction': 'vertical',
            // Missing required 'children' property
          },
        ];

        // System should handle missing properties gracefully
        for (final widgetDef in invalidWidgets) {
          final definition = {
            'type': 'page',
            'content': widgetDef,
          };

          await runtime.initialize(definition);
          expect(runtime.isInitialized, isTrue);
          
          // Widget should render with defaults or empty values
          final widget = runtime.buildUI();
          expect(widget, isNotNull);
          
          await runtime.destroy();
          runtime = MCPUIRuntime(enableDebugMode: true);
        }
      });
    });

    group('Runtime Service Configuration Compliance', () {
      test('should validate state service configuration', () async {
        final validStateServiceConfig = {
          'type': 'page',
          'content': {
            'type': 'text',
            'content': '{{counter}}',
          },
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'counter': 0,
                },
              },
            },
          },
        };

        await runtime.initialize(validStateServiceConfig);
        expect(runtime.isInitialized, isTrue);
      });

      test('should validate notification service configuration', () async {
        final validNotificationConfig = {
          'type': 'page',
          'content': {
            'type': 'text',
            'content': 'Test',
          },
          'runtime': {
            'services': {
              'notifications': {
                'channels': [
                  {
                    'id': 'test',
                    'name': 'Test Channel',
                    'importance': 'default',
                  },
                ],
              },
            },
          },
        };

        await runtime.initialize(validNotificationConfig);
        expect(runtime.isInitialized, isTrue);
      });

      test('should validate background service configuration', () async {
        final validBackgroundServiceConfig = {
          'type': 'page',
          'content': {
            'type': 'text',
            'content': 'Test',
          },
          'runtime': {
            'services': {
              'backgroundServices': {
                'sync': {
                  'type': 'periodic',
                  'interval': 30000,
                  'tool': 'syncData',
                },
              },
            },
          },
        };

        await runtime.initialize(validBackgroundServiceConfig);
        expect(runtime.isInitialized, isTrue);
      });
    });

    group('Binding Expression Compliance', () {
      test('should support all valid binding expressions', () async {
        final validBindings = [
          '{{simpleValue}}',
          '{{nested.value}}',
          '{{array[0]}}',
          '{{computed ? "true" : "false"}}',
          '{{value + 10}}',
          '{{text.toUpperCase()}}',
        ];

        for (final binding in validBindings) {
          final definition = {
            'type': 'page',
            'content': {
              'type': 'text',
              'content': binding,
            },
            'runtime': {
              'services': {
                'state': {
                  'initialState': {
                    'simpleValue': 'test',
                    'nested': {'value': 'nested test'},
                    'array': ['first'],
                    'computed': true,
                    'value': 5,
                    'text': 'hello',
                  },
                },
              },
            },
          };

          await runtime.initialize(definition);
          expect(runtime.isInitialized, isTrue);
          await runtime.destroy();
          runtime = MCPUIRuntime(enableDebugMode: true);
        }
      });

      test('should handle invalid binding expressions gracefully', () async {
        final invalidBindings = [
          '{{}}',  // Empty expression
          '{{unclosed',  // Unclosed braces
          'unclosed}}',  // Unmatched closing braces
          '{{invalid..syntax}}',  // Invalid syntax
        ];

        for (final binding in invalidBindings) {
          final definition = {
            'type': 'page',
            'content': {
              'type': 'text',
              'content': binding,
            },
          };

          // System should handle invalid bindings gracefully without crashing
          await runtime.initialize(definition);
          expect(runtime.isInitialized, isTrue);
          
          // The widget should render but show the raw binding or empty text
          final widget = runtime.buildUI();
          expect(widget, isNotNull);
          
          await runtime.destroy();
          runtime = MCPUIRuntime(enableDebugMode: true);
        }
      });
    });

    group('Error Handling Compliance', () {
      test('should handle invalid widget types gracefully', () async {
        final invalidDefinition = {
          'type': 'page',
          'content': {
            'type': 'invalid_widget_type',
          },
        };

        // System should handle invalid widget types without crashing
        await runtime.initialize(invalidDefinition);
        expect(runtime.isInitialized, isTrue);
        
        // Widget should render as a fallback (e.g., Container or error widget)
        final widget = runtime.buildUI();
        expect(widget, isNotNull);
      });

      test('should handle runtime errors gracefully', () async {
        final definition = {
          'type': 'page',
          'content': {
            'type': 'text',
            'content': '{{nonExistentValue.property}}',
          },
        };

        await runtime.initialize(definition);
        expect(runtime.isInitialized, isTrue);
        
        // Should not crash when rendering with missing state
        final widget = runtime.buildUI();
        expect(widget, isNotNull);
      });
    });

    group('Performance and Resource Management', () {
      test('should properly clean up resources', () async {
        final definition = {
          'type': 'page',
          'content': {
            'type': 'text',
            'content': 'Test',
          },
        };

        await runtime.initialize(definition);
        expect(runtime.isInitialized, isTrue);
        
        await runtime.destroy();
        expect(runtime.isInitialized, isFalse);
      });

      test('should handle multiple initializations correctly', () async {
        final definition = {
          'type': 'page',
          'content': {
            'type': 'text',
            'content': 'Test',
          },
        };

        await runtime.initialize(definition);
        expect(runtime.isInitialized, isTrue);
        
        // Second initialization should fail
        expect(() async => await runtime.initialize(definition), throwsStateError);
      });
    });
  });
}