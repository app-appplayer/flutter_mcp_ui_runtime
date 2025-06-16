import 'dart:convert';
import 'dart:io';

void main() async {
  print('Testing MCP server...');
  
  // Start server process
  final serverProcess = await Process.start(
    'dart',
    ['run', 'bin/server.dart'],
    workingDirectory: '.',
  );
  
  // Give server time to start
  await Future.delayed(Duration(seconds: 2));
  
  // Send initialize request
  final initializeRequest = {
    'jsonrpc': '2.0',
    'id': 1,
    'method': 'initialize',
    'params': {
      'protocolVersion': '2024-11-05',
      'capabilities': {
        'tools': {},
        'resources': {},
      },
      'clientInfo': {
        'name': 'test-client',
        'version': '1.0.0',
      },
    },
  };
  
  print('Sending initialize request...');
  serverProcess.stdin.writeln(jsonEncode(initializeRequest));
  
  // Listen to server output
  serverProcess.stdout.transform(utf8.decoder).listen((data) {
    print('Server response: $data');
  });
  
  serverProcess.stderr.transform(utf8.decoder).listen((data) {
    print('Server error: $data');
  });
  
  // Wait a bit for response
  await Future.delayed(Duration(seconds: 3));
  
  // Send resources/list request
  final resourcesRequest = {
    'jsonrpc': '2.0',
    'id': 2,
    'method': 'resources/list',
    'params': {},
  };
  
  print('Sending resources/list request...');
  serverProcess.stdin.writeln(jsonEncode(resourcesRequest));
  
  // Wait for response
  await Future.delayed(Duration(seconds: 2));
  
  // Clean up
  serverProcess.kill();
  print('Test completed.');
}