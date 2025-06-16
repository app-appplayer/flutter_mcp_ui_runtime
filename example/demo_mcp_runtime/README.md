# MCP UI Runtime Demo

A comprehensive demonstration app showcasing the MCP UI DSL v1.0 features and the advanced capabilities of the MCP UI Runtime package.

## Features Demonstrated

### 📱 Application Type Demo
- Multi-page application with routing
- Navigation between different pages
- Application-level state management
- Page loading and caching

### 📄 Page Type Demo
- Single page UI definition
- Simple and focused interface
- Ideal for single-screen components
- Lightweight page structure

### 🧭 Navigation Demo
- Multiple navigation patterns (drawer, tabs, bottom navigation)
- Route management and deep linking
- Navigation state persistence
- Dynamic navigation structure

### 🚀 Lifecycle Management
- Application initialization and readiness states
- Component mount/unmount lifecycle
- Service registration and management
- Lifecycle hooks execution

### ⚙️ Background Services
- Periodic services (run at intervals)
- Scheduled services (cron-like scheduling)
- Event-based services (triggered by events)
- Continuous and one-off services
- Service constraints and optimization

### ⚡ State & Bindings
- Reactive state management with real-time bindings
- Computed properties and watchers
- Complex state expressions
- Cross-component state synchronization

### 🔔 Notification System
- Real-time notification channels
- Different notification types (info, warning, error)
- Channel-based notification management
- Notification importance levels

### 🔧 Tool Integration
- MCP tool call handling
- System information access
- Real-time data refresh mechanisms
- Background task execution

## Runtime Architecture

The demo showcases the comprehensive MCP UI Runtime architecture:

```
┌─────────────────────────────────────────────────────────┐
│                    MCP UI Runtime                       │
├─────────────────────────────────────────────────────────┤
│  🏗️ Lifecycle Manager                                  │
│  ⚡ Service Registry (State, Navigation, Dialog, etc.) │
│  💾 Cache Manager (Offline Support)                    │
│  🔔 Notification Manager                               │
│  🎭 Binding Engine (State Expressions)                 │
│  🔧 Tool Integration                                    │
└─────────────────────────────────────────────────────────┘
```

## MCP UI DSL v1.0 Features

The demo showcases the complete MCP UI DSL v1.0 specification:

- **Application vs Page Types**: Full application definitions with routing vs simple page definitions
- **Navigation Systems**: Drawer, tabs, and bottom navigation patterns
- **Background Services**: Periodic, scheduled, event-based, continuous, and one-off services
- **State Management**: Initial state, computed properties, and watchers
- **Lifecycle Hooks**: onInitialize, onReady, onMount, onUnmount, onPause, onResume
- **Tool Integration**: MCP tool calls and system integration
- **Service Architecture**: State, navigation, dialog, and notification services

## Development Features

### Debug Panel
- Real-time state inspection and modification
- JSON definition viewer with copy functionality
- Event log for runtime activities
- Runtime information and service status

### Hot Reload Support
- Instant UI updates during development
- State preservation across reloads
- Service continuity

## Getting Started

1. **Prerequisites**: Flutter SDK >=3.0.0
2. **Install dependencies**: `flutter pub get`
3. **Run the demo**: `flutter run`
4. **Run tests**: `flutter test`

## Demo Controls

- **Left Panel**: Select different feature demonstrations
- **Center Panel**: Interactive runtime UI
- **Right Panel**: Debug information (toggle with bug icon)
- **Full Screen**: View demos in isolation

## Key Demo Interactions

- **Application Type Demo**: Navigate between multiple pages with routing
- **Page Type Demo**: Interact with a simple single-page interface
- **Navigation Demo**: Explore different navigation patterns
- **Lifecycle Demo**: Watch initialization and state changes
- **Background Services**: Start/schedule different service types
- **State & Bindings**: Increment/decrement counters, observe computed properties
- **Notifications**: Create and manage different notification types
- **Tools Demo**: Execute MCP tool calls and system integration

## Advanced Features

### Application Type Definition
```json
{
  "type": "application",
  "properties": {
    "title": "Demo Application",
    "version": "1.0.0",
    "initialRoute": "/home"
  },
  "routes": {
    "/home": "resource://pages/home",
    "/profile": "resource://pages/profile"
  },
  "navigation": {
    "type": "drawer",
    "items": [...]
  }
}
```

### Background Services
```json
{
  "services": {
    "backgroundServices": {
      "dataSync": {
        "type": "periodic",
        "interval": 30000,
        "tool": "syncData"
      },
      "backup": {
        "type": "scheduled", 
        "schedule": "0 2 * * *",
        "tool": "performBackup"
      }
    }
  }
}
```

### State Management with Bindings
```json
{
  "state": {
    "initial": {
      "counter": 0,
      "message": "Hello!"
    },
    "computed": {
      "doubleCounter": "state.counter * 2",
      "isPositive": "state.counter > 0"
    },
    "watchers": [
      {
        "path": "counter",
        "debounceMs": 300,
        "actions": [...]
      }
    ]
  }
}
```

## Learn More

- **[MCP UI Runtime Documentation](../../README.md)**
- **[Widget Factory System](../../lib/src/widgets/README.md)**
- **[Service Architecture](../../lib/src/services/README.md)**
- **[State Management](../../lib/src/state/README.md)**

This demo represents the complete implementation of MCP UI DSL v1.0 with comprehensive runtime management, showcasing both application and page types, advanced navigation patterns, background services, and sophisticated state management - perfect for building dynamic, server-driven applications.