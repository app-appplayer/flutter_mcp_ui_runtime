# Flutter MCP UI Runtime

## 🙌 Support This Project

If you find this package useful, consider supporting ongoing development on Patreon.

[![Support on Patreon](https://c5.patreon.com/external/logo/become_a_patron_button.png)](https://www.patreon.com/mcpdevstudio)

### 🔗 MCP Dart Package Family

- [`mcp_server`](https://pub.dev/packages/mcp_server): Exposes tools, resources, and prompts to LLMs. Acts as the AI server.
- [`mcp_client`](https://pub.dev/packages/mcp_client): Connects Flutter/Dart apps to MCP servers. Acts as the client interface.
- [`mcp_llm`](https://pub.dev/packages/mcp_llm): Bridges LLMs (Claude, OpenAI, etc.) to MCP clients/servers. Acts as the LLM brain.
- [`flutter_mcp`](https://pub.dev/packages/flutter_mcp): Complete Flutter plugin for MCP integration with platform features.
- [`flutter_mcp_ui_core`](https://pub.dev/packages/flutter_mcp_ui_core): Core models, constants, and utilities for Flutter MCP UI system. 
- [`flutter_mcp_ui_runtime`](https://pub.dev/packages/flutter_mcp_ui_runtime): Comprehensive runtime for building dynamic, reactive UIs through JSON specifications. 
- [`flutter_mcp_ui_generator`](https://pub.dev/packages/flutter_mcp_ui_generator): JSON generation toolkit for creating UI definitions with templates and fluent API. 

---

A comprehensive Flutter runtime for building server-driven UIs using the MCP (Model Context Protocol) UI DSL v1.0 specification. This package provides a complete runtime environment with lifecycle management, services, and advanced state management.

📋 **Based on [MCP UI DSL v1.0 Specification](./doc/specification/MCP_UI_DSL_v1.0_Specification.md)** - The standard specification for Model Context Protocol UI Definition Language.

## Features

- 🎨 **65+ Flutter widgets** supported out of the box
- 🔄 **Reactive State Management**: Built-in state management with automatic UI updates
- 🧮 **Expression Binding**: Support for dynamic data binding with expressions
- ⚡ **Action System**: Handle user interactions with configurable actions
- 🔧 **Extensible**: Easy to add custom widgets and tool executors
- 🎯 **Pure Architecture**: No external dependencies, tool executors are injected
- 🔀 **Multiple Instance Support**: Run multiple MCP servers/apps simultaneously
- 🧩 **MCP Protocol Ready**: Designed for AI-powered UI generation
- 📐 **Standardized Structure**: Follows MCP UI DSL v1.0 specification

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  flutter_mcp_ui_runtime: ^0.1.0
```

## Quick Start

### Basic Usage

```dart
import 'package:flutter_mcp_ui_renderer/flutter_mcp_ui_renderer.dart';

// Define your UI in JSON
final uiDefinition = {
  "layout": {
    "type": "column",
    "children": [
      {
        "type": "text",
        "properties": {
          "content": "Hello {{name}}!",
          "style": {"fontSize": 24}
        }
      },
      {
        "type": "button",
        "properties": {
          "label": "Click me",
          "onTap": {
            "type": "state",
            "action": "set",
            "path": "name",
            "value": "World"
          }
        }
      }
    ]
  }
};

// Render the UI
Widget ui = MCPUIRenderer.instance.render(
  uiDefinition,
  initialState: {"name": "Flutter"},
);
```

### Multiple MCP Servers

```dart
// Create separate renderer instances for different MCP servers
final tradingRenderer = MCPUIRenderer.forServer('trading-server');
final analyticsRenderer = MCPUIRenderer.forServer('analytics-server');

// Each renderer maintains independent state and configuration
final tradingUI = tradingRenderer.render(tradingDefinition);
final analyticsUI = analyticsRenderer.render(analyticsDefinition);
```

### With Tool Executors

```dart
// Define tool executors for external API calls
final toolExecutors = <String, Function>{
  'getCurrentTime': (Map<String, dynamic> args) async {
    return DateTime.now().toString();
  },
  'fetchUserData': (Map<String, dynamic> args) async {
    final userId = args['userId'];
    // Make API call here
    return {"name": "John", "email": "john@example.com"};
  },
};

// UI definition with tool actions
final uiDefinition = {
  "layout": {
    "type": "column",
    "children": [
      {
        "type": "text",
        "properties": {
          "content": "Time: {{currentTime}}"
        }
      },
      {
        "type": "button",
        "properties": {
          "label": "Get Time",
          "onTap": {
            "type": "tool",
            "tool": "getCurrentTime",
            "bindResult": "currentTime"
          }
        }
      }
    ]
  }
};

Widget ui = MCPUIRenderer.instance.render(
  uiDefinition,
  initialState: {"currentTime": "Not loaded"},
  toolExecutors: toolExecutors,
);
```

## Supported Widgets (65+)

The Flutter MCP UI Renderer supports **65 standard widgets** across 8 categories:

### Layout Widgets (19)
- `container`, `row`, `column`, `stack`, `positioned`
- `padding`, `center`, `align`, `sizedbox`
- `expanded`, `flexible`, `spacer`
- `wrap`, `aspectratio`, `fittedbox`
- `constrainedbox`, `limitedbox`
- `intrinsicheight`, `intrinsicwidth`

### Display Widgets (16)
- `text`, `richtext`, `icon`, `image`
- `card`, `chip`, `avatar`, `badge`
- `progressbar`, `divider`, `placeholder`
- `decoratedbox`, `banner`, `cliprrect`
- `tooltip`, `visibility`

### Input Widgets (12)
- `button`, `textfield`, `textformfield`
- `checkbox`, `switch`, `slider`, `rangeslider`
- `radio`, `dropdown`
- `datepicker`, `timepicker`, `stepper`

### List Widgets (3)
- `listview` - Dynamic list with data binding
- `gridview` - Grid layout with fixed/max cross axis extent
- `listtile` - Material design list item

### Navigation Widgets (7)
- `appbar`, `bottomnavigationbar`, `drawer`
- `tabbar`, `navigationrail`
- `floatingactionbutton`, `popupmenubutton`

### Scroll Widgets (2)
- `singlechildscrollview` - Scrollable single child
- `pageview` - Swipeable pages

### Animation Widgets (1)
- `animatedcontainer` - Animated property transitions

### Interactive Widgets (2)
- `gesturedetector` - Gesture detection
- `inkwell` - Material ripple effect

### Dialog Widgets (3)
- `alertdialog` - Alert dialog
- `snackbar` - Temporary message bar
- `bottomsheet` - Bottom sheet modal

For complete widget reference with properties and examples, see the [MCP UI DSL Complete Specification](./MCP_UI_DSL_Complete_Spec_v1.0.md).

## Expression Binding

The renderer supports dynamic data binding using double curly braces:

```json
{
  "type": "text",
  "properties": {
    "content": "{{user.name}}"
  }
}
```

### Supported Expressions

- **Simple binding**: `{{variable}}`
- **Nested paths**: `{{user.profile.name}}`
- **Array indexing**: `{{items[0]}}`
- **Dynamic array indexing**: `{{products[index].name}}`
- **Arithmetic**: `{{count + 1}}`
- **Comparison**: `{{count > 0}}`
- **Conditional**: `{{count > 0 ? 'Has items' : 'Empty'}}`
- **Transforms**: `{{name | uppercase}}`

### Built-in Transforms

- `uppercase`, `lowercase`, `capitalize`
- `round`, `floor`, `ceil`, `abs`

## Action System

### State Actions
```json
{
  "type": "state",
  "action": "set",
  "path": "counter",
  "value": 42
}
```

Actions: `set`, `increment`, `decrement`, `toggle`, `append`, `remove`

### Tool Actions
```json
{
  "type": "tool",
  "tool": "fetchData",
  "args": {"id": "{{userId}}"},
  "bindResult": "userData"
}
```

### Batch Actions
```json
{
  "type": "batch",
  "parallel": true,
  "actions": [
    {"type": "state", "action": "set", "path": "loading", "value": true},
    {"type": "tool", "tool": "fetchData", "bindResult": "data"}
  ]
}
```

### Conditional Actions
```json
{
  "type": "conditional",
  "condition": "{{count > 0}}",
  "then": {"type": "state", "action": "set", "path": "message", "value": "Has data"},
  "else": {"type": "state", "action": "set", "path": "message", "value": "No data"}
}
```

## Customization

### Custom Widgets

```dart
class MyCustomWidget extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    // Your custom widget implementation
    return Container();
  }
}

// Register custom widget
MCPUIRenderer.instance.registerWidget('myWidget', MyCustomWidget());
```

### Custom Transforms

```dart
MCPUIRenderer.instance.registerTransform('reverse', (value) {
  return value.toString().split('').reversed.join('');
});
```

## Examples

### Counter App
```json
{
  "layout": {
    "type": "column",
    "properties": {"mainAxisAlignment": "center"},
    "children": [
      {
        "type": "text",
        "properties": {
          "content": "Count: {{count}}",
          "style": {"fontSize": 24}
        }
      },
      {
        "type": "row",
        "properties": {"mainAxisAlignment": "center"},
        "children": [
          {
            "type": "button",
            "properties": {
              "label": "-",
              "onTap": {"type": "state", "action": "decrement", "path": "count"}
            }
          },
          {
            "type": "button",
            "properties": {
              "label": "+",
              "onTap": {"type": "state", "action": "increment", "path": "count"}
            }
          }
        ]
      }
    ]
  }
}
```

### Form Example
```json
{
  "layout": {
    "type": "column",
    "children": [
      {
        "type": "text",
        "properties": {"content": "Name: {{form.name}}"}
      },
      {
        "type": "button",
        "properties": {
          "label": "Update Name",
          "onTap": {
            "type": "state",
            "action": "set",
            "path": "form.name",
            "value": "John Doe"
          }
        }
      }
    ]
  }
}
```

## API Reference

### MCPUIRenderer

Main class for rendering UI definitions.

```dart
class MCPUIRenderer {
  // Singleton instance
  static MCPUIRenderer get instance;
  
  // Create instance for specific server
  factory MCPUIRenderer.forServer(String serverId);
  
  // Main render method
  Widget render(
    Map<String, dynamic> uiDefinition, {
    Map<String, dynamic>? initialState,
    Map<String, Function>? toolExecutors,
    ErrorWidgetBuilder? errorBuilder,
  });
  
  // Register custom widget
  void registerWidget(String type, WidgetFactory factory);
  
  // Register custom transform
  void registerTransform(String name, Function transform);
  
  // State management
  T? getState<T>(String path);
  void setState(String path, dynamic value);
  Stream<T> watchState<T>(String path);
}
```

### State Management

```dart
// Get state value
T? value = MCPUIRenderer.instance.getState<T>('path');

// Set state value
MCPUIRenderer.instance.setState('path', value);

// Watch state changes
Stream<T> stream = MCPUIRenderer.instance.watchState<T>('path');
```

## Architecture

The package follows a clean architecture with these core components:

- **Renderer**: Converts JSON to Flutter widgets
- **StateManager**: Manages application state
- **BindingEngine**: Handles data binding and expressions
- **ActionHandler**: Executes user actions
- **WidgetRegistry**: Manages widget factories

## Documentation

- [MCP UI DSL v1.0 Specification](./doc/specification/MCP_UI_DSL_v1.0_Specification.md) - Complete specification for Model Context Protocol UI Definition Language
- [API Reference](./doc/api/) - Detailed API documentation
- [Architecture Overview](./doc/architecture/overview.md) - System architecture and design
- [Getting Started Guide](./doc/guides/getting-started.md) - Quick start guide
- [Advanced Topics](./doc/guides/advanced-topics.md) - Advanced usage and patterns
- [Custom Widgets Guide](./doc/guides/custom-widgets.md) - How to create custom widgets
- [Examples](./doc/examples/) - Sample implementations
- [Widget Reference](./doc/api/widget-reference.md) - Complete widget property reference

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

---

Made with ❤️ for the Flutter and MCP communities.