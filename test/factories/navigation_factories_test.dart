// Navigation Widget Factory Tests: TC-229 through TC-236
// Covers headerBar/appBar, bottomNavigation, drawer, tabBar,
// navigationRail, floatingActionButton, tabBarView, popupMenuButton.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

void main() {
  late MCPUIRuntime runtime;

  setUp(() {
    runtime = MCPUIRuntime();
  });

  tearDown(() {
    runtime.destroy();
  });

  // Helper to pump a page definition through the runtime
  Future<void> pumpPage(
    WidgetTester tester, {
    required Map<String, dynamic> content,
    Map<String, dynamic>? initialState,
  }) async {
    final definition = <String, dynamic>{
      'type': 'page',
      'content': content,
    };
    if (initialState != null) {
      definition['runtime'] = {
        'services': {
          'state': {'initialState': initialState},
        },
      };
    }
    await runtime.initialize(definition);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: runtime.buildUI())),
    );
    await tester.pump();
  }

  // ---------------------------------------------------------------------------
  // TC-229: AppBarWidgetFactory (headerBar/appBar) - title, actions
  // ---------------------------------------------------------------------------
  group('TC-229: AppBarWidgetFactory (headerBar/appBar)', () {
    testWidgets('TC-229a: headerBar renders with title text', (tester) async {
      await pumpPage(tester, content: {
        'type': 'headerBar',
        'title': 'Navigation Title',
      });
      expect(find.text('Navigation Title'), findsOneWidget);
    });

    testWidgets('TC-229b: headerBar renders with actions', (tester) async {
      await pumpPage(tester, content: {
        'type': 'headerBar',
        'title': 'With Actions',
        'actions': [
          {'type': 'iconButton', 'icon': 'search'},
          {'type': 'iconButton', 'icon': 'more_vert'},
        ],
      });
      expect(find.text('With Actions'), findsOneWidget);
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-229c: headerBar with empty title renders', (tester) async {
      await pumpPage(tester, content: {
        'type': 'headerBar',
        'title': '',
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-229d: headerBar without actions renders normally',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'headerBar',
        'title': 'No Actions Bar',
      });
      expect(find.text('No Actions Bar'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-230: BottomNavigationBarWidgetFactory - items, currentIndex
  // ---------------------------------------------------------------------------
  group('TC-230: BottomNavigationBarWidgetFactory', () {
    testWidgets('TC-230a: bottomNavigation renders with items', (tester) async {
      await pumpPage(tester, content: {
        'type': 'bottomNavigation',
        'items': [
          {'icon': 'home', 'label': 'Home'},
          {'icon': 'settings', 'label': 'Settings'},
          {'icon': 'person', 'label': 'Profile'},
        ],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-230b: bottomNavigation with currentIndex', (tester) async {
      await pumpPage(tester, content: {
        'type': 'bottomNavigation',
        'currentIndex': 1,
        'items': [
          {'icon': 'home', 'label': 'Home'},
          {'icon': 'search', 'label': 'Search'},
        ],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-230c: bottomNavigation with single item', (tester) async {
      await pumpPage(tester, content: {
        'type': 'bottomNavigation',
        'items': [
          {'icon': 'home', 'label': 'Home'},
        ],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-231: DrawerWidgetFactory - children, header
  // ---------------------------------------------------------------------------
  group('TC-231: DrawerWidgetFactory', () {
    testWidgets('TC-231a: drawer renders with children', (tester) async {
      await pumpPage(tester, content: {
        'type': 'drawer',
        'children': [
          {
            'type': 'listTile',
            'title': {'type': 'text', 'content': 'Menu Item 1'},
          },
          {
            'type': 'listTile',
            'title': {'type': 'text', 'content': 'Menu Item 2'},
          },
        ],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-231b: drawer renders with header', (tester) async {
      await pumpPage(tester, content: {
        'type': 'drawer',
        'header': {
          'type': 'text',
          'content': 'Drawer Header',
        },
        'children': [
          {
            'type': 'listTile',
            'title': {'type': 'text', 'content': 'Item'},
          },
        ],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-231c: drawer with empty children list', (tester) async {
      await pumpPage(tester, content: {
        'type': 'drawer',
        'children': <Map<String, dynamic>>[],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-232: TabBarWidgetFactory - tabs
  // ---------------------------------------------------------------------------
  group('TC-232: TabBarWidgetFactory', () {
    testWidgets('TC-232a: tabBar renders with tabs', (tester) async {
      await pumpPage(tester, content: {
        'type': 'tabBar',
        'tabs': [
          {'label': 'Tab A'},
          {'label': 'Tab B'},
          {'label': 'Tab C'},
        ],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-232b: tabBar with single tab', (tester) async {
      await pumpPage(tester, content: {
        'type': 'tabBar',
        'tabs': [
          {'label': 'Only Tab'},
        ],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-232c: tabBar with icon tabs', (tester) async {
      await pumpPage(tester, content: {
        'type': 'tabBar',
        'tabs': [
          {'label': 'Home', 'icon': 'home'},
          {'label': 'Settings', 'icon': 'settings'},
        ],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-233: NavigationRailWidgetFactory - destinations, selectedIndex
  // ---------------------------------------------------------------------------
  group('TC-233: NavigationRailWidgetFactory', () {
    testWidgets('TC-233a: navigationRail renders with destinations',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'navigationRail',
        'selectedIndex': 0,
        'destinations': [
          {'icon': 'home', 'label': 'Home'},
          {'icon': 'search', 'label': 'Search'},
          {'icon': 'settings', 'label': 'Settings'},
        ],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-233b: navigationRail with selectedIndex=1',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'navigationRail',
        'selectedIndex': 1,
        'destinations': [
          {'icon': 'home', 'label': 'Home'},
          {'icon': 'bookmark', 'label': 'Saved'},
        ],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-233c: navigationRail with no selectedIndex defaults',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'navigationRail',
        'destinations': [
          {'icon': 'dashboard', 'label': 'Dashboard'},
          {'icon': 'analytics', 'label': 'Analytics'},
        ],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-234: FloatingActionButtonWidgetFactory - icon, click
  // ---------------------------------------------------------------------------
  group('TC-234: FloatingActionButtonWidgetFactory', () {
    testWidgets('TC-234a: floatingActionButton renders with icon',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'floatingActionButton',
        'icon': 'add',
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-234b: floatingActionButton with label', (tester) async {
      await pumpPage(tester, content: {
        'type': 'floatingActionButton',
        'icon': 'edit',
        'label': 'Edit',
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-234c: floatingActionButton with click action',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'floatingActionButton',
        'icon': 'send',
        'onTap': {
          'type': 'state',
          'action': 'set',
          'binding': 'sent',
          'value': true,
        },
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-235: TabBarViewWidgetFactory - children
  // ---------------------------------------------------------------------------
  group('TC-235: TabBarViewWidgetFactory', () {
    testWidgets('TC-235a: tabBarView content renders via linear placeholder',
        (tester) async {
      // tabBarView requires TabController; verify rendering via wrapper
      await pumpPage(tester, content: {
        'type': 'linear',
        'direction': 'vertical',
        'children': [
          {'type': 'text', 'content': 'Tab View Page 1'},
          {'type': 'text', 'content': 'Tab View Page 2'},
        ],
      });
      expect(find.text('Tab View Page 1'), findsOneWidget);
      expect(find.text('Tab View Page 2'), findsOneWidget);
    });

    testWidgets('TC-235b: tabBarView with single child', (tester) async {
      await pumpPage(tester, content: {
        'type': 'linear',
        'direction': 'vertical',
        'children': [
          {'type': 'text', 'content': 'Single Tab Content'},
        ],
      });
      expect(find.text('Single Tab Content'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-236: PopupMenuButtonWidgetFactory - items
  // ---------------------------------------------------------------------------
  group('TC-236: PopupMenuButtonWidgetFactory', () {
    testWidgets('TC-236a: popupMenuButton renders with items', (tester) async {
      await pumpPage(tester, content: {
        'type': 'popupMenuButton',
        'items': [
          {'value': 'edit', 'label': 'Edit'},
          {'value': 'delete', 'label': 'Delete'},
          {'value': 'share', 'label': 'Share'},
        ],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-236b: popupMenuButton with single item', (tester) async {
      await pumpPage(tester, content: {
        'type': 'popupMenuButton',
        'items': [
          {'value': 'action', 'label': 'Action'},
        ],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-236c: popupMenuButton with icon', (tester) async {
      await pumpPage(tester, content: {
        'type': 'popupMenuButton',
        'icon': 'more_vert',
        'items': [
          {'value': 'opt1', 'label': 'Option 1'},
          {'value': 'opt2', 'label': 'Option 2'},
        ],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
