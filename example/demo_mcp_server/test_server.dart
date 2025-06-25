import 'dart:convert';
import 'dart:io';

void main() async {
  print('Testing MCP Server...');
  
  // Start the server process
  final process = await Process.start(
    'dart',
    ['run', 'bin/server.dart'],
    workingDirectory: Directory.current.path,
  );
  
  // Listen to server output
  process.stdout.transform(utf8.decoder).listen((data) {
    print('Server Output: $data');
  });
  
  process.stderr.transform(utf8.decoder).listen((data) {
    print('Server Error: $data');
  });
  
  // Send initialize request
  final initRequest = {
    'jsonrpc': '2.0',
    'id': 1,
    'method': 'initialize',
    'params': {
      'protocolVersion': '1.0.0',
      'capabilities': {},
      'clientInfo': {
        'name': 'Test Client',
        'version': '1.0.0',
      },
    },
  };
  
  print('Sending initialize request...');
  process.stdin.writeln(jsonEncode(initRequest));
  
  // Wait a bit
  await Future.delayed(const Duration(seconds: 2));
  
  // Send resources/list request
  final listRequest = {
    'jsonrpc': '2.0',
    'id': 2,
    'method': 'resources/list',
  };
  
  print('Sending resources/list request...');
  process.stdin.writeln(jsonEncode(listRequest));
  
  // Wait a bit
  await Future.delayed(const Duration(seconds: 2));
  
  // Send resource/read request
  final readRequest = {
    'jsonrpc': '2.0',
    'id': 3,
    'method': 'resources/read',
    'params': {
      'uri': 'ui://dashboard',
    },
  };
  
  print('Sending resources/read request...');
  process.stdin.writeln(jsonEncode(readRequest));
  
  // Wait a bit more
  await Future.delayed(const Duration(seconds: 3));
  
  // Send tool call request
  final toolRequest = {
    'jsonrpc': '2.0',
    'id': 4,
    'method': 'tools/call',
    'params': {
      'name': 'increment_counter',
      'arguments': {},
    },
  };
  
  print('Sending tool call request...');
  process.stdin.writeln(jsonEncode(toolRequest));
  
  // Wait and then kill
  await Future.delayed(const Duration(seconds: 2));
  
  print('Killing server...');
  process.kill();
  
  print('Test completed!');
}