import 'dart:convert';
import 'dart:io';

/// Starts the demo_ui server, reads every page via MCP protocol,
/// then feeds each page JSON to a minimal rendering check.
void main() async {
  final server = await Process.start(
    './server',
    [],
    workingDirectory: Directory.current.path,
  );

  server.stderr.transform(utf8.decoder).listen((_) {});

  final lines = server.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter());

  final responses = <int, Map<String, dynamic>>{};
  int nextId = 1;

  lines.listen((line) {
    try {
      final json = jsonDecode(line) as Map<String, dynamic>;
      final id = json['id'] as int?;
      if (id != null) responses[id] = json;
    } catch (_) {}
  });

  void send(Map<String, dynamic> msg) {
    server.stdin.writeln(jsonEncode(msg));
  }

  Future<Map<String, dynamic>?> request(String method, Map<String, dynamic> params) async {
    final id = nextId++;
    send({'jsonrpc': '2.0', 'id': id, 'method': method, 'params': params});
    for (int i = 0; i < 30; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (responses.containsKey(id)) return responses.remove(id);
    }
    return null;
  }

  // Initialize
  await request('initialize', {
    'protocolVersion': '2024-11-05',
    'capabilities': {},
    'clientInfo': {'name': 'render-test', 'version': '1.0'},
  });
  send({'jsonrpc': '2.0', 'method': 'notifications/initialized'});
  await Future.delayed(const Duration(milliseconds: 500));

  // Read ui://app to get routes
  final appResp = await request('resources/read', {'uri': 'ui://app'});
  final appText = appResp?['result']?['contents']?[0]?['text'] as String?;
  if (appText == null) {
    stderr.writeln('FAIL: Could not read ui://app');
    server.kill();
    exit(1);
  }

  final appDef = jsonDecode(appText) as Map<String, dynamic>;
  final routes = appDef['routes'] as Map<String, dynamic>? ?? {};

  stderr.writeln('=== App: ${appDef['title']} ===');
  stderr.writeln('Routes: ${routes.keys.join(', ')}');
  stderr.writeln('Navigation: ${(appDef['navigation'] as Map?)?['type']}');
  stderr.writeln('');

  int pass = 0;
  int fail = 0;
  final failures = <String>[];

  // Read and validate each page
  for (final entry in routes.entries) {
    final route = entry.key;
    final uri = entry.value as String;

    final pageResp = await request('resources/read', {'uri': uri});
    final pageText = pageResp?['result']?['contents']?[0]?['text'] as String?;

    if (pageText == null) {
      fail++;
      failures.add('$route ($uri): FAIL — no content returned');
      continue;
    }

    try {
      final pageDef = jsonDecode(pageText) as Map<String, dynamic>;
      final content = pageDef['content'] as Map<String, dynamic>?;

      if (content == null) {
        fail++;
        failures.add('$route: FAIL — no content field');
        continue;
      }

      // Recursively check all widget types
      final issues = <String>[];
      _validateWidget(content, route, issues);

      if (issues.isEmpty) {
        pass++;
        stderr.writeln('PASS: $route — ${_countWidgets(content)} widgets');
      } else {
        fail++;
        for (final issue in issues) {
          failures.add('$route: $issue');
        }
        stderr.writeln('FAIL: $route — ${issues.length} issue(s)');
      }
    } catch (e) {
      fail++;
      failures.add('$route: FAIL — parse error: $e');
    }
  }

  stderr.writeln('');
  stderr.writeln('=== Results: $pass pass, $fail fail ===');
  if (failures.isNotEmpty) {
    stderr.writeln('');
    stderr.writeln('Failures:');
    for (final f in failures) {
      stderr.writeln('  - $f');
    }
  }

  server.kill();
  exit(fail > 0 ? 1 : 0);
}

