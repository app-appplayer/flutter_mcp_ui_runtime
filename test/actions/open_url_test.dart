/// `navigation.openUrl` — spec §4.3.3, §7.3.4.
///
/// The behaviour worth pinning is the refusal path. Every other navigation
/// sub-action stays inside the app; this one hands control to software the
/// runtime does not own, so the two ways it can go wrong — a scheme that must
/// never open, and a host that cannot open anything — both have to be
/// reported rather than swallowed.
library open_url_test;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';

void main() {
  late RenderContext context;
  late NavigationActionExecutor executor;
  late List<String> opened;

  setUp(() {
    final registry = WidgetRegistry();
    final state = StateManager();
    state.initialize({'link': 'https://example.com/from-state'});
    final binding = BindingEngine();
    final theme = ThemeManager();
    final actions = ActionHandler();
    context = RenderContext(
      renderer: Renderer(
        widgetRegistry: registry,
        bindingEngine: binding,
        actionHandler: actions,
        stateManager: state,
      ),
      stateManager: state,
      bindingEngine: binding,
      actionHandler: actions,
      themeManager: theme,
    );
    executor = NavigationActionExecutor();
    opened = [];
    NavigationActionExecutor.clearOnOpenUrlCallback();
  });

  tearDown(NavigationActionExecutor.clearOnOpenUrlCallback);

  Map<String, dynamic> openUrl(String url, {String? target}) => {
        'type': 'navigation',
        'action': 'openUrl',
        'url': url,
        if (target != null) 'target': target,
      };

  void wireHost({bool succeeds = true}) {
    NavigationActionExecutor.setOnOpenUrlCallback((url, target) async {
      opened.add('$url|$target');
      return succeeds;
    });
  }

  group('delegation', () {
    test('hands an absolute https URL to the host with the target', () async {
      wireHost();
      final r = await executor.execute(
          openUrl('https://example.com/terms', target: 'same'), context);
      expect(r.success, isTrue);
      expect(opened, ['https://example.com/terms|same']);
    });

    test('target defaults to new', () async {
      wireHost();
      await executor.execute(openUrl('https://example.com'), context);
      expect(opened.single.endsWith('|new'), isTrue);
    });

    test('resolves the binding before opening', () async {
      // §7.3.4 — a policy applied to "{{link}}" checks a literal, not the
      // value that will open.
      wireHost();
      final r = await executor.execute(openUrl('{{link}}'), context);
      expect(r.success, isTrue);
      expect(opened, ['https://example.com/from-state|new']);
    });

    test('mailto and tel reach the host — the policy blocks by list, not by '
        'allowlisting https alone', () async {
      wireHost();
      await executor.execute(openUrl('mailto:a@b.c'), context);
      await executor.execute(openUrl('tel:+15551234'), context);
      expect(opened.length, 2);
    });
  });

  group('refusal is reported, never silent', () {
    test('no host handler fails rather than succeeding', () async {
      final r = await executor.execute(
          openUrl('https://example.com'), context);
      expect(r.success, isFalse);
      expect(r.error, contains('openUrl'));
    });

    test('a host that returns false fails', () async {
      wireHost(succeeds: false);
      final r =
          await executor.execute(openUrl('https://example.com'), context);
      expect(r.success, isFalse);
      expect(opened, isNotEmpty, reason: 'the host was still asked');
    });

    test('a host that throws fails rather than propagating', () async {
      NavigationActionExecutor.setOnOpenUrlCallback(
          (url, target) async => throw StateError('no browser'));
      final r =
          await executor.execute(openUrl('https://example.com'), context);
      expect(r.success, isFalse);
      expect(r.error, contains('no browser'));
    });
  });

  group('scheme policy (§7.3.4)', () {
    test('blocked schemes never reach the host', () async {
      wireHost();
      for (final url in [
        'javascript:alert(1)',
        'data:text/html,<script>x</script>',
        'file:///etc/passwd',
        'blob:https://x/y',
        'vbscript:msgbox',
      ]) {
        final r = await executor.execute(openUrl(url), context);
        expect(r.success, isFalse, reason: url);
      }
      expect(opened, isEmpty,
          reason: 'a refused scheme must not be handed to the host at all');
    });

    test('scheme matching is case-insensitive', () async {
      wireHost();
      final r =
          await executor.execute(openUrl('JavaScript:alert(1)'), context);
      expect(r.success, isFalse);
      expect(opened, isEmpty);
    });

    test('a relative value is an error, not a route', () async {
      wireHost();
      final r = await executor.execute(openUrl('/orders'), context);
      expect(r.success, isFalse);
      expect(r.error, contains('absolute'));
      expect(opened, isEmpty);
    });

    test('an empty or missing url is an error', () async {
      wireHost();
      expect((await executor.execute(openUrl(''), context)).success, isFalse);
      expect(
        (await executor.execute(
                {'type': 'navigation', 'action': 'openUrl'}, context))
            .success,
        isFalse,
      );
    });
  });
}
