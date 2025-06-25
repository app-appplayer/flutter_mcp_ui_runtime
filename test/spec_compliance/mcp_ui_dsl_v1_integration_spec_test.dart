import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

/// MCP UI DSL v1.0 Integration Test
/// 
/// This test verifies that all components work together correctly
/// to provide a complete MCP UI DSL v1.0 compliant implementation.
void main() {
  group('MCP UI DSL v1.0 Integration Tests', () {
    late MCPUIRuntime runtime;
    
    setUp(() {
      runtime = MCPUIRuntime();
    });
    
    tearDown(() {
      runtime.destroy();
    });
    
    group('Complete Application Flow', () {
      testWidgets('should build a complete interactive form application', (WidgetTester tester) async {
        String? submittedData;
        
        await runtime.initialize({
          'type': 'page',
          'metadata': {
            'title': 'User Registration',
            'description': 'Complete user registration form',
          },
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'form': {
                    'firstName': '',
                    'lastName': '',
                    'email': '',
                    'password': '',
                    'confirmPassword': '',
                    'agreeToTerms': false,
                  },
                  'errors': {},
                  'isSubmitting': false,
                  'isSuccess': false,
                },
              },
            },
          },
          'content': {
            'type': 'linear',
            'direction': 'vertical',
            'padding': {'all': 20},
            'gap': 16,
            'children': [
              {
                'type': 'text',
                'content': 'User Registration',
                'style': {
                  'fontSize': 24,
                  'fontWeight': 'bold',
                },
              },
              {
                'type': 'conditional',
                'condition': '{{isSuccess}}',
                'then': {
                  'type': 'card',
                  'child': {
                    'type': 'linear',
                    'direction': 'vertical',
                    'padding': {'all': 16},
                    'children': [
                      {
                        'type': 'icon',
                        'icon': 'check_circle',
                        'size': 48,
                        'color': '#4CAF50',
                      },
                      {
                        'type': 'text',
                        'content': 'Registration successful!',
                        'style': {
                          'fontSize': 18,
                          'color': '#4CAF50',
                        },
                      },
                    ],
                  },
                },
                'orElse': {
                  'type': 'form',
                  'children': [
                    {
                      'type': 'linear',
                      'direction': 'horizontal',
                      'gap': 16,
                      'children': [
                        {
                          'type': 'box',
                          'flex': 1,
                          'child': {
                            'type': 'textInput',
                            'label': 'First Name',
                            'value': '{{form.firstName}}',
                            'change': {
                              'type': 'state',
                              'action': 'set',
                              'path': 'form.firstName',
                              'value': '{{event.value}}',
                            },
                            'validator': {
                              'type': 'required',
                              'message': 'First name is required',
                            },
                          },
                        },
                        {
                          'type': 'box',
                          'flex': 1,
                          'child': {
                            'type': 'textInput',
                            'label': 'Last Name',
                            'value': '{{form.lastName}}',
                            'change': {
                              'type': 'state',
                              'action': 'set',
                              'path': 'form.lastName',
                              'value': '{{event.value}}',
                            },
                            'validator': {
                              'type': 'required',
                              'message': 'Last name is required',
                            },
                          },
                        },
                      ],
                    },
                    {
                      'type': 'textInput',
                      'label': 'Email',
                      'placeholder': 'user@example.com',
                      'value': '{{form.email}}',
                      'keyboardType': 'emailAddress',
                      'change': {
                        'type': 'state',
                        'action': 'set',
                        'path': 'form.email',
                        'value': '{{event.value}}',
                      },
                      'validator': {
                        'type': 'email',
                        'message': 'Please enter a valid email',
                      },
                    },
                    {
                      'type': 'textInput',
                      'label': 'Password',
                      'obscureText': true,
                      'value': '{{form.password}}',
                      'change': {
                        'type': 'state',
                        'action': 'set',
                        'path': 'form.password',
                        'value': '{{event.value}}',
                      },
                      'validator': {
                        'type': 'minLength',
                        'value': 8,
                        'message': 'Password must be at least 8 characters',
                      },
                    },
                    {
                      'type': 'textInput',
                      'label': 'Confirm Password',
                      'obscureText': true,
                      'value': '{{form.confirmPassword}}',
                      'change': {
                        'type': 'state',
                        'action': 'set',
                        'path': 'form.confirmPassword',
                        'value': '{{event.value}}',
                      },
                      'validator': {
                        'type': 'custom',
                        'validate': '{{value == form.password}}',
                        'message': 'Passwords do not match',
                      },
                    },
                    {
                      'type': 'checkbox',
                      'label': 'I agree to the terms and conditions',
                      'value': '{{form.agreeToTerms}}',
                      'change': {
                        'type': 'state',
                        'action': 'set',
                        'path': 'form.agreeToTerms',
                        'value': '{{event.value}}',
                      },
                    },
                    {
                      'type': 'conditional',
                      'condition': '{{errors.submit}}',
                      'then': {
                        'type': 'text',
                        'content': '{{errors.submit}}',
                        'style': {
                          'color': '#F44336',
                          'fontSize': 14,
                        },
                      },
                    },
                    {
                      'type': 'button',
                      'label': '{{isSubmitting ? "Submitting..." : "Register"}}',
                      'enabled': '{{!isSubmitting && form.agreeToTerms}}',
                      'style': {
                        'width': '100%',
                      },
                      'click': {
                        'type': 'conditional',
                        'condition': '{{form.firstName && form.lastName && form.email && form.password && form.confirmPassword && form.agreeToTerms}}',
                        'then': {
                          'type': 'batch',
                          'actions': [
                            {
                              'type': 'state',
                              'action': 'set',
                              'path': 'isSubmitting',
                              'value': true,
                            },
                            {
                              'type': 'tool',
                              'tool': 'submitRegistration',
                              'params': {
                                'firstName': '{{form.firstName}}',
                                'lastName': '{{form.lastName}}',
                                'email': '{{form.email}}',
                                'password': '{{form.password}}',
                              },
                            },
                          ],
                        },
                        'else': {
                          'type': 'state',
                          'action': 'set',
                          'path': 'errors.submit',
                          'value': 'Please fill all required fields',
                        },
                      },
                    },
                  ],
                },
              },
            ],
          },
        });
        
        // Register the submit handler
        runtime.registerToolExecutor('submitRegistration', (params) async {
          submittedData = params.toString();
          // Simulate API delay
          await Future.delayed(const Duration(milliseconds: 100));
          runtime.stateManager.set('isSubmitting', false);
          runtime.stateManager.set('isSuccess', true);
          return {'success': true};
        });
        
        await tester.pumpWidget(
          MaterialApp(
            home: runtime.buildUI(),
          ),
        );
        await tester.pump();
        
        // Verify initial state
        expect(find.text('User Registration'), findsOneWidget);
        expect(find.text('First Name'), findsOneWidget);
        expect(find.text('Last Name'), findsOneWidget);
        expect(find.text('Email'), findsOneWidget);
        expect(find.text('Password'), findsOneWidget);
        expect(find.text('Confirm Password'), findsOneWidget);
        expect(find.text('I agree to the terms and conditions'), findsOneWidget);
        expect(find.text('Register'), findsOneWidget);
        
        // Button should be disabled initially
        final registerButton = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Register'),
        );
        expect(registerButton.onPressed, isNull);
        
        // Fill the form - find fields by their associated labels
        final firstNameField = find.ancestor(
          of: find.text('First Name'),
          matching: find.byType(TextField),
        );
        final lastNameField = find.ancestor(
          of: find.text('Last Name'),
          matching: find.byType(TextField),
        );
        final emailField = find.ancestor(
          of: find.text('Email'),
          matching: find.byType(TextField),
        );
        final passwordField = find.ancestor(
          of: find.text('Password'),
          matching: find.byType(TextField),
        );
        final confirmPasswordField = find.ancestor(
          of: find.text('Confirm Password'),
          matching: find.byType(TextField),
        );
        
        await tester.enterText(firstNameField, 'John');
        await tester.pump();
        await tester.enterText(lastNameField, 'Doe');
        await tester.pump();
        await tester.enterText(emailField, 'john@example.com');
        await tester.pump();
        await tester.enterText(passwordField, 'password123');
        await tester.pump();
        await tester.enterText(confirmPasswordField, 'password123');
        await tester.pump();
        
        // Check the terms checkbox
        await tester.tap(find.byType(Checkbox));
        await tester.pump();
        
        // Button should now be enabled
        final enabledButton = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Register'),
        );
        expect(enabledButton.onPressed, isNotNull);
        
        // Submit the form
        await tester.tap(find.text('Register'));
        await tester.pump();
        
        // Should show submitting state
        expect(find.text('Submitting...'), findsOneWidget);
        
        // Wait for async operation
        await tester.pump(const Duration(milliseconds: 150));
        
        // Should show success state
        expect(find.text('Registration successful!'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
        
        // Verify submitted data
        expect(submittedData, contains('John'));
        expect(submittedData, contains('Doe'));
        expect(submittedData, contains('john@example.com'));
      });
    });
    
    group('Real-time Dashboard', () {
      testWidgets('should display real-time data updates', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'metadata': {
            'title': 'Dashboard',
          },
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'metrics': {
                    'activeUsers': 0,
                    'totalRevenue': 0,
                    'orderCount': 0,
                    'avgOrderValue': 0,
                  },
                  'recentOrders': [],
                  'lastUpdate': null,
                },
              },
            },
          },
          'content': {
            'type': 'singleChildScrollView',
            'child': {
              'type': 'linear',
              'direction': 'vertical',
              'padding': {'all': 16},
              'gap': 16,
              'children': [
                {
                  'type': 'headerBar',
                'title': 'Dashboard',
                'actions': [
                  {
                    'type': 'button',
                    'label': 'Refresh',
                    'variant': 'icon',
                    'icon': 'refresh',
                    'click': {
                      'type': 'tool',
                      'tool': 'refreshData',
                    },
                  },
                ],
              },
              {
                'type': 'grid',
                'crossAxisCount': 2,
                'mainAxisSpacing': 16,
                'crossAxisSpacing': 16,
                'shrinkWrap': true,
                'children': [
                  {
                    'type': 'card',
                    'child': {
                      'type': 'linear',
                      'direction': 'vertical',
                      'padding': {'all': 16},
                      'children': [
                        {
                          'type': 'text',
                          'content': 'Active Users',
                          'style': {'fontSize': 14, 'color': '#666'},
                        },
                        {
                          'type': 'text',
                          'content': '{{metrics.activeUsers}}',
                          'style': {'fontSize': 32, 'fontWeight': 'bold'},
                        },
                      ],
                    },
                  },
                  {
                    'type': 'card',
                    'child': {
                      'type': 'linear',
                      'direction': 'vertical',
                      'padding': {'all': 16},
                      'children': [
                        {
                          'type': 'text',
                          'content': 'Total Revenue',
                          'style': {'fontSize': 14, 'color': '#666'},
                        },
                        {
                          'type': 'text',
                          'content': '\${{metrics.totalRevenue}}',
                          'style': {'fontSize': 32, 'fontWeight': 'bold'},
                        },
                      ],
                    },
                  },
                  {
                    'type': 'card',
                    'child': {
                      'type': 'linear',
                      'direction': 'vertical',
                      'padding': {'all': 16},
                      'children': [
                        {
                          'type': 'text',
                          'content': 'Orders',
                          'style': {'fontSize': 14, 'color': '#666'},
                        },
                        {
                          'type': 'text',
                          'content': '{{metrics.orderCount}}',
                          'style': {'fontSize': 32, 'fontWeight': 'bold'},
                        },
                      ],
                    },
                  },
                  {
                    'type': 'card',
                    'child': {
                      'type': 'linear',
                      'direction': 'vertical',
                      'padding': {'all': 16},
                      'children': [
                        {
                          'type': 'text',
                          'content': 'Avg Order Value',
                          'style': {'fontSize': 14, 'color': '#666'},
                        },
                        {
                          'type': 'text',
                          'content': '\${{metrics.avgOrderValue}}',
                          'style': {'fontSize': 32, 'fontWeight': 'bold'},
                        },
                      ],
                    },
                  },
                ],
              },
              {
                'type': 'card',
                'child': {
                  'type': 'linear',
                  'direction': 'vertical',
                  'padding': {'all': 16},
                  'children': [
                    {
                      'type': 'text',
                      'content': 'Recent Orders',
                      'style': {'fontSize': 18, 'fontWeight': 'bold'},
                    },
                    {
                      'type': 'conditional',
                      'condition': '{{recentOrders.length > 0}}',
                      'then': {
                        'type': 'list',
                        'items': '{{recentOrders}}',
                        'shrinkWrap': true,
                        'itemTemplate': {
                          'type': 'listTile',
                          'title': 'Order #{{item.id}}',
                          'subtitle': '{{item.customer}} - \${{item.amount}}',
                          'trailing': {
                            'type': 'chip',
                            'label': '{{item.status}}',
                            'backgroundColor': '{{item.status == "completed" ? "#4CAF50" : item.status == "pending" ? "#FF9800" : "#F44336"}}',
                          },
                        },
                      },
                      'orElse': {
                        'type': 'text',
                        'content': 'No recent orders',
                        'style': {'color': '#666'},
                      },
                    },
                  ],
                },
              },
              {
                'type': 'conditional',
                'condition': '{{lastUpdate}}',
                'then': {
                  'type': 'text',
                  'content': 'Last updated: {{lastUpdate}}',
                  'style': {'fontSize': 12, 'color': '#666'},
                },
                },
              ],
            },
          },
        });
        
        // Register data refresh handler
        runtime.registerToolExecutor('refreshData', (_) async {
          // Simulate fetching new data
          runtime.stateManager.set('metrics', {
            'activeUsers': 1234,
            'totalRevenue': 45678.90,
            'orderCount': 89,
            'avgOrderValue': 513.24,
          });
          runtime.stateManager.set('recentOrders', [
            {'id': 1001, 'customer': 'John Doe', 'amount': 250.00, 'status': 'completed'},
            {'id': 1002, 'customer': 'Jane Smith', 'amount': 175.50, 'status': 'pending'},
            {'id': 1003, 'customer': 'Bob Wilson', 'amount': 89.99, 'status': 'cancelled'},
          ]);
          runtime.stateManager.set('lastUpdate', DateTime.now().toString().substring(0, 19));
          return {'success': true};
        });
        
        await tester.pumpWidget(
          MaterialApp(
            home: runtime.buildUI(),
          ),
        );
        await tester.pump();
        
        // Initial state
        expect(find.text('Dashboard'), findsOneWidget); // Title appears in headerBar
        expect(find.text('0'), findsNWidgets(2)); // activeUsers and orderCount
        expect(find.text('\$0'), findsNWidgets(2)); // totalRevenue and avgOrderValue with dollar sign
        expect(find.text('No recent orders'), findsOneWidget);
        
        // Refresh data
        await tester.tap(find.byIcon(Icons.refresh));
        await tester.pumpAndSettle();
        
        // Updated state
        expect(find.text('1234'), findsOneWidget);
        expect(find.text('\$45678.9'), findsOneWidget);
        expect(find.text('89'), findsOneWidget);
        expect(find.text('\$513.24'), findsOneWidget);
        
        // Recent orders - check titles and chips
        expect(find.text('Order #1001'), findsOneWidget);
        expect(find.text('Order #1002'), findsOneWidget);
        expect(find.text('Order #1003'), findsOneWidget);
        
        // Check chip labels
        expect(find.text('completed'), findsOneWidget);
        expect(find.text('pending'), findsOneWidget);
        expect(find.text('cancelled'), findsOneWidget);
        
        // Check subtitles - they are rendered as separate Text widgets
        expect(find.text('John Doe - \$250'), findsOneWidget);
        expect(find.text('Jane Smith - \$175.5'), findsOneWidget);
        expect(find.text('Bob Wilson - \$89.99'), findsOneWidget);
        
        // Last update time
        expect(find.textContaining('Last updated:'), findsOneWidget);
      });
    });
    
    group('Complex Navigation', () {
      testWidgets('should handle multi-step wizard navigation', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'currentStep': 0,
                  'totalSteps': 3,
                  'wizardData': {
                    'personal': {},
                    'address': {},
                    'payment': {},
                  },
                },
              },
            },
          },
          'content': {
            'type': 'linear',
            'direction': 'vertical',
            'children': [
              {
                'type': 'linear',
                'direction': 'horizontal',
                'distribution': 'space-around',
                'padding': {'vertical': 16},
                'children': [
                  {
                    'type': 'chip',
                    'label': 'Personal',
                    'selected': '{{currentStep >= 0}}',
                  },
                  {
                    'type': 'chip',
                    'label': 'Address',
                    'selected': '{{currentStep >= 1}}',
                  },
                  {
                    'type': 'chip',
                    'label': 'Payment',
                    'selected': '{{currentStep >= 2}}',
                  },
                ],
              },
              {
                'type': 'box',
                'flex': 1,
                'child': {
                  'type': 'conditional',
                  'condition': '{{currentStep == 0}}',
                  'then': {
                    'type': 'linear',
                    'direction': 'vertical',
                    'padding': {'all': 16},
                    'children': [
                      {
                        'type': 'text',
                        'content': 'Personal Information',
                        'style': {'fontSize': 20, 'fontWeight': 'bold'},
                      },
                      {
                        'type': 'textInput',
                        'label': 'Full Name',
                        'value': '{{wizardData.personal.name}}',
                        'change': {
                          'type': 'state',
                          'action': 'set',
                          'path': 'wizardData.personal.name',
                          'value': '{{event.value}}',
                        },
                      },
                    ],
                  },
                  'orElse': {
                    'type': 'conditional',
                    'condition': '{{currentStep == 1}}',
                    'then': {
                      'type': 'linear',
                      'direction': 'vertical',
                      'padding': {'all': 16},
                      'children': [
                        {
                          'type': 'text',
                          'content': 'Address Information',
                          'style': {'fontSize': 20, 'fontWeight': 'bold'},
                        },
                        {
                          'type': 'textInput',
                          'label': 'Street Address',
                          'value': '{{wizardData.address.street}}',
                          'change': {
                            'type': 'state',
                            'action': 'set',
                            'path': 'wizardData.address.street',
                            'value': '{{event.value}}',
                          },
                        },
                      ],
                    },
                    'orElse': {
                      'type': 'linear',
                      'direction': 'vertical',
                      'padding': {'all': 16},
                      'children': [
                        {
                          'type': 'text',
                          'content': 'Payment Information',
                          'style': {'fontSize': 20, 'fontWeight': 'bold'},
                        },
                        {
                          'type': 'textInput',
                          'label': 'Card Number',
                          'value': '{{wizardData.payment.cardNumber}}',
                          'change': {
                            'type': 'state',
                            'action': 'set',
                            'path': 'wizardData.payment.cardNumber',
                            'value': '{{event.value}}',
                          },
                        },
                      ],
                    },
                  },
                },
              },
              {
                'type': 'linear',
                'direction': 'horizontal',
                'distribution': 'space-between',
                'padding': {'all': 16},
                'children': [
                  {
                    'type': 'button',
                    'label': 'Previous',
                    'enabled': '{{currentStep > 0}}',
                    'click': {
                      'type': 'state',
                      'action': 'decrement',
                      'path': 'currentStep',
                    },
                  },
                  {
                    'type': 'conditional',
                    'condition': '{{currentStep < totalSteps - 1}}',
                    'then': {
                      'type': 'button',
                      'label': 'Next',
                      'click': {
                        'type': 'state',
                        'action': 'increment',
                        'path': 'currentStep',
                      },
                    },
                    'orElse': {
                      'type': 'button',
                      'label': 'Complete',
                      'style': {
                        'backgroundColor': '#4CAF50',
                      },
                      'click': {
                        'type': 'tool',
                        'tool': 'completeWizard',
                        'params': '{{wizardData}}',
                      },
                    },
                  },
                ],
              },
            ],
          },
        });
        
        await tester.pumpWidget(
          MaterialApp(
            home: runtime.buildUI(),
          ),
        );
        await tester.pump();
        
        // Step 1: Personal Information
        expect(find.text('Personal Information'), findsOneWidget);
        expect(find.text('Full Name'), findsOneWidget);
        expect(find.text('Previous'), findsOneWidget);
        expect(find.text('Next'), findsOneWidget);
        
        // Previous button should be disabled
        final prevButton = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Previous'),
        );
        expect(prevButton.onPressed, isNull);
        
        // Fill personal info and go to next step
        await tester.enterText(find.byType(TextField), 'John Doe');
        await tester.tap(find.text('Next'));
        await tester.pump();
        
        // Step 2: Address Information
        expect(find.text('Address Information'), findsOneWidget);
        expect(find.text('Street Address'), findsOneWidget);
        
        // Previous button should now be enabled
        final prevButton2 = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Previous'),
        );
        expect(prevButton2.onPressed, isNotNull);
        
        // Fill address and go to next step
        await tester.enterText(find.byType(TextField), '123 Main St');
        await tester.tap(find.text('Next'));
        await tester.pump();
        
        // Step 3: Payment Information
        expect(find.text('Payment Information'), findsOneWidget);
        expect(find.text('Card Number'), findsOneWidget);
        expect(find.text('Complete'), findsOneWidget);
        
        // Fill payment info
        await tester.enterText(find.byType(TextField), '4111111111111111');
        
        // Verify we can navigate back
        await tester.tap(find.text('Previous'));
        await tester.pump();
        expect(find.text('Address Information'), findsOneWidget);
        
        await tester.tap(find.text('Previous'));
        await tester.pump();
        expect(find.text('Personal Information'), findsOneWidget);
        
        // Verify data persistence
        expect(find.widgetWithText(TextField, 'John Doe'), findsOneWidget);
      });
    });
  });
}