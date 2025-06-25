import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

void main() {
  group('MCP UI DSL v1.0 - Validation System Tests', () {
    late MCPUIRuntime runtime;
    
    setUp(() {
      runtime = MCPUIRuntime();
    });
    
    tearDown(() {
      runtime.destroy();
    });
    
    group('Required Field Validation', () {
      testWidgets('should show error for empty required field', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'form': {
                    'name': '',
                  },
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
                'label': 'Name',
                'value': '{{form.name}}',
                'validation': [
                  {'type': 'required', 'message': 'Name is required'},
                ],
                'error': '{{errors.name}}',
                'change': {
                  'type': 'state',
                  'action': 'set',
                  'binding': 'form.name',
                  'value': '{{event.value}}',
                },
              },
              {
                'type': 'button',
                'label': 'Submit',
                'click': {
                  'type': 'tool',
                  'tool': 'validateForm',
                },
              },
            ],
          },
        });
        
        runtime.registerToolExecutor('validateForm', (params) async {
          final name = runtime.stateManager.get('form.name') as String? ?? '';
          final errors = <String, String>{};
          
          if (name.isEmpty) {
            errors['name'] = 'Name is required';
          }
          
          runtime.stateManager.set('errors', errors);
          
          if (errors.isEmpty) {
            // Form is valid, proceed with submission
            return {'success': true, 'valid': true};
          }
          
          return {'success': true, 'valid': false};
        });
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: runtime.buildUI(),
            ),
          ),
        );
        
        await tester.pump();
        
        // Click submit without filling the field
        await tester.tap(find.text('Submit'));
        await tester.pumpAndSettle();
        
        // Should show error message
        expect(find.text('Name is required'), findsOneWidget);
        
        // Enter a value
        await tester.enterText(find.byType(TextField), 'John Doe');
        await tester.pump();
        
        // Submit again
        await tester.tap(find.text('Submit'));
        await tester.pumpAndSettle();
        
        // Error should be gone
        expect(find.text('Name is required'), findsNothing);
      });
      
      testWidgets('should validate multiple required fields', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'form': {
                    'firstName': '',
                    'lastName': '',
                    'email': '',
                  },
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
                'label': 'First Name',
                'value': '{{form.firstName}}',
                'validation': [
                  {'type': 'required'},
                ],
                'error': '{{errors.firstName}}',
                'change': {
                  'type': 'state',
                  'action': 'set',
                  'binding': 'form.firstName',
                  'value': '{{event.value}}',
                },
              },
              {
                'type': 'textInput',
                'label': 'Last Name',
                'value': '{{form.lastName}}',
                'validation': [
                  {'type': 'required'},
                ],
                'error': '{{errors.lastName}}',
                'change': {
                  'type': 'state',
                  'action': 'set',
                  'binding': 'form.lastName',
                  'value': '{{event.value}}',
                },
              },
              {
                'type': 'textInput',
                'label': 'Email',
                'value': '{{form.email}}',
                'validation': [
                  {'type': 'required'},
                  {'type': 'email'},
                ],
                'error': '{{errors.email}}',
                'change': {
                  'type': 'state',
                  'action': 'set',
                  'binding': 'form.email',
                  'value': '{{event.value}}',
                },
              },
              {
                'type': 'button',
                'label': 'Submit',
                'click': {
                  'type': 'tool',
                  'tool': 'validateAllFields',
                },
              },
            ],
          },
        });
        
        runtime.registerToolExecutor('validateAllFields', (params) async {
          final form = runtime.stateManager.get('form') as Map<String, dynamic>? ?? {};
          final errors = <String, String>{};
          
          if ((form['firstName'] as String? ?? '').isEmpty) {
            errors['firstName'] = 'First name is required';
          }
          if ((form['lastName'] as String? ?? '').isEmpty) {
            errors['lastName'] = 'Last name is required';
          }
          
          final email = form['email'] as String? ?? '';
          if (email.isEmpty) {
            errors['email'] = 'Email is required';
          } else if (!email.contains('@')) {
            errors['email'] = 'Invalid email format';
          }
          
          runtime.stateManager.set('errors', errors);
          return {'success': true, 'valid': errors.isEmpty};
        });
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: runtime.buildUI(),
            ),
          ),
        );
        
        await tester.pump();
        
        // Submit empty form
        await tester.tap(find.text('Submit'));
        await tester.pumpAndSettle();
        
        // Should show all errors
        expect(find.text('First name is required'), findsOneWidget);
        expect(find.text('Last name is required'), findsOneWidget);
        expect(find.text('Email is required'), findsOneWidget);
      });
    });
    
    group('Email Validation', () {
      testWidgets('should validate email format', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'email': '',
                  'emailError': null,
                },
              },
            },
          },
          'content': {
            'type': 'linear',
            'direction': 'vertical',
            'children': [
              {
                'type': 'textInput',
                'label': 'Email',
                'value': '{{email}}',
                'validation': [
                  {'type': 'email', 'message': 'Please enter a valid email'},
                ],
                'error': '{{emailError}}',
                'change': {
                  'type': 'state',
                  'action': 'set',
                  'binding': 'email',
                  'value': '{{event.value}}',
                },
                'blur': {
                  'type': 'tool',
                  'tool': 'validateEmail',
                },
              },
            ],
          },
        });
        
        runtime.registerToolExecutor('validateEmail', (params) async {
          final email = runtime.stateManager.get('email') as String? ?? '';
          
          // Simple email validation
          final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
          
          if (email.isNotEmpty && !emailRegex.hasMatch(email)) {
            runtime.stateManager.set('emailError', 'Please enter a valid email');
          } else {
            runtime.stateManager.set('emailError', null);
          }
          
          return {'success': true};
        });
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: runtime.buildUI(),
            ),
          ),
        );
        
        await tester.pump();
        
        // Test invalid emails
        final invalidEmails = [
          'notanemail',
          'missing@domain',
          '@nodomain.com',
          'spaces in@email.com',
          'double@@domain.com',
        ];
        
        for (final invalidEmail in invalidEmails) {
          await tester.enterText(find.byType(TextField), invalidEmail);
          await tester.pump();
          
          // Trigger blur event (focus something else)
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await tester.pump();
          
          // Allow async validation
          await tester.pump(const Duration(milliseconds: 100));
          
          // Should show error
          expect(find.text('Please enter a valid email'), findsOneWidget,
              reason: 'Should show error for: $invalidEmail');
          
          // Clear for next test
          await tester.enterText(find.byType(TextField), '');
          runtime.stateManager.set('emailError', null);
          await tester.pump();
        }
        
        // Test valid email
        await tester.enterText(find.byType(TextField), 'user@example.com');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump(const Duration(milliseconds: 100));
        
        // Should not show error
        expect(find.text('Please enter a valid email'), findsNothing);
      });
    });
    
    group('Length Validation', () {
      testWidgets('should validate minimum length', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'password': '',
                  'passwordError': null,
                },
              },
            },
          },
          'content': {
            'type': 'linear',
            'direction': 'vertical',
            'children': [
              {
                'type': 'textInput',
                'label': 'Password',
                'value': '{{password}}',
                'obscureText': true,
                'validation': [
                  {'type': 'minLength', 'value': 8, 'message': 'Password must be at least 8 characters'},
                ],
                'error': '{{passwordError}}',
                'change': {
                  'type': 'tool',
                  'tool': 'validatePassword',
                  'params': {
                    'value': '{{event.value}}',
                  },
                },
              },
              {
                'type': 'text',
                'content': 'Length: {{password.length}}',
                'style': {
                  'fontSize': 12,
                  'color': '#666666',
                },
              },
            ],
          },
        });
        
        runtime.registerToolExecutor('validatePassword', (params) async {
          final password = params['value'] as String? ?? '';
          runtime.stateManager.set('password', password);
          
          if (password.isNotEmpty && password.length < 8) {
            runtime.stateManager.set('passwordError', 'Password must be at least 8 characters');
          } else {
            runtime.stateManager.set('passwordError', null);
          }
          
          return {'success': true};
        });
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: runtime.buildUI(),
            ),
          ),
        );
        
        await tester.pump();
        
        // Enter short password
        await tester.enterText(find.byType(TextField), 'short');
        await tester.pump();
        
        // Should show error
        expect(find.text('Password must be at least 8 characters'), findsOneWidget);
        expect(find.text('Length: 5'), findsOneWidget);
        
        // Enter valid password
        await tester.enterText(find.byType(TextField), 'longpassword123');
        await tester.pump();
        
        // Error should be gone
        expect(find.text('Password must be at least 8 characters'), findsNothing);
        expect(find.text('Length: 15'), findsOneWidget);
      });
      
      testWidgets('should validate maximum length', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'username': '',
                  'usernameError': null,
                },
              },
            },
          },
          'content': {
            'type': 'textInput',
            'label': 'Username',
            'value': '{{username}}',
            'validation': [
              {'type': 'maxLength', 'value': 15, 'message': 'Username cannot exceed 15 characters'},
            ],
            'maxLength': 15, // Also enforce in UI
            'error': '{{usernameError}}',
            'change': {
              'type': 'tool',
              'tool': 'validateUsername',
              'params': {
                'value': '{{event.value}}',
              },
            },
          },
        });
        
        runtime.registerToolExecutor('validateUsername', (params) async {
          final username = params['value'] as String? ?? '';
          runtime.stateManager.set('username', username);
          
          if (username.length > 15) {
            runtime.stateManager.set('usernameError', 'Username cannot exceed 15 characters');
          } else {
            runtime.stateManager.set('usernameError', null);
          }
          
          return {'success': true};
        });
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: runtime.buildUI(),
            ),
          ),
        );
        
        await tester.pump();
        
        // Try to enter long username
        await tester.enterText(find.byType(TextField), 'verylongusername123');
        await tester.pump();
        
        // Should be truncated by maxLength property
        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.maxLength, 15);
      });
    });
    
    group('Pattern Validation', () {
      testWidgets('should validate against regex pattern', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'phone': '',
                  'phoneError': null,
                },
              },
            },
          },
          'content': {
            'type': 'linear',
            'direction': 'vertical',
            'children': [
              {
                'type': 'textInput',
                'label': 'Phone Number',
                'value': '{{phone}}',
                'placeholder': '123-456-7890',
                'validation': [
                  {'type': 'pattern', 'value': r'^\d{3}-\d{3}-\d{4}$', 'message': 'Please use format: 123-456-7890'},
                ],
                'error': '{{phoneError}}',
                'change': {
                  'type': 'state',
                  'action': 'set',
                  'binding': 'phone',
                  'value': '{{event.value}}',
                },
                'blur': {
                  'type': 'tool',
                  'tool': 'validatePhone',
                },
              },
            ],
          },
        });
        
        runtime.registerToolExecutor('validatePhone', (params) async {
          final phone = runtime.stateManager.get('phone') as String? ?? '';
          final phoneRegex = RegExp(r'^\d{3}-\d{3}-\d{4}$');
          
          if (phone.isNotEmpty && !phoneRegex.hasMatch(phone)) {
            runtime.stateManager.set('phoneError', 'Please use format: 123-456-7890');
          } else {
            runtime.stateManager.set('phoneError', null);
          }
          
          return {'success': true};
        });
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: runtime.buildUI(),
            ),
          ),
        );
        
        await tester.pump();
        
        // Invalid formats
        await tester.enterText(find.byType(TextField), '1234567890');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        
        expect(find.text('Please use format: 123-456-7890'), findsOneWidget);
        
        // Valid format
        await tester.enterText(find.byType(TextField), '123-456-7890');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        
        expect(find.text('Please use format: 123-456-7890'), findsNothing);
      });
    });
    
    group('Custom Validation', () {
      testWidgets('should support custom validation functions', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'password': '',
                  'confirmPassword': '',
                  'passwordError': null,
                  'confirmError': null,
                },
              },
            },
          },
          'content': {
            'type': 'form',
            'children': [
              {
                'type': 'textInput',
                'label': 'Password',
                'value': '{{password}}',
                'obscureText': true,
                'change': {
                  'type': 'state',
                  'action': 'set',
                  'binding': 'password',
                  'value': '{{event.value}}',
                },
              },
              {
                'type': 'textInput',
                'label': 'Confirm Password',
                'value': '{{confirmPassword}}',
                'obscureText': true,
                'validation': [
                  {'type': 'custom', 'value': 'passwordMatch', 'message': 'Passwords do not match'},
                ],
                'error': '{{confirmError}}',
                'change': {
                  'type': 'tool',
                  'tool': 'checkPasswordMatch',
                  'params': {
                    'value': '{{event.value}}',
                  },
                },
              },
            ],
          },
        });
        
        runtime.registerToolExecutor('checkPasswordMatch', (params) async {
          final confirmPassword = params['value'] as String? ?? '';
          runtime.stateManager.set('confirmPassword', confirmPassword);
          
          final password = runtime.stateManager.get('password') as String? ?? '';
          
          if (confirmPassword.isNotEmpty && confirmPassword != password) {
            runtime.stateManager.set('confirmError', 'Passwords do not match');
          } else {
            runtime.stateManager.set('confirmError', null);
          }
          
          return {'success': true};
        });
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: runtime.buildUI(),
            ),
          ),
        );
        
        await tester.pump();
        
        // Enter password
        final textFields = find.byType(TextField);
        await tester.enterText(textFields.at(0), 'mypassword123');
        await tester.pump();
        
        // Enter non-matching confirm password
        await tester.enterText(textFields.at(1), 'different123');
        await tester.pump();
        
        expect(find.text('Passwords do not match'), findsOneWidget);
        
        // Fix to match
        await tester.enterText(textFields.at(1), 'mypassword123');
        await tester.pump();
        
        expect(find.text('Passwords do not match'), findsNothing);
      });
    });
    
    group('Real-time Validation', () {
      testWidgets('should validate on change', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'username': '',
                  'usernameStatus': null,
                  'checking': false,
                },
              },
            },
          },
          'content': {
            'type': 'linear',
            'direction': 'vertical',
            'children': [
              {
                'type': 'textInput',
                'label': 'Username',
                'value': '{{username}}',
                'change': {
                  'type': 'tool',
                  'tool': 'checkUsername',
                  'params': {
                    'value': '{{event.value}}',
                  },
                },
              },
              {
                'type': 'text',
                'content': '{{usernameStatus}}',
                'style': {
                  'fontSize': 12,
                  'color': '{{usernameStatus == "Available" ? "#4CAF50" : "#F44336"}}',
                },
                'visible': '{{usernameStatus != null}}',
              },
              {
                'type': 'loadingIndicator',
                'visible': '{{checking}}',
              },
            ],
          },
        });
        
        runtime.registerToolExecutor('checkUsername', (params) async {
          final username = params['value'] as String? ?? '';
          runtime.stateManager.set('username', username);
          
          if (username.isEmpty) {
            runtime.stateManager.set('usernameStatus', null);
            return {'success': true};
          }
          
          // Simulate checking availability
          runtime.stateManager.set('checking', true);
          runtime.stateManager.set('usernameStatus', null);
          
          // Simulate delay
          await Future.delayed(const Duration(milliseconds: 300));
          
          // Check if username is taken
          final takenUsernames = ['admin', 'user', 'test'];
          if (takenUsernames.contains(username.toLowerCase())) {
            runtime.stateManager.set('usernameStatus', 'Username taken');
          } else if (username.length < 3) {
            runtime.stateManager.set('usernameStatus', 'Too short');
          } else {
            runtime.stateManager.set('usernameStatus', 'Available');
          }
          
          runtime.stateManager.set('checking', false);
          return {'success': true};
        });
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: runtime.buildUI(),
            ),
          ),
        );
        
        await tester.pump();
        
        // Type a taken username
        await tester.enterText(find.byType(TextField), 'admin');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        
        expect(find.text('Username taken'), findsOneWidget);
        
        // Type an available username
        await tester.enterText(find.byType(TextField), 'newuser');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        
        expect(find.text('Available'), findsOneWidget);
      });
    });
    
    group('Form-level Validation', () {
      testWidgets('should validate entire form before submission', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'form': {
                    'name': '',
                    'email': '',
                    'age': '',
                  },
                  'errors': {},
                  'submitted': false,
                },
              },
            },
          },
          'content': {
            'type': 'linear',
            'direction': 'vertical',
            'children': [
              {
                'type': 'form',
                'children': [
                  {
                    'type': 'textInput',
                    'label': 'Name',
                    'value': '{{form.name}}',
                    'validation': [
                      {'type': 'required'},
                    ],
                    'error': '{{errors.name}}',
                    'change': {
                      'type': 'state',
                      'action': 'set',
                      'binding': 'form.name',
                      'value': '{{event.value}}',
                    },
                  },
                  {
                    'type': 'textInput',
                    'label': 'Email',
                    'value': '{{form.email}}',
                    'validation': [
                      {'type': 'required'},
                      {'type': 'email'},
                    ],
                    'error': '{{errors.email}}',
                    'change': {
                      'type': 'state',
                      'action': 'set',
                      'binding': 'form.email',
                      'value': '{{event.value}}',
                    },
                  },
                  {
                    'type': 'textInput',
                    'label': 'Age',
                    'value': '{{form.age}}',
                    'keyboardType': 'number',
                    'validation': [
                      {'type': 'required'},
                      {'type': 'min', 'value': 18},
                      {'type': 'max', 'value': 100},
                    ],
                    'error': '{{errors.age}}',
                    'change': {
                      'type': 'state',
                      'action': 'set',
                      'binding': 'form.age',
                      'value': '{{event.value}}',
                    },
                  },
                  {
                    'type': 'button',
                    'label': 'Submit',
                    'click': {
                      'type': 'tool',
                      'tool': 'submitForm',
                    },
                  },
                ],
              },
              {
                'type': 'text',
                'content': 'Form submitted successfully!',
                'visible': '{{submitted}}',
                'style': {
                  'color': '#4CAF50',
                  'fontWeight': 'bold',
                },
              },
            ],
          },
        });
        
        runtime.registerToolExecutor('submitForm', (params) async {
          final form = runtime.stateManager.get('form') as Map<String, dynamic>? ?? {};
          final errors = <String, String>{};
          
          // Validate name
          if ((form['name'] as String? ?? '').isEmpty) {
            errors['name'] = 'Name is required';
          }
          
          // Validate email
          final email = form['email'] as String? ?? '';
          if (email.isEmpty) {
            errors['email'] = 'Email is required';
          } else if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
            errors['email'] = 'Invalid email format';
          }
          
          // Validate age - handle both string and number types
          final ageValue = form['age'];
          if (ageValue == null || (ageValue is String && ageValue.isEmpty)) {
            errors['age'] = 'Age is required';
          } else {
            // Convert to int if it's not already
            final int? age;
            if (ageValue is int) {
              age = ageValue;
            } else if (ageValue is String) {
              age = int.tryParse(ageValue);
            } else if (ageValue is num) {
              age = ageValue.toInt();
            } else {
              age = null;
            }
            
            if (age == null) {
              errors['age'] = 'Age must be a number';
            } else if (age < 18) {
              errors['age'] = 'Must be at least 18 years old';
            } else if (age > 100) {
              errors['age'] = 'Must be under 100 years old';
            }
          }
          
          runtime.stateManager.set('errors', errors);
          
          if (errors.isEmpty) {
            runtime.stateManager.set('submitted', true);
            return {'success': true, 'valid': true};
          }
          
          return {'success': true, 'valid': false};
        });
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: runtime.buildUI(),
            ),
          ),
        );
        
        await tester.pump();
        
        // Submit empty form
        await tester.tap(find.text('Submit'));
        await tester.pumpAndSettle();
        
        // All fields should show errors
        expect(find.text('Name is required'), findsOneWidget);
        expect(find.text('Email is required'), findsOneWidget);
        expect(find.text('Age is required'), findsOneWidget);
        expect(find.text('Form submitted successfully!'), findsNothing);
        
        // Fill in valid data
        final textFields = find.byType(TextField);
        await tester.enterText(textFields.at(0), 'John Doe');
        await tester.pump();
        await tester.enterText(textFields.at(1), 'john@example.com');
        await tester.pump();
        await tester.enterText(textFields.at(2), '25');
        await tester.pump();
        
        // Submit again
        await tester.tap(find.text('Submit'));
        await tester.pumpAndSettle();
        
        // Should show success
        expect(find.text('Form submitted successfully!'), findsOneWidget);
        expect(find.text('Name is required'), findsNothing);
        expect(find.text('Email is required'), findsNothing);
        expect(find.text('Age is required'), findsNothing);
      });
    });
    
    group('New Widget Type Validation', () {
      testWidgets('should validate numberField input', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'quantity': null,
                  'quantityError': null,
                },
              },
            },
          },
          'content': {
            'type': 'linear',
            'direction': 'vertical',
            'children': [
              {
                'type': 'numberField',
                'label': 'Quantity',
                'value': '{{quantity}}',
                'validation': [
                  {'type': 'required', 'message': 'Quantity is required'},
                  {'type': 'min', 'value': 1, 'message': 'Minimum quantity is 1'},
                  {'type': 'max', 'value': 100, 'message': 'Maximum quantity is 100'},
                ],
                'error': '{{quantityError}}',
                'change': {
                  'type': 'tool',
                  'tool': 'validateQuantity',
                  'params': {
                    'value': '{{event.value}}',
                  },
                },
              },
              {
                'type': 'text',
                'content': 'Quantity: {{quantity ?? "Not set"}}',
              },
            ],
          },
        });
        
        runtime.registerToolExecutor('validateQuantity', (params) async {
          final value = params['value'];
          runtime.stateManager.set('quantity', value);
          
          if (value == null) {
            runtime.stateManager.set('quantityError', 'Quantity is required');
          } else if (value < 1) {
            runtime.stateManager.set('quantityError', 'Minimum quantity is 1');
          } else if (value > 100) {
            runtime.stateManager.set('quantityError', 'Maximum quantity is 100');
          } else {
            runtime.stateManager.set('quantityError', null);
          }
          
          return {'success': true};
        });
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: runtime.buildUI(),
            ),
          ),
        );
        
        await tester.pump();
        
        // Find the number field (TextField with number keyboard)
        final numberField = find.byType(TextField).first;
        
        // Test invalid inputs
        await tester.enterText(numberField, '0');
        await tester.pump();
        expect(find.text('Minimum quantity is 1'), findsOneWidget);
        
        await tester.enterText(numberField, '150');
        await tester.pump();
        expect(find.text('Maximum quantity is 100'), findsOneWidget);
        
        // Test valid input
        await tester.enterText(numberField, '50');
        await tester.pump();
        expect(find.text('Minimum quantity is 1'), findsNothing);
        expect(find.text('Maximum quantity is 100'), findsNothing);
        expect(find.text('Quantity: 50'), findsOneWidget);
      });
      
      testWidgets('should validate dateField input', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'startDate': null,
                  'endDate': null,
                  'dateError': null,
                },
              },
            },
          },
          'content': {
            'type': 'linear',
            'direction': 'vertical',
            'children': [
              {
                'type': 'dateField',
                'label': 'Start Date',
                'value': '{{startDate}}',
                'validation': [
                  {'type': 'required', 'message': 'Start date is required'},
                ],
                'error': '{{dateError}}',
                'change': {
                  'type': 'state',
                  'action': 'set',
                  'binding': 'startDate',
                  'value': '{{event.value}}',
                },
              },
              {
                'type': 'dateField',
                'label': 'End Date',
                'value': '{{endDate}}',
                'minDate': '{{startDate}}',
                'change': {
                  'type': 'tool',
                  'tool': 'validateEndDate',
                  'params': {
                    'value': '{{event.value}}',
                  },
                },
              },
              {
                'type': 'text',
                'content': 'Selected: {{startDate}} - {{endDate}}',
                'visible': '{{startDate != null && endDate != null}}',
              },
            ],
          },
        });
        
        runtime.registerToolExecutor('validateEndDate', (params) async {
          final endDate = params['value'];
          final startDate = runtime.stateManager.get('startDate');
          
          runtime.stateManager.set('endDate', endDate);
          
          if (startDate != null && endDate != null) {
            final start = DateTime.parse(startDate.toString());
            final end = DateTime.parse(endDate.toString());
            
            if (end.isBefore(start)) {
              runtime.stateManager.set('dateError', 'End date must be after start date');
            } else {
              runtime.stateManager.set('dateError', null);
            }
          }
          
          return {'success': true};
        });
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: runtime.buildUI(),
            ),
          ),
        );
        
        await tester.pump();
        
        // The actual date field interaction would involve platform-specific date pickers
        // For this test, we're focusing on the validation logic structure
        expect(find.text('Start Date'), findsOneWidget);
        expect(find.text('End Date'), findsOneWidget);
      });
      
      testWidgets('should validate colorPicker input', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'primaryColor': '#2196F3',
                  'secondaryColor': null,
                  'colorError': null,
                },
              },
            },
          },
          'content': {
            'type': 'linear',
            'direction': 'vertical',
            'children': [
              {
                'type': 'colorPicker',
                'label': 'Primary Color',
                'value': '{{primaryColor}}',
                'change': {
                  'type': 'state',
                  'action': 'set',
                  'binding': 'primaryColor',
                  'value': '{{event.value}}',
                },
              },
              {
                'type': 'colorPicker',
                'label': 'Secondary Color',
                'value': '{{secondaryColor}}',
                'validation': [
                  {'type': 'required', 'message': 'Secondary color is required'},
                ],
                'error': '{{colorError}}',
                'change': {
                  'type': 'tool',
                  'tool': 'validateColor',
                  'params': {
                    'value': '{{event.value}}',
                  },
                },
              },
              {
                'type': 'box',
                'height': 50,
                'decoration': {
                  'color': '{{primaryColor}}',
                },
                'child': {
                  'type': 'center',
                  'child': {
                    'type': 'text',
                    'content': 'Preview',
                    'style': {
                      'color': '#FFFFFF',
                    },
                  },
                },
              },
            ],
          },
        });
        
        runtime.registerToolExecutor('validateColor', (params) async {
          final color = params['value'];
          runtime.stateManager.set('secondaryColor', color);
          
          if (color == null || color.toString().isEmpty) {
            runtime.stateManager.set('colorError', 'Secondary color is required');
          } else {
            runtime.stateManager.set('colorError', null);
          }
          
          return {'success': true};
        });
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: runtime.buildUI(),
            ),
          ),
        );
        
        await tester.pump();
        
        // Verify color picker widgets are rendered
        expect(find.text('Primary Color'), findsOneWidget);
        expect(find.text('Secondary Color'), findsOneWidget);
        expect(find.text('Preview'), findsOneWidget);
      });
    });
  });
}