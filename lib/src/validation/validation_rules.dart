/// Validation rule types for MCP UI DSL v1.0
enum ValidationRuleType {
  required,
  minLength,
  maxLength,
  pattern,
  min,
  max,
  email,
  url,
  custom,
}

/// Property keys for MCP UI DSL v1.0
class PropertyKeys {
  static const String doubleClick = 'doubleClick';
  static const String rightClick = 'rightClick';
  static const String longPress = 'longPress';
  
  // Widget properties
  static const String type = 'type';
  static const String content = 'content';
  static const String label = 'label';
  static const String value = 'value';
  static const String binding = 'binding';
  static const String children = 'children';
  static const String items = 'items';
  static const String direction = 'direction';
  static const String alignment = 'alignment';
  static const String spacing = 'spacing';
  static const String padding = 'padding';
  static const String margin = 'margin';
  static const String width = 'width';
  static const String height = 'height';
  static const String style = 'style';
  static const String theme = 'theme';
  
  // Event properties
  static const String click = 'click';
  static const String change = 'change';
  static const String focus = 'focus';
  static const String blur = 'blur';
  static const String submit = 'submit';
  static const String itemClick = 'itemClick';
  static const String indexChange = 'indexChange';
  
  // Action properties
  static const String action = 'action';
  static const String tool = 'tool';
  static const String params = 'params';
  static const String args = 'args';
  static const String route = 'route';
  static const String uri = 'uri';
  static const String method = 'method';
  static const String target = 'target';
  static const String data = 'data';
}