/// Result of an action execution
class ActionResult {
  final bool success;
  final String? error;
  final dynamic data;

  ActionResult._({
    required this.success,
    this.error,
    this.data,
  });

  /// Create a successful result
  factory ActionResult.success({dynamic data}) {
    return ActionResult._(
      success: true,
      data: data,
    );
  }

  /// Create an error result
  factory ActionResult.error(String message) {
    return ActionResult._(
      success: false,
      error: message,
    );
  }

  @override
  String toString() {
    if (success) {
      return 'ActionResult.success(data: $data)';
    } else {
      return 'ActionResult.error($error)';
    }
  }
}