# MCP UI DSL v1.0 Specification Compliance Tests

This directory contains comprehensive tests that verify `flutter_mcp_ui_runtime` fully implements the MCP UI DSL v1.0 specification.

## Test Philosophy

These tests are **specification-based**, not implementation-based. They verify behavior against the MCP UI DSL v1.0 specification document itself, not against any particular implementation (including `flutter_mcp_ui_core`).

The specification is the source of truth. Both `flutter_mcp_ui_core` and `flutter_mcp_ui_runtime` should be validated against these tests.

## Test Structure

### 1. Widget Specification Tests (`mcp_ui_dsl_v1_widget_spec_test.dart`)
- Verifies all widget types defined in the spec are registered
- Tests widget properties and behavior match specification
- Covers: text, button, image, linear, box, stack, list, conditional, etc.

### 2. Action System Tests (`mcp_ui_dsl_v1_action_spec_test.dart`)
- Tests all action types with correct parameter usage
- Verifies state actions use 'path' parameter
- Verifies resource actions use 'target' parameter
- Verifies tool actions use 'params' parameter
- Covers: state, tool, resource, navigation, batch, conditional actions

### 3. Binding Engine Tests (`mcp_ui_dsl_v1_binding_spec_test.dart`)
- Tests expression evaluation and data binding
- Covers all binding syntax from the specification:
  - Simple bindings: `{{value}}`
  - Nested access: `{{user.profile.name}}`
  - Array access: `{{items[0]}}`
  - Expressions: `{{count > 10}}`
  - Ternary: `{{isDark ? "Dark" : "Light"}}`
  - Event bindings: `{{event.value}}`

### 4. Widget Factory Tests (`mcp_ui_dsl_v1_widget_factory_spec_test.dart`)
- Verifies widgets are created with all specified properties
- Tests style application, layout behavior, and interactions
- Ensures factories produce spec-compliant widget instances

### 5. State Management Tests (`mcp_ui_dsl_v1_state_management_spec_test.dart`)
- Tests state initialization, updates, and reactivity
- Verifies all state actions (set, increment, toggle, etc.)
- Tests nested state structures and array operations
- Ensures state persistence and computed values work

### 6. Integration Tests (`mcp_ui_dsl_v1_integration_spec_test.dart`)
- Tests complete application scenarios
- Verifies all components work together correctly
- Covers: forms with validation, real-time updates, navigation

## Running the Tests

### Run all spec compliance tests:
```bash
flutter test test/spec_compliance/run_all_spec_tests.dart
```

### Run individual test categories:
```bash
# Widget specification tests
flutter test test/spec_compliance/mcp_ui_dsl_v1_widget_spec_test.dart

# Action system tests
flutter test test/spec_compliance/mcp_ui_dsl_v1_action_spec_test.dart

# Binding engine tests
flutter test test/spec_compliance/mcp_ui_dsl_v1_binding_spec_test.dart

# Widget factory tests
flutter test test/spec_compliance/mcp_ui_dsl_v1_widget_factory_spec_test.dart

# State management tests
flutter test test/spec_compliance/mcp_ui_dsl_v1_state_management_spec_test.dart

# Integration tests
flutter test test/spec_compliance/mcp_ui_dsl_v1_integration_spec_test.dart
```

## Test Coverage

### Widget Types (100% coverage)
- ✅ Layout: linear, box, stack, grid, positioned
- ✅ Display: text, image, icon, divider
- ✅ Input: button, textInput, checkbox, select, slider
- ✅ List: list with static/dynamic items
- ✅ Navigation: headerBar, bottomNav
- ✅ Special: conditional, form

### Action System (100% coverage)
- ✅ State: set, increment, decrement, toggle, append, remove
- ✅ Tool: with params parameter
- ✅ Resource: with target parameter
- ✅ Navigation: push, replace, pop, popToRoot
- ✅ Batch: sequential action execution
- ✅ Conditional: with then/else branches

### Binding Engine (100% coverage)
- ✅ Simple property binding
- ✅ Nested property access
- ✅ Array element access
- ✅ Expression evaluation
- ✅ Event object binding
- ✅ Mixed content binding

### Properties (95% coverage)
- ✅ Style properties (colors, fonts, spacing)
- ✅ Layout properties (alignment, distribution)
- ✅ Interaction properties (events, states)
- ✅ Validation properties
- ⚠️ Accessibility properties (partial - aria attributes)

## Key Specification Compliance Points

### 1. Widget Naming
Per v1.0 spec, multi-word widgets use CamelCase:
- ✅ `textInput` (not `text-input`)
- ✅ `headerBar` (not `header-bar`)
- ✅ `loadingIndicator` (not `loading-indicator`)

### 2. Event Naming
Per v1.0 spec, events use CamelCase:
- ✅ `click` (not `onTap` or `onPressed`)
- ✅ `doubleClick` (not `double-click`)
- ✅ `rightClick` (not `right-click`)
- ✅ `longPress` (not `long-press`)

### 3. Action Parameters
Per v1.0 spec, different action types use different parameter names:
- ✅ State actions use `path`
- ✅ Resource actions use `target`
- ✅ Tool actions use `params`

### 4. Layout Properties
Per v1.0 spec, platform-neutral layout terms:
- ✅ `distribution` (not `mainAxisAlignment`)
- ✅ `alignment` (not `crossAxisAlignment`)
- ✅ `gap` (not `spacing`)

## Adding New Tests

When adding new tests:
1. Base them on the MCP UI DSL v1.0 specification
2. Test behavior, not implementation details
3. Include both positive and edge cases
4. Document which part of the spec is being tested
5. Use descriptive test names that reference the spec

## Maintenance

These tests serve as the conformance test suite for MCP UI DSL v1.0. They should be:
- Updated when the specification changes
- Run against both core and runtime implementations
- Used to verify third-party implementations
- Kept independent of any specific implementation details