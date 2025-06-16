import 'dart:io';
import 'package:flutter/foundation.dart';

/// Logger for MCP UI Runtime that outputs to stderr to avoid
/// interfering with MCP's STDIO transport protocol.
/// 
/// When using MCP's STDIO transport, stdout is reserved for protocol
/// messages. All logging must go to stderr to avoid breaking the
/// protocol communication.
class MCPLogger {
  final String name;
  final bool enableLogging;
  
  MCPLogger(this.name, {bool? enableLogging}) 
    : enableLogging = enableLogging ?? kDebugMode;
  
  /// Log a debug message
  void debug(String message) {
    if (!enableLogging) return;
    _log('DEBUG', message);
  }
  
  /// Log an info message
  void info(String message) {
    if (!enableLogging) return;
    _log('INFO', message);
  }
  
  /// Log a warning message
  void warning(String message) {
    if (!enableLogging) return;
    _log('WARN', message);
  }
  
  /// Log an error message
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (!enableLogging) return;
    _log('ERROR', message);
    if (error != null) {
      stderr.writeln('  Error: $error');
    }
    if (stackTrace != null) {
      stderr.writeln('  Stack trace:\n$stackTrace');
    }
  }
  
  void _log(String level, String message) {
    final timestamp = DateTime.now().toIso8601String();
    // Write to stderr to avoid interfering with MCP STDIO protocol
    stderr.writeln('[$timestamp] [$level] [$name] $message');
  }
  
  /// Factory constructor for creating a logger with a specific name
  factory MCPLogger.forClass(Type type, {bool? enableLogging}) {
    return MCPLogger(type.toString(), enableLogging: enableLogging);
  }
}