# MCP UI Runtime Demo Client

A Flutter application that demonstrates the full capabilities of the Flutter MCP UI Runtime by connecting to an MCP server and rendering dynamic UIs.

## Features

### MCP Server Integration
- **Automatic Connection**: Connects to the demo MCP server via stdio
- **Resource Discovery**: Fetches available UI resources from the server
- **Real-time Updates**: Handles MCP notifications for live data streaming
- **Tool Execution**: Executes server-side tools through the MCP protocol

### UI Capabilities
- **Dynamic UI Rendering**: Renders UI definitions received from the MCP server
- **State Management**: Maintains UI state with real-time updates
- **Data Binding**: Supports complex expressions and data bindings
- **Event Handling**: Processes user interactions and tool calls

### Demo Mode Fallback
- **Offline Support**: Falls back to demo mode when server is unavailable
- **Built-in UIs**: Includes dashboard, settings, and charts demo UIs
- **Tool Simulation**: Simulates tool execution in demo mode

## Getting Started

### Prerequisites
- Flutter SDK 3.0.0 or higher
- Dart SDK
- The demo MCP server (located in `../demo_mcp_server`)

### Running the Client

1. **Start the MCP Server** (in a separate terminal):
   ```bash
   cd ../demo_mcp_server
   dart run bin/server.dart
   ```

2. **Run the Flutter Client**:
   ```bash
   flutter run
   ```

The client will automatically attempt to connect to the MCP server. If the server is not available, it will offer to continue in demo mode.

## Architecture

### MCP Client Wrapper
The `MCPClientWrapper` class provides:
- Stdio-based communication with MCP servers
- Request/response handling with JSON-RPC
- Notification streaming
- Resource and tool management

### UI Rendering
The client uses `MCPUIRuntimeHelper` to:
- Parse UI definitions from the server
- Render Flutter widgets dynamically
- Handle state updates and data binding
- Process tool calls and events

### Connection States
1. **Connecting**: Attempting to establish MCP connection
2. **Connected**: Successfully connected to MCP server
3. **Demo Mode**: Running with built-in UI definitions
4. **Disconnected**: Failed to connect, showing error state

## Available UIs

### Dashboard
- Real-time metrics and statistics
- Interactive counter with server persistence
- Live data streaming with performance metrics
- Recent activity feed

### Settings
- Theme selection (light/dark/auto)
- Notification preferences
- Language settings
- Auto-sync configuration with intervals

### Charts
- Data visualization examples
- Dynamic chart generation
- Interactive data points

## Key Features Demonstrated

### State Management
```dart
// Server maintains state
{
  'counter': 0,
  'isStreaming': false,
  'streamData': {},
}

// Client updates via tool calls
await _mcpClient.callTool('increment_counter', {});
```

### Real-time Streaming
```dart
// Subscribe to server notifications
_mcpClient.notifications.listen((notification) {
  if (notification.method == 'stream/data') {
    // Handle streaming data
  }
});
```

### Tool Execution
```dart
// Execute server-side tools
final result = await _mcpClient.callTool('fetch_data', {
  'type': 'users'
});
```

### Dynamic UI Loading
```dart
// Fetch UI definition from server
final definition = await _mcpClient.readResource('ui://dashboard');

// Render using runtime
MCPUIRuntimeHelper.render(definition, onToolCall: _handleToolCall);
```

## Development

### Adding New Features
1. Update the MCP server to expose new resources or tools
2. The client will automatically discover and display them
3. Handle new notification types as needed

### Testing
Run the test suite:
```bash
flutter test
```

### Debugging
- Check the console for MCP communication logs
- Use the status bar to monitor connection state
- Server stderr output is displayed in the client console

## Troubleshooting

### Connection Issues
- Ensure the MCP server is running
- Check the server path in `_connectToMCPServer()`
- Verify Dart is in your PATH

### UI Rendering Issues
- Check the UI definition format
- Verify all required properties are present
- Review console for binding errors

### Tool Execution Failures
- Ensure tools are registered on the server
- Check tool parameters match schema
- Review server logs for errors