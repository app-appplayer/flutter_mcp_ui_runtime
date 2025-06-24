# Test Migration Guide: MCP UI DSL v1.0

This guide explains the test migration from legacy format to MCP UI DSL v1.0 specification-based tests.

## Overview

All tests in flutter_mcp_ui_runtime have been redesigned to test against the MCP UI DSL v1.0 specification document, not implementation details.

## New Test Structure

```
test/
├── v1_spec/                    # All v1.0 spec-based tests
│   ├── core/                   # Core functionality
│   ├── widgets/                # Widget tests by category
│   ├── actions/                # Action system tests
│   ├── binding/                # Data binding tests
│   ├── state/                  # State management
│   ├── validation/             # Form validation
│   ├── integration/            # Integration scenarios
│   └── compliance_report.dart  # Spec compliance report
└── [legacy tests]              # To be migrated or removed
```

## Key Changes

### 1. Widget Names (v1.0 CamelCase)
```dart
// OLD (Legacy)
'text-input', 'loading-indicator', 'header-bar'

// NEW (v1.0 Spec)
'textInput', 'loadingIndicator', 'headerBar'
```

### 2. Event Names (v1.0 Spec)
```dart
// OLD (Flutter-specific)
'onTap', 'onPressed', 'onChanged'

// NEW (v1.0 Spec)
'click', 'change', 'focus', 'blur'
```

### 3. Action Parameters (v1.0 Spec)
```dart
// OLD
{
  'type': 'state',
  'action': 'set',
  'key': 'message',    // Wrong parameter name
  'value': 'Hello'
}

// NEW (v1.0 Spec)
{
  'type': 'state',
  'action': 'set',
  'path': 'message',   // Correct: 'path' for state actions
  'value': 'Hello'
}
```

### 4. Layout Properties (v1.0 Spec)
```dart
// OLD (Flutter-specific)
{
  'type': 'linear',
  'mainAxisAlignment': 'center',
  'crossAxisAlignment': 'start'
}

// NEW (v1.0 Spec)
{
  'type': 'linear',
  'distribution': 'center',  // Platform-neutral
  'alignment': 'start'       // Platform-neutral
}
```

## Migration Steps

### Step 1: Identify Test Category
Determine which v1.0 spec section your test belongs to:
- Core runtime → `v1_spec/core/`
- Widget tests → `v1_spec/widgets/[category]/`
- Actions → `v1_spec/actions/`
- Bindings → `v1_spec/binding/`
- State → `v1_spec/state/`

### Step 2: Update Widget Names
Replace all hyphenated widget names with CamelCase:
```dart
// Before
registry.has('text-input')

// After
registry.has('textInput')
```

### Step 3: Update Event Handlers
Replace Flutter-specific events with v1.0 spec events:
```dart
// Before
'onTap': {'type': 'tool', 'tool': 'handleClick'}

// After
'click': {'type': 'tool', 'tool': 'handleClick'}
```

### Step 4: Update Action Definitions
Use correct parameter names per action type:
```dart
// State actions use 'path'
{'type': 'state', 'action': 'set', 'path': 'value'}

// Tool actions use 'params'
{'type': 'tool', 'tool': 'send', 'params': {...}}

// Resource actions use 'target'
{'type': 'resource', 'resource': 'api', 'target': '/users'}
```

### Step 5: Test Against Spec, Not Implementation
```dart
// BAD: Testing implementation details
test('should call Flutter setState', () {
  // Tests internal Flutter behavior
});

// GOOD: Testing spec compliance
test('should update text when state changes per spec 5.1', () {
  // Tests that binding {{value}} updates when state changes
});
```

## Running Tests

### Run all v1.0 spec tests:
```bash
flutter test test/v1_spec
```

### Run specific categories:
```bash
flutter test test/v1_spec/widgets
flutter test test/v1_spec/actions
flutter test test/v1_spec/integration
```

### Generate compliance report:
```bash
flutter test test/v1_spec/compliance_report.dart
```

## Test Naming Convention

Use descriptive names that reference the spec:
```dart
test('should render text widget with content property per spec 4.2.1', () {
  // Test implementation
});
```

## Common Patterns

### Testing Widget Properties
```dart
testWidgets('should apply all style properties per spec', (tester) async {
  await runtime.initialize({
    'type': 'page',
    'content': {
      'type': 'text',
      'content': 'Styled Text',
      'style': {
        'fontSize': 24,
        'fontWeight': 'bold',
        'color': '#FF0000'
      }
    }
  });
  
  await tester.pumpWidget(MaterialApp(home: runtime.buildUI()));
  await tester.pump();
  
  final text = tester.widget<Text>(find.text('Styled Text'));
  expect(text.style?.fontSize, 24);
  expect(text.style?.fontWeight, FontWeight.bold);
  expect(text.style?.color, const Color(0xFFFF0000));
});
```

### Testing State Updates
```dart
testWidgets('should update binding when state changes', (tester) async {
  await runtime.initialize({
    'type': 'page',
    'runtime': {
      'services': {
        'state': {
          'initialState': {'count': 0}
        }
      }
    },
    'content': {
      'type': 'text',
      'content': 'Count: {{count}}'
    }
  });
  
  await tester.pumpWidget(MaterialApp(home: runtime.buildUI()));
  await tester.pump();
  
  expect(find.text('Count: 0'), findsOneWidget);
  
  runtime.stateManager.set('count', 5);
  await tester.pump();
  
  expect(find.text('Count: 5'), findsOneWidget);
});
```

## Checklist for Migration

- [ ] Replace all hyphenated widget names with CamelCase
- [ ] Update all event names to v1.0 spec (click, change, etc.)
- [ ] Use correct action parameters (path, params, target)
- [ ] Replace Flutter-specific property names
- [ ] Test against spec behavior, not implementation
- [ ] Add spec section references in test descriptions
- [ ] Verify tests pass with latest flutter_mcp_ui_core
- [ ] Remove dependency on internal implementation details

## Legacy Test Deprecation

Legacy tests in the following directories should be migrated:
- `test/widgets/` → `test/v1_spec/widgets/`
- `test/actions/` → `test/v1_spec/actions/`
- `test/core/` → `test/v1_spec/core/`
- `test/integration/` → `test/v1_spec/integration/`

Once migrated, legacy tests can be removed.