/// Known valid widget types from the runtime's default_widgets.dart
const _knownTypes = <String>{
  'linear', 'box', 'container', 'stack', 'center', 'align', 'padding',
  'sizedBox', 'expanded', 'flexible', 'spacer', 'wrap', 'positioned',
  'intrinsicHeight', 'intrinsicWidth', 'visibility', 'aspectRatio',
  'conditional', 'indexedStack', 'constrained', 'fractionallySized',
  'column', 'row', 'flow', 'margin', 'safeArea',
  'text', 'richText', 'image', 'icon', 'card', 'divider', 'badge', 'chip',
  'avatar', 'tooltip', 'placeholder', 'banner', 'progressBar', 'progress',
  'loadingIndicator', 'verticalDivider', 'decoration',
  'button', 'textInput', 'textField', 'textfield', 'textFormField',
  'select', 'dropdown', 'toggle', 'switch', 'slider', 'rangeSlider',
  'checkbox', 'radio', 'radioGroup', 'checkboxGroup', 'numberField',
  'colorPicker', 'dateField', 'timeField', 'datePicker', 'timePicker',
  'dateRangePicker', 'segmentedControl', 'stepper', 'numberStepper',
  'iconButton', 'form', 'rating',
  'list', 'listView', 'grid', 'listTile',
  'headerBar', 'appbar', 'bottomNavigation', 'bottomNav',
  'bottomnavigationbar', 'tabBar', 'tabBarView', 'drawer',
  'navigationRail', 'floatingActionButton', 'popupMenuButton',
  'scrollView', 'singleChildScrollView', 'scrollBar', 'pageView',
  'animatedContainer', 'opacity', 'transform', 'lottieAnimation',
  'gestureDetector', 'inkWell', 'draggable', 'dragTarget',
  'alertDialog', 'snackBar', 'bottomSheet', 'simpleDialog', 'customDialog',
  'chart', 'map', 'mediaPlayer', 'calendar', 'timeline', 'gauge',
  'heatmap', 'tree', 'graph', 'codeEditor', 'terminal', 'fileExplorer',
  'markdown', 'webView', 'signature', 'networkGraph', 'canvas',
  'table', 'dataTable', 'lazy', 'accessibleWrapper',
  'use', 'dashboard',
};

void _validateWidget(Map<String, dynamic> widget, String path, List<String> issues) {
  final type = widget['type'] as String?;
  if (type == null) {
    issues.add('Widget without type at $path');
    return;
  }

  if (!_knownTypes.contains(type)) {
    issues.add('Unknown widget type: "$type"');
  }

  // Check for key collisions (duplicate 'type' key — Dart map deduplicates silently)
  // This can't be detected after JSON parse, but we check for suspicious combinations
  if (type == 'linear' && widget.containsKey('value') && !widget.containsKey('direction')) {
    issues.add('Possible key collision: type="linear" with "value" — was this meant to be progressBar?');
  }

  // Recursively check children
  final child = widget['child'];
  if (child is Map<String, dynamic>) {
    _validateWidget(child, '$path > $type.child', issues);
  }

  final children = widget['children'];
  if (children is List) {
    for (int i = 0; i < children.length; i++) {
      if (children[i] is Map<String, dynamic>) {
        _validateWidget(children[i], '$path > $type[$i]', issues);
      }
    }
  }

  // Check itemTemplate
  final itemTemplate = widget['itemTemplate'] ?? widget['template'];
  if (itemTemplate is Map<String, dynamic>) {
    _validateWidget(itemTemplate, '$path > $type.itemTemplate', issues);
  }

  // Check nested action widgets
  for (final key in ['leading', 'trailing', 'title', 'subtitle', 'content']) {
    final nested = widget[key];
    if (nested is Map<String, dynamic> && nested.containsKey('type')) {
      _validateWidget(nested, '$path > $type.$key', issues);
    }
  }

  // Check dialog content
  final dialog = widget['dialog'];
  if (dialog is Map<String, dynamic>) {
    final dialogContent = dialog['content'];
    if (dialogContent is Map<String, dynamic>) {
      _validateWidget(dialogContent, '$path > dialog.content', issues);
    }
  }
}

int _countWidgets(Map<String, dynamic> widget) {
  int count = 1;
  final child = widget['child'];
  if (child is Map<String, dynamic>) count += _countWidgets(child);

  final children = widget['children'];
  if (children is List) {
    for (final c in children) {
      if (c is Map<String, dynamic>) count += _countWidgets(c);
    }
  }

  for (final key in ['leading', 'trailing', 'title', 'subtitle', 'content', 'itemTemplate', 'template']) {
    final nested = widget[key];
    if (nested is Map<String, dynamic> && nested.containsKey('type')) {
      count += _countWidgets(nested);
    }
  }

  return count;
}
