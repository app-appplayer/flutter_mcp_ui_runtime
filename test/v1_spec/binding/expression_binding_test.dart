import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

/// MCP UI DSL v1.0 Expression Binding Tests
/// 
/// Tests expression evaluation and complex bindings according to MCP UI DSL v1.0 specification.
/// Reference: Spec Section 5.2 - Expression Language
void main() {
  group('MCP UI DSL v1.0 - Expression Binding', () {
    late MCPUIRuntime runtime;
    
    setUp(() {
      runtime = MCPUIRuntime();
    });
    
    tearDown(() {
      runtime.destroy();
    });
    
    group('Comparison Operators (Spec 5.2.1)', () {
      testWidgets('should evaluate equality operator ==', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'value1': 10,
                  'value2': 10,
                  'value3': 20,
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
                'content': 'value1 == value2: {{value1 == value2}}',
              },
              {
                'type': 'text',
                'content': 'value1 == value3: {{value1 == value3}}',
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        expect(find.text('value1 == value2: true'), findsOneWidget);
        expect(find.text('value1 == value3: false'), findsOneWidget);
      });
      
      testWidgets('should evaluate inequality operator !=', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'status': 'active',
                },
              },
            },
          },
          'content': {
            'type': 'text',
            'content': 'Is inactive: {{status != "active"}}',
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        expect(find.text('Is inactive: false'), findsOneWidget);
      });
      
      testWidgets('should evaluate comparison operators <, >, <=, >=', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'age': 25,
                  'minAge': 18,
                  'maxAge': 65,
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
                'content': 'age > minAge: {{age > minAge}}',
              },
              {
                'type': 'text',
                'content': 'age < maxAge: {{age < maxAge}}',
              },
              {
                'type': 'text',
                'content': 'age >= 25: {{age >= 25}}',
              },
              {
                'type': 'text',
                'content': 'age <= 30: {{age <= 30}}',
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        expect(find.text('age > minAge: true'), findsOneWidget);
        expect(find.text('age < maxAge: true'), findsOneWidget);
        expect(find.text('age >= 25: true'), findsOneWidget);
        expect(find.text('age <= 30: true'), findsOneWidget);
      });
    });
    
    group('Logical Operators (Spec 5.2.2)', () {
      testWidgets('should evaluate AND operator &&', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'isLoggedIn': true,
                  'hasPermission': true,
                  'isActive': false,
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
                'content': 'Can access: {{isLoggedIn && hasPermission}}',
              },
              {
                'type': 'text',
                'content': 'Can edit: {{isLoggedIn && hasPermission && isActive}}',
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        expect(find.text('Can access: true'), findsOneWidget);
        expect(find.text('Can edit: false'), findsOneWidget);
      });
      
      testWidgets('should evaluate OR operator ||', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'isAdmin': false,
                  'isOwner': true,
                  'isModerator': false,
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
                'content': 'Has privileges: {{isAdmin || isOwner || isModerator}}',
              },
              {
                'type': 'text',
                'content': 'Is staff: {{isAdmin || isModerator}}',
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        expect(find.text('Has privileges: true'), findsOneWidget);
        expect(find.text('Is staff: false'), findsOneWidget);
      });
      
      testWidgets('should evaluate NOT operator !', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'isDisabled': false,
                  'isHidden': true,
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
                'content': 'Is enabled: {{!isDisabled}}',
              },
              {
                'type': 'text',
                'content': 'Is visible: {{!isHidden}}',
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        expect(find.text('Is enabled: true'), findsOneWidget);
        expect(find.text('Is visible: false'), findsOneWidget);
      });
    });
    
    group('Ternary Operator (Spec 5.2.3)', () {
      testWidgets('should evaluate simple ternary expressions', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'isDarkMode': true,
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
                'type': 'text',
                'content': 'Theme: {{isDarkMode ? "Dark" : "Light"}}',
              },
              {
                'type': 'text',
                'content': '{{isLoggedIn ? "Welcome back!" : "Please log in"}}',
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        expect(find.text('Theme: Dark'), findsOneWidget);
        expect(find.text('Please log in'), findsOneWidget);
      });
      
      testWidgets('should evaluate nested ternary expressions', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'score': 85,
                },
              },
            },
          },
          'content': {
            'type': 'text',
            'content': 'Grade: {{score >= 90 ? "A" : score >= 80 ? "B" : score >= 70 ? "C" : "F"}}',
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        expect(find.text('Grade: B'), findsOneWidget);
      });
      
      testWidgets('should evaluate ternary with complex conditions', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'count': 1,
                  'items': ['a', 'b', 'c'],
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
                'content': '{{count == 1 ? "1 item" : count + " items"}}',
              },
              {
                'type': 'text',
                'content': '{{items.length > 0 ? "Has " + items.length + " items" : "No items"}}',
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        expect(find.text('1 item'), findsOneWidget);
        expect(find.text('Has 3 items'), findsOneWidget);
      });
    });
    
    group('Arithmetic Operations (Spec 5.2.4)', () {
      testWidgets('should evaluate arithmetic expressions', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'price': 100,
                  'quantity': 3,
                  'taxRate': 0.08,
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
                'content': 'Subtotal: \${{price * quantity}}',
              },
              {
                'type': 'text',
                'content': 'Tax: \${{price * quantity * taxRate}}',
              },
              {
                'type': 'text',
                'content': 'Total: \${{price * quantity * (1 + taxRate)}}',
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        expect(find.text('Subtotal: \$300'), findsOneWidget);
        expect(find.text('Tax: \$24'), findsOneWidget);
        expect(find.text('Total: \$324'), findsOneWidget);
      });
    });
    
    group('String Operations (Spec 5.2.5)', () {
      testWidgets('should concatenate strings', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'firstName': 'John',
                  'lastName': 'Doe',
                  'title': 'Dr.',
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
                'content': '{{title + " " + firstName + " " + lastName}}',
              },
              {
                'type': 'text',
                'content': '{{firstName + " " + lastName.toUpperCase()}}',
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        expect(find.text('Dr. John Doe'), findsOneWidget);
        expect(find.text('John DOE'), findsOneWidget);
      });
    });
    
    group('Complex Expressions (Spec 5.2.6)', () {
      testWidgets('should evaluate complex mixed expressions', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'user': {
                    'role': 'admin',
                    'permissions': ['read', 'write', 'delete'],
                  },
                  'feature': {
                    'enabled': true,
                    'minRole': 'admin',
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
                'type': 'text',
                'content': 'Can use feature: {{feature.enabled && user.role == feature.minRole}}',
              },
              {
                'type': 'text',
                'content': 'Permission count: {{user.permissions.length}}',
              },
              {
                'type': 'text',
                'content': 'Has write access: {{user.permissions.contains("write")}}',
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        expect(find.text('Can use feature: true'), findsOneWidget);
        expect(find.text('Permission count: 3'), findsOneWidget);
        expect(find.text('Has write access: true'), findsOneWidget);
      });
      
      testWidgets('should handle undefined values gracefully', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'user': {
                    'name': 'John',
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
                'type': 'text',
                'content': 'Email: {{user.email || "Not provided"}}',
              },
              {
                'type': 'text',
                'content': 'Phone: {{user.phone ? user.phone : "N/A"}}',
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        expect(find.text('Email: Not provided'), findsOneWidget);
        expect(find.text('Phone: N/A'), findsOneWidget);
      });
    });
  });
}