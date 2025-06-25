import 'package:flutter/foundation.dart';

/// Logger for MCP UI Runtime that outputs debug messages.
///
/// In debug mode, uses debugPrint for output. In release mode,
/// logging is disabled by default to avoid performance impact.
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
      _log('ERROR', '  Error: $error');
    }
    if (stackTrace != null) {
      _log('ERROR', '  Stack trace:\n$stackTrace');
    }
  }

  void _log(String level, String message) {
    final timestamp = DateTime.now().toIso8601String();
    // Use debugPrint to ensure it works on all platforms including web
    debugPrint('[$timestamp] [$level] [$name] $message');
  }

  /// Factory constructor for creating a logger with a specific name
  factory MCPLogger.forClass(Type type, {bool? enableLogging}) {
    return MCPLogger(type.toString(), enableLogging: enableLogging);
  }
}
