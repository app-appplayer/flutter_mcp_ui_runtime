import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

void main() {
  group('MCP UI DSL v1.0 - Conditional Rendering Tests', () {
    late MCPUIRuntime runtime;
    
    setUp(() {
      runtime = MCPUIRuntime();
    });
    
    tearDown(() {
      runtime.destroy();
    });
    
    group('Basic Conditional Rendering', () {
      testWidgets('should render then branch when condition is true', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'showMessage': true,
                },
              },
            },
          },
          'content': {
            'type': 'conditional',
            'condition': '{{showMessage}}',
            'then': {
              'type': 'text',
              'content': 'Message is visible',
            },
            'orElse': {
              'type': 'text',
              'content': 'Message is hidden',
            },
          },
        });
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: runtime.buildUI(),
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        expect(find.text('Message is visible'), findsOneWidget);
        expect(find.text('Message is hidden'), findsNothing);
      });
      
      testWidgets('should render orElse branch when condition is false', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'showMessage': false,
                },
              },
            },
          },
          'content': {
            'type': 'conditional',
            'condition': '{{showMessage}}',
            'then': {
              'type': 'text',
              'content': 'Message is visible',
            },
            'orElse': {
              'type': 'text',
              'content': 'Message is hidden',
            },
          },
        });
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: runtime.buildUI(),
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        expect(find.text('Message is visible'), findsNothing);
        expect(find.text('Message is hidden'), findsOneWidget);
      });
      
      testWidgets('should render nothing when condition is false and no orElse', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'showOptional': false,
                },
              },
            },
          },
          'content': {
            'type': 'linear',
            'direction': 'vertical',
            'children': [
              {
                'type': 'text',
                'content': 'Always visible',
              },
              {
                'type': 'conditional',
                'condition': '{{showOptional}}',
                'then': {
                  'type': 'text',
                  'content': 'Optional content',
                },
              },
              {
                'type': 'text',
                'content': 'Also always visible',
              },
            ],
          },
        });
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: runtime.buildUI(),
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        expect(find.text('Always visible'), findsOneWidget);
        expect(find.text('Optional content'), findsNothing);
        expect(find.text('Also always visible'), findsOneWidget);
      });
    });
    
    group('Dynamic Conditional Updates', () {
      testWidgets('should toggle between branches when condition changes', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'isLoggedIn': false,
                },
              },
            },
          },
          'content': {
            'type': 'linear',
            'direction': 'vertical',
            'children': [
              {
                'type': 'conditional',
                'condition': '{{isLoggedIn}}',
                'then': {
                  'type': 'linear',
                  'direction': 'vertical',
                  'children': [
                    {
                      'type': 'text',
                      'content': 'Welcome back!',
                    },
                    {
                      'type': 'button',
                      'label': 'Logout',
                      'click': {
                        'type': 'state',
                        'action': 'set',
                        'path': 'isLoggedIn',
                        'value': false,
                      },
                    },
                  ],
                },
                'orElse': {
                  'type': 'linear',
                  'direction': 'vertical',
                  'children': [
                    {
                      'type': 'text',
                      'content': 'Please login',
                    },
                    {
                      'type': 'button',
                      'label': 'Login',
                      'click': {
                        'type': 'state',
                        'action': 'set',
                        'path': 'isLoggedIn',
                        'value': true,
                      },
                    },
                  ],
                },
              },
            ],
          },
        });
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: runtime.buildUI(),
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        // Initially logged out
        expect(find.text('Please login'), findsOneWidget);
        expect(find.text('Login'), findsOneWidget);
        expect(find.text('Welcome back!'), findsNothing);
        expect(find.text('Logout'), findsNothing);
        
        // Click login
        await tester.tap(find.text('Login'));
        await tester.pumpAndSettle();
        
        // Should show logged in state
        expect(find.text('Welcome back!'), findsOneWidget);
        expect(find.text('Logout'), findsOneWidget);
        expect(find.text('Please login'), findsNothing);
        expect(find.text('Login'), findsNothing);
        
        // Click logout
        await tester.tap(find.text('Logout'));
        await tester.pumpAndSettle();
        
        // Back to logged out state
        expect(find.text('Please login'), findsOneWidget);
        expect(find.text('Login'), findsOneWidget);
        expect(find.text('Welcome back!'), findsNothing);
        expect(find.text('Logout'), findsNothing);
      });
    });
    
    group('Complex Conditional Expressions', () {
      testWidgets('should evaluate equality comparisons', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'userRole': 'admin',
                },
              },
            },
          },
          'content': {
            'type': 'linear',
            'direction': 'vertical',
            'children': [
              {
                'type': 'conditional',
                'condition': '{{userRole == "admin"}}',
                'then': {
                  'type': 'text',
                  'content': 'Admin Dashboard',
                },
              },
              {
                'type': 'conditional',
                'condition': '{{userRole == "user"}}',
                'then': {
                  'type': 'text',
                  'content': 'User Dashboard',
                },
              },
              {
                'type': 'conditional',
                'condition': '{{userRole != "admin" && userRole != "user"}}',
                'then': {
                  'type': 'text',
                  'content': 'Guest Dashboard',
                },
              },
            ],
          },
        });
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: runtime.buildUI(),
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        expect(find.text('Admin Dashboard'), findsOneWidget);
        expect(find.text('User Dashboard'), findsNothing);
        expect(find.text('Guest Dashboard'), findsNothing);
      });
      
      testWidgets('should evaluate logical AND expressions', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'isAuthenticated': true,
                  'hasPermission': true,
                },
              },
            },
          },
          'content': {
            'type': 'conditional',
            'condition': '{{isAuthenticated && hasPermission}}',
            'then': {
              'type': 'text',
              'content': 'Access Granted',
            },
            'orElse': {
              'type': 'text',
              'content': 'Access Denied',
            },
          },
        });
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: runtime.buildUI(),
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        expect(find.text('Access Granted'), findsOneWidget);
        expect(find.text('Access Denied'), findsNothing);
        
        // Remove permission
        runtime.stateManager.set('hasPermission', false);
        await tester.pumpAndSettle();
        
        expect(find.text('Access Granted'), findsNothing);
        expect(find.text('Access Denied'), findsOneWidget);
      });
      
      testWidgets('should evaluate logical OR expressions', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'isPremium': false,
                  'isTrial': true,
                },
              },
            },
          },
          'content': {
            'type': 'conditional',
            'condition': '{{isPremium || isTrial}}',
            'then': {
              'type': 'text',
              'content': 'Premium Features Available',
            },
            'orElse': {
              'type': 'text',
              'content': 'Upgrade to Premium',
            },
          },
        });
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: runtime.buildUI(),
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        expect(find.text('Premium Features Available'), findsOneWidget);
        expect(find.text('Upgrade to Premium'), findsNothing);
      });
      
      testWidgets('should evaluate numeric comparisons', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'count': 5,
                  'threshold': 10,
                },
              },
            },
          },
          'content': {
            'type': 'linear',
            'direction': 'vertical',
            'children': [
              {
                'type': 'conditional',
                'condition': '{{count < threshold}}',
                'then': {
                  'type': 'text',
                  'content': 'Below threshold',
                },
              },
              {
                'type': 'conditional',
                'condition': '{{count >= threshold}}',
                'then': {
                  'type': 'text',
                  'content': 'At or above threshold',
                },
              },
              {
                'type': 'button',
                'label': 'Increment',
                'click': {
                  'type': 'state',
                  'action': 'increment',
                  'path': 'count',
                },
              },
            ],
          },
        });
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: runtime.buildUI(),
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        expect(find.text('Below threshold'), findsOneWidget);
        expect(find.text('At or above threshold'), findsNothing);
        
        // Increment count to reach threshold
        for (int i = 0; i < 5; i++) {
          await tester.tap(find.text('Increment'));
          await tester.pumpAndSettle();
        }
        
        expect(find.text('Below threshold'), findsNothing);
        expect(find.text('At or above threshold'), findsOneWidget);
      });
    });
    
    group('Nested Conditional Widgets', () {
      testWidgets('should handle nested conditionals', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'userType': 'premium',
                  'features': {
                    'advancedAnalytics': true,
                    'exportData': true,
                  },
                },
              },
            },
          },
          'content': {
            'type': 'conditional',
            'condition': '{{userType == "premium"}}',
            'then': {
              'type': 'linear',
              'direction': 'vertical',
              'children': [
                {
                  'type': 'text',
                  'content': 'Premium User',
                },
                {
                  'type': 'conditional',
                  'condition': '{{features.advancedAnalytics}}',
                  'then': {
                    'type': 'text',
                    'content': 'Advanced Analytics Enabled',
                  },
                },
                {
                  'type': 'conditional',
                  'condition': '{{features.exportData}}',
                  'then': {
                    'type': 'text',
                    'content': 'Export Data Enabled',
                  },
                },
              ],
            },
            'orElse': {
              'type': 'text',
              'content': 'Free User',
            },
          },
        });
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: runtime.buildUI(),
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        expect(find.text('Premium User'), findsOneWidget);
        expect(find.text('Advanced Analytics Enabled'), findsOneWidget);
        expect(find.text('Export Data Enabled'), findsOneWidget);
        expect(find.text('Free User'), findsNothing);
      });
    });
    
    group('Conditional Forms', () {
      testWidgets('should show/hide form fields conditionally', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'accountType': 'personal',
                  'form': {
                    'name': '',
                    'companyName': '',
                    'taxId': '',
                  },
                },
              },
            },
          },
          'content': {
            'type': 'form',
            'children': [
              {
                'type': 'select',
                'label': 'Account Type',
                'value': '{{accountType}}',
                'items': [
                  {'value': 'personal', 'label': 'Personal'},
                  {'value': 'business', 'label': 'Business'},
                ],
                'change': {
                  'type': 'state',
                  'action': 'set',
                  'path': 'accountType',
                  'value': '{{event.value}}',
                },
              },
              {
                'type': 'textInput',
                'label': 'Full Name',
                'value': '{{form.name}}',
                'change': {
                  'type': 'state',
                  'action': 'set',
                  'path': 'form.name',
                  'value': '{{event.value}}',
                },
              },
              {
                'type': 'conditional',
                'condition': '{{accountType == "business"}}',
                'then': {
                  'type': 'linear',
                  'direction': 'vertical',
                  'gap': 12,
                  'children': [
                    {
                      'type': 'textInput',
                      'label': 'Company Name',
                      'value': '{{form.companyName}}',
                      'change': {
                        'type': 'state',
                        'action': 'set',
                        'path': 'form.companyName',
                        'value': '{{event.value}}',
                      },
                    },
                    {
                      'type': 'textInput',
                      'label': 'Tax ID',
                      'value': '{{form.taxId}}',
                      'change': {
                        'type': 'state',
                        'action': 'set',
                        'path': 'form.taxId',
                        'value': '{{event.value}}',
                      },
                    },
                  ],
                },
              },
            ],
          },
        });
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: runtime.buildUI(),
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        // Initially personal account - should not show business fields
        expect(find.text('Full Name'), findsOneWidget);
        expect(find.text('Company Name'), findsNothing);
        expect(find.text('Tax ID'), findsNothing);
        
        // Change to business account
        await tester.tap(find.byType(DropdownButton<dynamic>));
        await tester.pumpAndSettle();
        
        await tester.tap(find.text('Business').last);
        await tester.pumpAndSettle();
        
        // Should now show business fields
        expect(find.text('Full Name'), findsOneWidget);
        expect(find.text('Company Name'), findsOneWidget);
        expect(find.text('Tax ID'), findsOneWidget);
      });
    });
    
    group('Conditional Styling', () {
      testWidgets('should apply conditional styles', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'status': 'pending',
                },
              },
            },
          },
          'content': {
            'type': 'linear',
            'direction': 'vertical',
            'children': [
              {
                'type': 'text',
                'content': 'Status: {{status}}',
                'style': {
                  'color': '{{status == "success" ? "#4CAF50" : (status == "error" ? "#F44336" : "#FF9800")}}',
                  'fontWeight': '{{status == "error" ? "bold" : "normal"}}',
                },
              },
              {
                'type': 'linear',
                'direction': 'horizontal',
                'gap': 8,
                'children': [
                  {
                    'type': 'button',
                    'label': 'Success',
                    'click': {
                      'type': 'state',
                      'action': 'set',
                      'path': 'status',
                      'value': 'success',
                    },
                  },
                  {
                    'type': 'button',
                    'label': 'Error',
                    'click': {
                      'type': 'state',
                      'action': 'set',
                      'path': 'status',
                      'value': 'error',
                    },
                  },
                  {
                    'type': 'button',
                    'label': 'Pending',
                    'click': {
                      'type': 'state',
                      'action': 'set',
                      'path': 'status',
                      'value': 'pending',
                    },
                  },
                ],
              },
            ],
          },
        });
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: runtime.buildUI(),
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        // Initially pending - orange color
        final initialText = tester.widget<Text>(find.text('Status: pending'));
        expect(initialText.style?.color, const Color(0xFFFF9800));
        expect(initialText.style?.fontWeight, FontWeight.normal);
        
        // Change to error
        await tester.tap(find.text('Error'));
        await tester.pumpAndSettle();
        
        final errorText = tester.widget<Text>(find.text('Status: error'));
        expect(errorText.style?.color, const Color(0xFFF44336));
        expect(errorText.style?.fontWeight, FontWeight.bold);
        
        // Change to success
        await tester.tap(find.text('Success'));
        await tester.pumpAndSettle();
        
        final successText = tester.widget<Text>(find.text('Status: success'));
        expect(successText.style?.color, const Color(0xFF4CAF50));
        expect(successText.style?.fontWeight, FontWeight.normal);
      });
    });
    
    group('Conditional Lists', () {
      testWidgets('should conditionally render list items', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'showCompleted': false,
                  'todos': [
                    {'id': 1, 'text': 'Buy groceries', 'completed': false},
                    {'id': 2, 'text': 'Walk the dog', 'completed': true},
                    {'id': 3, 'text': 'Write code', 'completed': false},
                    {'id': 4, 'text': 'Read book', 'completed': true},
                  ],
                },
              },
            },
          },
          'content': {
            'type': 'linear',
            'direction': 'vertical',
            'children': [
              {
                'type': 'checkbox',
                'label': 'Show completed',
                'value': '{{showCompleted}}',
                'change': {
                  'type': 'state',
                  'action': 'set',
                  'path': 'showCompleted',
                  'value': '{{event.value}}',
                },
              },
              {
                'type': 'list',
                'shrinkWrap': true,
                'items': '{{todos}}',
                'itemTemplate': {
                  'type': 'conditional',
                  'condition': '{{!item.completed || showCompleted}}',
                  'then': {
                    'type': 'listTile',
                    'title': '{{item.text}}',
                    'leading': {
                      'type': 'icon',
                      'icon': '{{item.completed ? "check_circle" : "radio_button_unchecked"}}',
                      'color': '{{item.completed ? "#4CAF50" : "#9E9E9E"}}',
                    },
                  },
                },
              },
            ],
          },
        });
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: runtime.buildUI(),
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        // Initially should only show incomplete todos
        expect(find.text('Buy groceries'), findsOneWidget);
        expect(find.text('Walk the dog'), findsNothing);
        expect(find.text('Write code'), findsOneWidget);
        expect(find.text('Read book'), findsNothing);
        
        // Check show completed
        await tester.tap(find.byType(Checkbox));
        await tester.pumpAndSettle();
        
        // Should now show all todos
        expect(find.text('Buy groceries'), findsOneWidget);
        expect(find.text('Walk the dog'), findsOneWidget);
        expect(find.text('Write code'), findsOneWidget);
        expect(find.text('Read book'), findsOneWidget);
      });
    });
  });
}