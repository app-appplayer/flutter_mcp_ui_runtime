# Flutter MCP UI Runtime Examples

This directory contains demonstration applications showcasing the Flutter MCP UI Runtime capabilities.

## Overview

The Flutter MCP UI Runtime enables dynamic UI rendering from MCP (Model Context Protocol) server definitions. This example demonstrates:

1. **MCP Server** (`demo_mcp_server/`) - Serves UI definitions and handles real-time data
2. **Flutter Client** (`demo_mcp_client/`) - Connects to MCP server and renders dynamic UIs
3. **Runtime Demo** (`demo_mcp_runtime/`) - Standalone runtime feature demonstrations

## Quick Start

### Option 1: Using the Launch Script (Recommended)

```bash
cd demo_mcp_client
./run_demo.sh
```

This script will:
- Start the MCP server in the background
- Launch the Flutter client
- Handle cleanup on exit

### Option 2: Manual Launch

1. **Start the MCP Server**:
   ```bash
   cd demo_mcp_server
   dart run bin/server.dart
   ```

2. **Run the Flutter Client** (in a new terminal):
   ```bash
   cd demo_mcp_client
   flutter run
   ```

## Architecture

### MCP Server (`demo_mcp_server`)

The server demonstrates:
- **UI Resource Management**: Serves dashboard, settings, and charts UIs
- **Real-time Streaming**: Sends live data updates via MCP notifications
- **Tool Execution**: Handles client tool calls for UI interactions
- **State Persistence**: Maintains UI state across tool calls

Key features:
- Stdio-based MCP communication
- JSON-RPC 2.0 protocol implementation
- Dynamic UI definition generation
- Real-time data simulation

### Flutter Client (`demo_mcp_client`)

The client showcases:
- **MCP Connection**: Automatic server discovery and connection
- **Dynamic UI Rendering**: Renders UIs from server definitions
- **State Synchronization**: Maintains UI state with server updates
- **Tool Integration**: Executes server-side tools for actions
- **Fallback Mode**: Demo mode when server is unavailable

Key components:
- `MCPClientWrapper`: Handles MCP protocol communication
- `MCPUIRuntimeHelper`: Renders dynamic UIs from definitions
- State management with real-time updates
- Notification handling for streaming data

## Features Demonstrated

### 1. Dashboard UI
- **Live Metrics**: Real-time CPU, memory, network statistics
- **Interactive Counter**: Server-persisted counter state
- **Data Streaming**: Toggle real-time data updates
- **Activity Feed**: Recent system activities

### 2. Settings UI
- **Form Controls**: Dropdowns, switches, sliders
- **State Binding**: Two-way data binding
- **Conditional Rendering**: Dynamic UI based on state
- **Tool Execution**: Save settings to server

### 3. Charts UI
- **Data Visualization**: Chart rendering placeholder
- **Dynamic Data**: Generate chart data on demand
- **Empty States**: Conditional content display

## Advanced Features

### Real-time Streaming
```dart
// Server sends notifications
sendNotification('stream/data', {
  'cpu': cpuUsage,
  'memory': memoryUsage,
  'timestamp': DateTime.now()
});

// Client receives updates
_mcpClient.notifications.listen((notification) {
  if (notification.method == 'stream/data') {
    // Update UI with streaming data
  }
});
```

### Tool Execution
```dart
// Client calls server tool
await _mcpClient.callTool('increment_counter', {});

// Server handles tool
case 'increment_counter':
  _uiStates['dashboard']['counter']++;
  sendNotification('state/update', {...});
```

### State Management
```dart
// UI definition with state binding
{
  'type': 'text',
  'properties': {
    'content': {'binding': '"Count: " + state.counter'}
  }
}

// Actions update state
{
  'type': 'state.setValue',
  'path': 'counter',
  'value': 0
}
```

## Development Guide

### Adding New UIs

1. **Server Side** - Add UI definition in `server.dart`:
   ```dart
   case 'ui://newui':
     return getNewUI();
   ```

2. **Define UI Structure**:
   ```dart
   Map<String, dynamic> getNewUI() {
     return {
       'mcpRuntime': {
         'version': '1.0',
         'runtime': {...},
         'ui': {...}
       }
     };
   }
   ```

3. **Client Auto-Discovery**: The client will automatically discover and list the new UI

### Adding New Tools

1. **Register Tool** in server's `tools/list`:
   ```dart
   {
     'name': 'new_tool',
     'description': 'Tool description',
     'inputSchema': {...}
   }
   ```

2. **Implement Handler**:
   ```dart
   case 'new_tool':
     return handleNewTool(args);
   ```

### Custom Notifications

1. **Send from Server**:
   ```dart
   sendNotification('custom/event', {'data': value});
   ```

2. **Handle in Client**:
   ```dart
   case 'custom/event':
     _handleCustomEvent(notification.params);
   ```

## Testing

### Unit Tests
```bash
cd demo_mcp_client
flutter test
```

### Integration Testing
1. Start server and client
2. Verify connection status
3. Test UI interactions
4. Validate tool execution
5. Check streaming updates

## Troubleshooting

### Common Issues

1. **Connection Failed**
   - Ensure server is running
   - Check Dart is in PATH
   - Verify server path in client

2. **UI Not Rendering**
   - Check UI definition format
   - Validate JSON structure
   - Review console for errors

3. **Tools Not Working**
   - Verify tool registration
   - Check parameter schemas
   - Review server logs

### Debug Mode

Enable verbose logging:
```dart
// In MCPClientWrapper
print('MCP Request: $request');
print('MCP Response: $response');
```

## Resources

- [MCP Protocol Specification](https://modelcontextprotocol.io/)
- [Flutter MCP UI Runtime Documentation](../README.md)
- [Flutter Documentation](https://flutter.dev/docs)

## License

See the main project LICENSE file.