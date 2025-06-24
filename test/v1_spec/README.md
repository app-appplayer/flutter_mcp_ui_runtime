# MCP UI DSL v1.0 Specification-Based Tests

This directory contains the complete test suite for flutter_mcp_ui_runtime based on the MCP UI DSL v1.0 specification.

## Test Philosophy

All tests in this directory are **specification-driven**. They test against the MCP UI DSL v1.0 specification document, not against any implementation details.

## Directory Structure

```
v1_spec/
├── README.md                    # This file
├── core/                       # Core functionality tests
│   ├── runtime_test.dart       # Runtime initialization and lifecycle
│   ├── widget_registry_test.dart # Widget registration per spec
│   └── service_registry_test.dart # Service registration
├── widgets/                    # Widget specification tests
│   ├── layout/                 # Layout widgets (linear, box, stack, grid)
│   ├── display/               # Display widgets (text, image, icon)
│   ├── input/                 # Input widgets (button, textInput, checkbox)
│   ├── list/                  # List widgets
│   └── special/               # Special widgets (conditional, form)
├── actions/                    # Action system tests
│   ├── state_actions_test.dart # State manipulation actions
│   ├── tool_actions_test.dart  # Tool execution with params
│   ├── resource_actions_test.dart # Resource calls with target
│   └── navigation_actions_test.dart # Navigation actions
├── binding/                    # Data binding tests
│   ├── simple_binding_test.dart # {{value}} bindings
│   ├── expression_binding_test.dart # Complex expressions
│   └── event_binding_test.dart # Event object bindings
├── state/                      # State management tests
│   ├── initialization_test.dart # Initial state setup
│   ├── updates_test.dart       # State updates and reactivity
│   └── persistence_test.dart  # State persistence
├── validation/                 # Form validation tests
│   ├── built_in_validators_test.dart # Required, email, etc.
│   └── custom_validators_test.dart # Custom validation
├── integration/               # Integration tests
│   ├── form_flow_test.dart   # Complete form scenarios
│   ├── navigation_flow_test.dart # Multi-page navigation
│   └── realtime_updates_test.dart # Live data updates
└── compliance_report.dart     # Spec compliance report generator
```

## Running Tests

### Run all v1.0 spec tests:
```bash
flutter test test/v1_spec
```

### Run specific category:
```bash
# Widget tests only
flutter test test/v1_spec/widgets

# Action tests only
flutter test test/v1_spec/actions

# Integration tests only
flutter test test/v1_spec/integration
```

### Generate compliance report:
```bash
flutter test test/v1_spec/compliance_report.dart
```

## Specification Compliance

Each test file includes:
- Reference to specific spec section being tested
- Expected behavior according to spec
- Test cases covering all spec requirements
- Edge cases and error handling

## Test Naming Convention

Test names follow this pattern:
- `should_[behavior]_when_[condition]`
- `spec_[section]_[requirement]`

Example:
```dart
test('should render text widget with content property per spec 4.2.1', () {
  // Test implementation
});
```