import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:mcp_client/mcp_client.dart';

void main() async {
  stderr.writeln('[TEST] Starting MCP subscription test...');
  
  try {
    // Create client configuration
    final config = McpClient.simpleConfig(
      name: 'Test Subscription Client',
      version: '1.0.0',
      enableDebugLogging: true,
    );
    
    // Create STDIO transport
    final transportConfig = TransportConfig.stdio(
      command: 'dart',
      arguments: ['run', 'bin/server.dart'],
      workingDirectory: '../demo_mcp_server',
    );
    
    // Connect to server
    stderr.writeln('[TEST] Connecting to server...');
    final clientResult = await McpClient.createAndConnect(
      config: config,
      transportConfig: transportConfig,
    );
    
    if (clientResult.isFailure) {
      throw Exception('Failed to connect: ${clientResult.failureOrNull}');
    }
    
    final client = clientResult.get();
    stderr.writeln('[TEST] Connected successfully!');
    
    // List available resources
    final resources = await client.listResources();
    stderr.writeln('[TEST] Available resources:');
    for (final resource in resources) {
      stderr.writeln('  - ${resource.uri}: ${resource.name}');
    }
    
    // Setup notification handler
    var notificationCount = 0;
    client.onResourceContentUpdated((uri, content) {
      notificationCount++;
      stderr.writeln('[TEST] === NOTIFICATION #$notificationCount ===');
      stderr.writeln('[TEST] URI: $uri');
      stderr.writeln('[TEST] Content: ${content.text}');
      stderr.writeln('[TEST] MimeType: ${content.mimeType}');
      
      if (content.text != null) {
        try {
          final data = jsonDecode(content.text!);
          stderr.writeln('[TEST] Parsed data: $data');
        } catch (e) {
          stderr.writeln('[TEST] Failed to parse JSON: $e');
        }
      }
      stderr.writeln('[TEST] === END NOTIFICATION ===');
    });
    
    // Subscribe to temperature resource
    stderr.writeln('[TEST] Subscribing to data://temperature...');
    await client.subscribeResource('data://temperature');
    stderr.writeln('[TEST] Subscribed successfully!');
    
    // Read initial value
    stderr.writeln('[TEST] Reading initial temperature...');
    final resource = await client.readResource('data://temperature');
    final content = resource.contents.first;
    if (content.text != null) {
      final data = jsonDecode(content.text!);
      stderr.writeln('[TEST] Initial temperature: $data');
    }
    
    // Wait for notifications
    stderr.writeln('[TEST] Waiting for notifications (30 seconds)...');
    await Future.delayed(Duration(seconds: 30));
    
    stderr.writeln('[TEST] Total notifications received: $notificationCount');
    
    // Unsubscribe
    stderr.writeln('[TEST] Unsubscribing...');
    await client.unsubscribeResource('data://temperature');
    stderr.writeln('[TEST] Unsubscribed successfully!');
    
    // Wait a bit more to ensure no more notifications
    stderr.writeln('[TEST] Waiting 5 more seconds to ensure no notifications...');
    await Future.delayed(Duration(seconds: 5));
    
    stderr.writeln('[TEST] Final notification count: $notificationCount');
    
    // Cleanup
    client.dispose();
    stderr.writeln('[TEST] Test completed!');
    
  } catch (e, stackTrace) {
    stderr.writeln('[TEST] Error: $e');
    stderr.writeln('[TEST] Stack trace: $stackTrace');
  }
  
  exit(0);
}