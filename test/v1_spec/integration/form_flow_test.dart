import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

/// MCP UI DSL v1.0 Form Flow Integration Tests
/// 
/// Tests complete form scenarios according to MCP UI DSL v1.0 specification.
/// Reference: Spec Section 8 - Form Handling
void main() {
  group('MCP UI DSL v1.0 - Form Flow Integration', () {
    late MCPUIRuntime runtime;
    
    setUp(() {
      runtime = MCPUIRuntime();
    });
    
    tearDown(() {
      runtime.destroy();
    });
    
    testWidgets('should handle complete user registration form', (WidgetTester tester) async {
      Map<String, dynamic>? submittedData;
      
      await runtime.initialize({
        'type': 'page',
        'metadata': {
          'title': 'User Registration',
          'description': 'MCP UI DSL v1.0 Form Example',
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
                  'age': 18,
                  'country': 'US',
                  'agreeToTerms': false,
                  'newsletter': false,
                },
                'validation': {
                  'errors': {},
                  'isValid': false,
                },
                'ui': {
                  'isSubmitting': false,
                  'submitResult': null,
                },
              },
            },
          },
        },
        'content': {
          'type': 'form',
          'children': [
              {
                'type': 'text',
                'content': 'Create Your Account',
              'style': {
                'fontSize': 24,
                'fontWeight': 'bold',
                'marginBottom': 20,
              },
            },
            // Personal Information Section
            {
              'type': 'text',
              'content': 'Personal Information',
              'style': {
                'fontSize': 18,
                'fontWeight': 'w600',
                'marginTop': 16,
                'marginBottom': 12,
              },
            },
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
                    'placeholder': 'John',
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
                    'placeholder': 'Doe',
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
            // Account Information Section
            {
              'type': 'text',
              'content': 'Account Information',
              'style': {
                'fontSize': 18,
                'fontWeight': 'w600',
                'marginTop': 16,
                'marginBottom': 12,
              },
            },
            {
              'type': 'textInput',
              'label': 'Email Address',
              'value': '{{form.email}}',
              'placeholder': 'john.doe@example.com',
              'keyboardType': 'emailAddress',
              'change': {
                'type': 'state',
                'action': 'set',
                'path': 'form.email',
                'value': '{{event.value}}',
              },
              'validator': {
                'type': 'email',
                'message': 'Please enter a valid email address',
              },
            },
            {
              'type': 'textInput',
              'label': 'Password',
              'value': '{{form.password}}',
              'placeholder': 'Min 8 characters',
              'obscureText': true,
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
              'value': '{{form.confirmPassword}}',
              'obscureText': true,
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
            // Additional Information
            {
              'type': 'text',
              'content': 'Additional Information',
              'style': {
                'fontSize': 18,
                'fontWeight': 'w600',
                'marginTop': 16,
                'marginBottom': 12,
              },
            },
            {
              'type': 'linear',
              'direction': 'horizontal',
              'gap': 16,
              'alignment': 'center',
              'children': [
                {
                  'type': 'text',
                  'content': 'Age:',
                },
                {
                  'type': 'slider',
                  'value': '{{form.age}}',
                  'min': 13,
                  'max': 100,
                  'divisions': 87,
                  'label': '{{form.age}}',
                  'change': {
                    'type': 'state',
                    'action': 'set',
                    'path': 'form.age',
                    'value': '{{event.value}}',
                  },
                },
                {
                  'type': 'text',
                  'content': '{{form.age}} years',
                  'style': {'fontWeight': 'bold'},
                },
              ],
            },
            {
              'type': 'select',
              'label': 'Country',
              'value': '{{form.country}}',
              'items': [
                {'value': 'US', 'label': 'United States'},
                {'value': 'UK', 'label': 'United Kingdom'},
                {'value': 'CA', 'label': 'Canada'},
                {'value': 'AU', 'label': 'Australia'},
                {'value': 'OTHER', 'label': 'Other'},
              ],
              'change': {
                'type': 'state',
                'action': 'set',
                'path': 'form.country',
                'value': '{{event.value}}',
              },
            },
            // Terms and Conditions
            {
              'type': 'box',
              'marginTop': 20,
              'child': {
                'type': 'linear',
                'direction': 'vertical',
                'gap': 12,
                'children': [
                  {
                    'type': 'checkbox',
                    'label': 'I agree to the Terms and Conditions',
                    'value': '{{form.agreeToTerms}}',
                    'change': {
                      'type': 'state',
                      'action': 'set',
                      'path': 'form.agreeToTerms',
                      'value': '{{event.value}}',
                    },
                  },
                  {
                    'type': 'checkbox',
                    'label': 'Send me newsletter and updates',
                    'value': '{{form.newsletter}}',
                    'change': {
                      'type': 'state',
                      'action': 'set',
                      'path': 'form.newsletter',
                      'value': '{{event.value}}',
                    },
                  },
                ],
              },
            },
            // Error Display
            {
              'type': 'conditional',
              'condition': '{{validation.errors && Object.keys(validation.errors).length > 0}}',
              'then': {
                'type': 'box',
                'marginTop': 16,
                'padding': {'all': 12},
                'backgroundColor': '#FFEBEE',
                'borderRadius': 8,
                'child': {
                  'type': 'text',
                  'content': 'Please fix the errors above',
                  'style': {'color': '#F44336'},
                },
              },
            },
            // Submit Button
            {
              'type': 'box',
              'marginTop': 24,
              'child': {
                'type': 'button',
                'label': '{{ui.isSubmitting ? "Creating Account..." : "Create Account"}}',
                'enabled': '{{form.agreeToTerms && !ui.isSubmitting}}',
                'click': {
                  'type': 'conditional',
                  'condition': '{{form.firstName != "" && form.lastName != "" && form.email != "" && form.password != "" && form.confirmPassword != "" && form.password == form.confirmPassword}}',
                  'then': {
                    'type': 'batch',
                    'actions': [
                      {
                        'type': 'state',
                        'action': 'set',
                        'path': 'ui.isSubmitting',
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
                          'age': '{{form.age}}',
                          'country': '{{form.country}}',
                          'newsletter': '{{form.newsletter}}',
                        },
                        'onSuccess': {
                          'type': 'batch',
                          'actions': [
                            {
                              'type': 'state',
                              'action': 'set',
                              'path': 'ui.isSubmitting',
                              'value': false,
                            },
                            {
                              'type': 'state',
                              'action': 'set',
                              'path': 'success',
                              'value': true,
                            },
                            {
                              'type': 'state',
                              'action': 'set',
                              'path': 'message',
                              'value': 'Registration successful',
                            },
                            {
                              'type': 'state',
                              'action': 'set',
                              'path': 'userId',
                              'value': 'user123',
                            },
                          ],
                        },
                      },
                    ],
                  },
                  'else': {
                    'type': 'state',
                    'action': 'set',
                    'path': 'validation.errors.form',
                    'value': 'Please fill all required fields correctly',
                  },
                },
              },
            },
            // Success Message
            {
              'type': 'conditional',
              'condition': '{{success == true}}',
              'then': {
                'type': 'box',
                'marginTop': 16,
                'padding': {'all': 16},
                'backgroundColor': '#E8F5E9',
                'borderRadius': 8,
                'child': {
                  'type': 'linear',
                  'direction': 'vertical',
                  'gap': 8,
                  'alignment': 'center',
                  'children': [
                    {
                      'type': 'icon',
                      'icon': 'check_circle',
                      'size': 48,
                      'color': '#4CAF50',
                    },
                    {
                      'type': 'text',
                      'content': '{{message}}',
                      'style': {
                        'fontSize': 18,
                        'fontWeight': 'bold',
                        'color': '#2E7D32',
                      },
                    },
                    {
                      'type': 'text',
                      'content': 'User ID: {{userId}}',
                      'style': {'color': '#666'},
                    },
                  ],
                },
              },
            },
          ],
        },
      });
      
      runtime.registerToolExecutor('submitRegistration', (params) async {
        submittedData = params;
        return {
          'success': true,
          'userId': 'user123',
          'message': 'Registration successful',
        };
      });
      
      // Set larger viewport for long form
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: runtime.buildUI()),
        ),
      );
      await tester.pumpAndSettle();
      
      // Verify form renders correctly
      expect(find.text('Create Your Account'), findsOneWidget);
      expect(find.text('Personal Information'), findsOneWidget);
      expect(find.text('Account Information'), findsOneWidget);
      expect(find.text('Additional Information'), findsOneWidget);
      
      // Fill out the form
      await tester.enterText(find.byType(TextField).at(0), 'John');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), 'Doe');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(2), 'john.doe@example.com');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(3), 'password123');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(4), 'password123');
      await tester.pumpAndSettle();
      
      // Adjust age slider
      await tester.drag(find.byType(Slider), const Offset(50, 0));
      await tester.pumpAndSettle();
      
      // Select country
      await tester.tap(find.byType(DropdownButton<dynamic>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Canada').last);
      await tester.pumpAndSettle();
      
      // Check terms and newsletter
      final termsCheckbox = find.byType(Checkbox).at(0);
      final newsletterCheckbox = find.byType(Checkbox).at(1);
      
      await tester.tap(termsCheckbox);
      await tester.tap(newsletterCheckbox);
      await tester.pumpAndSettle();
      
      // Submit the form
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();
      
      // Verify success state
      expect(find.text('Registration successful'), findsOneWidget);
      expect(find.text('User ID: user123'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      
      // Verify submitted data
      expect(submittedData, isNotNull);
      expect(submittedData!['firstName'], 'John');
      expect(submittedData!['lastName'], 'Doe');
      expect(submittedData!['email'], 'john.doe@example.com');
      expect(submittedData!['country'], 'CA');
      expect(submittedData!['newsletter'], true);
    });
    
    testWidgets('should handle form validation errors', (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'runtime': {
          'services': {
            'state': {
              'initialState': {
                'email': '',
                'password': '',
                'errors': {},
              },
            },
          },
        },
        'content': {
          'type': 'form',
          'children': [
            {
              'type': 'textInput',
              'label': 'Email',
              'value': '{{email}}',
              'change': {
                'type': 'state',
                'action': 'set',
                'path': 'email',
                'value': '{{event.value}}',
              },
              'validation': [
                {'type': 'email', 'message': 'Invalid email format'},
              ],
              'error': '{{errors.email}}',
            },
            {
              'type': 'textInput',
              'label': 'Password',
              'value': '{{password}}',
              'obscureText': true,
              'change': {
                'type': 'state',
                'action': 'set',
                'path': 'password',
                'value': '{{event.value}}',
              },
              'validation': [
                {'type': 'minLength', 'value': 8, 'message': 'Password too short'},
              ],
              'error': '{{errors.password}}',
            },
            {
              'type': 'button',
              'label': 'Submit',
              'click': {
                'type': 'batch',
                'actions': [
                  {
                    'type': 'conditional',
                    'condition': '{{!email.contains("@")}}',
                    'then': {
                      'type': 'state',
                      'action': 'set',
                      'path': 'errors.email',
                      'value': 'Invalid email format',
                    },
                    'else': {
                      'type': 'state',
                      'action': 'set',
                      'path': 'errors.email',
                      'value': null,
                    },
                  },
                  {
                    'type': 'conditional',
                    'condition': '{{password.length < 8}}',
                    'then': {
                      'type': 'state',
                      'action': 'set',
                      'path': 'errors.password',
                      'value': 'Password too short',
                    },
                    'else': {
                      'type': 'state',
                      'action': 'set',
                      'path': 'errors.password',
                      'value': null,
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
          home: Scaffold(body: runtime.buildUI()),
        ),
      );
      await tester.pumpAndSettle();
      
      // Submit with invalid data
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      
      // Should show validation errors
      expect(find.text('Invalid email format'), findsOneWidget);
      expect(find.text('Password too short'), findsOneWidget);
      
      // Fix email but not password
      await tester.enterText(find.byType(TextField).first, 'test@example.com');
      await tester.pumpAndSettle();
      
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      
      // Email error should be gone, password error remains
      expect(find.text('Invalid email format'), findsNothing);
      expect(find.text('Password too short'), findsOneWidget);
    });
  });
}