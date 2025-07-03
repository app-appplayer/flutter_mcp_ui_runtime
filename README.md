# Flutter MCP UI Runtime

## 🙌 Support This Project

If you find this package useful, consider supporting ongoing development on PayPal.

[![Donate](https://www.paypalobjects.com/en_US/i/btn/btn_donate_LG.gif)](https://www.paypal.com/ncp/payment/F7G56QD9LSJ92)  
Support makemind via [PayPal](https://www.paypal.com/ncp/payment/F7G56QD9LSJ92)

---

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

📋 **Based on [MCP UI DSL v1.0 Specification](https://github.com/app-appplayer/makemind/blob/main/doc/specification/MCP_UI_DSL_v1.0_Specification.md)** - The standard specification for Model Context Protocol UI Definition Language.

## Features

- 🎨 **77+ Flutter widgets** supported out of the box
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
  flutter_mcp_ui_runtime: ^0.2.4
```

### Important: Building with Dynamic Icons

If your app uses dynamic icons from JSON (e.g., `"icon": "folder"`), you must build with the `--no-tree-shake-icons` flag:

```bash
flutter build apk --no-tree-shake-icons
flutter build ios --no-tree-shake-icons
flutter build macos --no-tree-shake-icons
```

This is necessary because the runtime creates icons dynamically from strings, which the compiler cannot detect at build time. Without this flag, Material Icons will be removed by tree shaking and your icons won't appear.

## Quick Start

### Basic Usage

```dart
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

// Define your UI in JSON
final uiDefinition = {
  "type": "page",
  "content": {
    "type": "linear",
    "direction": "vertical",
    "padding": {"all": 20},
    "children": [
      {
        "type": "label",
        "content": "Hello {{name}}!",
        "style": {
          "fontSize": 24,
          "fontWeight": "bold"
        }
      },
      {"type": "box", "height": 16},
      {
        "type": "button",
        "label": "Click me",
        "variant": "elevated",
        "click": {
          "type": "state",
          "action": "set",
          "binding": "name",
          "value": "World"
        }
      }
    ]
  },
  "state": {
    "initial": {
      "name": "Flutter"
    }
  }
};

// Create and initialize runtime
final runtime = MCPUIRuntime();
await runtime.initialize(uiDefinition);

// Build the UI
Widget ui = runtime.buildUI();
```

### Full Application Example

```dart
// Define a complete application with navigation and theme
final appDefinition = {
  "type": "application",
  "title": "My MCP App",
  "version": "1.0.0",
  "theme": {
    "mode": "light",
    "colors": {
      "primary": "#2196F3",
      "secondary": "#FF4081",
      "background": "#FFFFFF",
      "surface": "#F5F5F5"
    },
    "typography": {
      "h1": {"fontSize": 32, "fontWeight": "bold"},
      "body1": {"fontSize": 16}
    },
    "spacing": {
      "sm": 8,
      "md": 16,
      "lg": 24
    }
  },
  "navigation": {
    "type": "drawer",
    "items": [
      {"title": "Home", "icon": "home", "route": "/home"},
      {"title": "Settings", "icon": "settings", "route": "/settings"}
    ]
  },
  "routes": {
    "/home": "ui://pages/home",
    "/settings": "ui://pages/settings"
  },
  "initialRoute": "/home",
  "state": {
    "initial": {
      "user": {"name": "Guest", "isAuthenticated": false}
    }
  }
};

// Initialize and run the application
final runtime = MCPUIRuntime();
await runtime.initialize(appDefinition);
Widget app = runtime.buildUI();
```

### Multiple MCP Servers

```dart
// Create separate runtime instances for different MCP servers
final tradingRuntime = MCPUIRuntime(debugMode: true);
final analyticsRuntime = MCPUIRuntime(debugMode: true);

// Initialize each runtime with their definitions
await tradingRuntime.initialize(tradingDefinition);
await analyticsRuntime.initialize(analyticsDefinition);

// Each runtime maintains independent state and configuration
final tradingUI = tradingRuntime.buildUI();
final analyticsUI = analyticsRuntime.buildUI();
```

### With Tool Executors

```dart
// Define tool executors for external API calls
final runtime = MCPUIRuntime();

// Register tool executors
runtime.registerToolExecutor('getCurrentTime', (Map<String, dynamic> args) async {
  return DateTime.now().toString();
});

runtime.registerToolExecutor('fetchUserData', (Map<String, dynamic> args) async {
  final userId = args['userId'];
  // Make API call here
  return {"name": "John", "email": "john@example.com"};
});

// UI definition with tool actions
final uiDefinition = {
  "type": "page",
  "content": {
    "type": "linear",
    "direction": "vertical",
    "padding": {"all": 20},
    "children": [
      {
        "type": "text",
        "content": "Time: {{currentTime}}",
        "style": {"fontSize": 18}
      },
      {"type": "box", "height": 16},
      {
        "type": "button",
        "label": "Get Time",
        "variant": "elevated",
        "click": {
          "type": "tool",
          "tool": "getCurrentTime",
          "bindTo": "currentTime"
        }
      }
    ]
  },
  "state": {
    "initial": {
      "currentTime": "Not loaded"
    }
  }
};

// Initialize and build UI
await runtime.initialize(uiDefinition);
Widget ui = runtime.buildUI();
```

## Supported Widgets (77+)

The Flutter MCP UI Runtime supports **77+ widgets** across 9 categories:

### Layout Widgets (19)
- `box`, `linear`, `stack`, `positioned`
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

For complete widget reference with properties and examples, see the [Widget Reference](https://github.com/app-appplayer/makemind/blob/main/doc/api/widget-reference.md).

## Expression Binding

The renderer supports dynamic data binding using double curly braces:

```json
{
  "type": "text",
  "content": "{{user.name}}",
  "style": {
    "fontSize": 16,
    "color": "{{theme.colors.textOnBackground}}"
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
  "binding": "counter",
  "value": 42
}
```

Actions: `set`, `increment`, `decrement`, `toggle`, `append`, `remove`

### Tool Actions
```json
{
  "type": "tool",
  "tool": "fetchData",
  "params": {"id": "{{userId}}"},
  "bindTo": "userData"
}
```

### Batch Actions
```json
{
  "type": "batch",
  "parallel": true,
  "actions": [
    {"type": "state", "action": "set", "binding": "loading", "value": true},
    {"type": "tool", "tool": "fetchData", "bindTo": "data"}
  ]
}
```

### Conditional Actions
```json
{
  "type": "conditional",
  "condition": "{{count > 0}}",
  "then": {"type": "state", "action": "set", "binding": "message", "value": "Has data"},
  "else": {"type": "state", "action": "set", "binding": "message", "value": "No data"}
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
    "type": "linear",
    "direction": "vertical",
    "properties": {"mainAxisAlignment": "center"},
    "children": [
      {
        "type": "label",
        "properties": {
          "content": "Count: {{count}}",
          "style": {"fontSize": 24}
        }
      },
      {
        "type": "linear",
        "direction": "horizontal",
        "properties": {"mainAxisAlignment": "center"},
        "children": [
          {
            "type": "button",
            "properties": {
              "label": "-",
              "click": {"type": "state", "action": "decrement", "binding": "count"}
            }
          },
          {
            "type": "button",
            "properties": {
              "label": "+",
              "click": {"type": "state", "action": "increment", "binding": "count"}
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
    "type": "linear",
    "direction": "vertical",
    "children": [
      {
        "type": "label",
        "properties": {"content": "Name: {{form.name}}"}
      },
      {
        "type": "button",
        "properties": {
          "label": "Update Name",
          "click": {
            "type": "state",
            "action": "set",
            "binding": "form.name",
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

- [MCP UI DSL v1.0 Specification](https://github.com/app-appplayer/makemind/blob/main/doc/specification/MCP_UI_DSL_v1.0_Specification.md) - Complete specification for Model Context Protocol UI Definition Language
- [API Reference](https://github.com/app-appplayer/makemind/tree/main/doc/api) - Detailed API documentation
- [Architecture Overview](https://github.com/app-appplayer/makemind/blob/main/doc/architecture/overview.md) - System architecture and design
- [Getting Started Guide](https://github.com/app-appplayer/makemind/blob/main/doc/guides/getting-started.md) - Quick start guide
- [Advanced Topics](https://github.com/app-appplayer/makemind/blob/main/doc/guides/advanced-topics.md) - Advanced usage and patterns
- [Custom Widgets Guide](https://github.com/app-appplayer/makemind/blob/main/doc/guides/custom-widgets.md) - How to create custom widgets
- [Examples](https://github.com/app-appplayer/makemind/tree/main/doc/examples) - Sample implementations
- [Widget Reference](https://github.com/app-appplayer/makemind/blob/main/doc/api/widget-reference.md) - Complete widget property reference

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