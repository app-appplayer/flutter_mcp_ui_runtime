import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_core/flutter_mcp_ui_core.dart';

/// TC-DASHBOARD-001 ~ TC-DASHBOARD-004
/// Corresponds to: 04_TEST/feat-v13-widgets.md §4
void main() {
  group('Dashboard Entry Point Tests', () {
    // TC-DASHBOARD-001: Dashboard rendering mode
    test('TC-DASHBOARD-001: DashboardConfig with content widget tree', () {
      final json = {
        'content': {
          'type': 'linear',
          'direction': 'vertical',
          'children': [
            {'type': 'text', 'content': 'Dashboard Title'},
            {'type': 'text', 'content': 'Status: Active'},
          ],
        },
      };

      final dashboard = DashboardConfig.fromJson(json);
      expect(dashboard.content['type'], 'linear');
      expect((dashboard.content['children'] as List).length, 2);
    });

    // TC-DASHBOARD-002: Dashboard refresh interval
    test('TC-DASHBOARD-002: Dashboard with refreshInterval', () {
      final json = {
        'content': {'type': 'text', 'content': 'Auto-refresh'},
        'refreshInterval': 5000,
      };

      final dashboard = DashboardConfig.fromJson(json);
      expect(dashboard.refreshInterval, 5000);
    });

    // TC-DASHBOARD-003: Dashboard click action
    test('TC-DASHBOARD-003: Dashboard onTap openApp action', () {
      final json = {
        'content': {'type': 'text', 'content': 'Click me'},
        'onTap': {
          'type': 'navigation',
          'action': 'openApp',
        },
      };

      final dashboard = DashboardConfig.fromJson(json);
      expect(dashboard.onTap, isNotNull);
      expect(dashboard.onTap!['type'], 'navigation');
      expect(dashboard.onTap!['action'], 'openApp');
    });

    // TC-DASHBOARD-004: Missing dashboard field
    test('TC-DASHBOARD-004: DashboardConfig is optional', () {
      // Verify that DashboardConfig can be null
      final dashJson = {
        'content': {'type': 'text', 'content': 'Test'},
      };
      final dashboard = DashboardConfig.fromJson(dashJson);
      expect(dashboard.content, isNotNull);
      // No onTap and no refreshInterval
      expect(dashboard.onTap, isNull);
      expect(dashboard.refreshInterval, isNull);
    });

    test('DashboardConfig serialization roundtrip', () {
      final original = DashboardConfig(
        content: {'type': 'text', 'content': 'Test'},
        refreshInterval: 3000,
        onTap: {'type': 'navigation', 'action': 'openApp'},
      );

      final json = original.toJson();
      final restored = DashboardConfig.fromJson(json);

      expect(restored.content, original.content);
      expect(restored.refreshInterval, original.refreshInterval);
      expect(restored.onTap, original.onTap);
    });

    test('DashboardConfig copyWith', () {
      final original = DashboardConfig(
        content: {'type': 'text', 'content': 'Original'},
        refreshInterval: 1000,
      );

      final modified = original.copyWith(refreshInterval: 5000);
      expect(modified.refreshInterval, 5000);
      expect(modified.content, original.content);
    });

    test('DashboardConfig equality', () {
      final content = {'type': 'text', 'content': 'Test'};
      final a = DashboardConfig(
        content: content,
        refreshInterval: 1000,
      );
      final b = DashboardConfig(
        content: content,
        refreshInterval: 1000,
      );

      // Same content reference → equal
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
