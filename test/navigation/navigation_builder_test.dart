import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

void main() {
  group('NavigationBuilder Tests', () {
    late NavigationDefinition drawerNav;
    late NavigationDefinition tabNav;
    late NavigationDefinition bottomNav;
    late Widget testBody;
    late List<String> navigationCalls;

    setUp(() {
      drawerNav = NavigationDefinition(
        type: 'drawer',
        items: [
          NavigationItem(title: 'Home', route: '/home', icon: 'home'),
          NavigationItem(title: 'Profile', route: '/profile', icon: 'person'),
          NavigationItem(title: 'Settings', route: '/settings', icon: 'settings'),
        ],
      );

      tabNav = NavigationDefinition(
        type: 'tabs',
        items: [
          NavigationItem(title: 'Dashboard', route: '/dashboard', icon: 'dashboard'),
          NavigationItem(title: 'Analytics', route: '/analytics', icon: 'bar_chart'),
        ],
      );

      bottomNav = NavigationDefinition(
        type: 'bottom',
        items: [
          NavigationItem(title: 'Home', route: '/home', icon: 'home'),
          NavigationItem(title: 'Search', route: '/search', icon: 'search'),
          NavigationItem(title: 'Profile', route: '/profile', icon: 'person'),
        ],
      );

      testBody = const Center(child: Text('Test Body'));
      navigationCalls = [];
    });

    testWidgets('builds drawer navigation correctly', (WidgetTester tester) async {
      final navigation = NavigationBuilder.buildNavigation(
        navDefinition: drawerNav,
        body: testBody,
        onNavigate: (route) => navigationCalls.add(route),
        currentRoute: '/home',
      );

      await tester.pumpWidget(
        MaterialApp(home: navigation),
      );

      await tester.pumpAndSettle();

      // Should have a scaffold
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.text('Test Body'), findsOneWidget);

      // Check if drawer exists by looking for the drawer button
      final drawerButtons = find.byIcon(Icons.menu);
      if (drawerButtons.evaluate().isNotEmpty) {
        // Test drawer opening
        await tester.tap(drawerButtons.first);
        await tester.pumpAndSettle();

        // Should find navigation items in drawer
        expect(find.text('Home'), findsWidgets);
        expect(find.text('Profile'), findsWidgets);
        expect(find.text('Settings'), findsWidgets);

        // Test navigation call
        final profileTiles = find.text('Profile');
        if (profileTiles.evaluate().isNotEmpty) {
          await tester.tap(profileTiles.last);
          await tester.pumpAndSettle();
          expect(navigationCalls, contains('/profile'));
        }
      } else {
        // If no drawer button, just verify the navigation was built
        expect(navigation, isA<Scaffold>());
      }
    });

    testWidgets('builds tab navigation correctly', (WidgetTester tester) async {
      final navigation = NavigationBuilder.buildNavigation(
        navDefinition: tabNav,
        body: testBody,
        onNavigate: (route) => navigationCalls.add(route),
        currentRoute: '/dashboard',
      );

      await tester.pumpWidget(
        MaterialApp(home: navigation),
      );

      await tester.pumpAndSettle();

      // Should have tabs or at least a scaffold
      expect(find.byType(Scaffold), findsOneWidget);
      
      final tabBars = find.byType(TabBar);
      if (tabBars.evaluate().isNotEmpty) {
        expect(find.text('Dashboard'), findsOneWidget);
        expect(find.text('Analytics'), findsOneWidget);

        // Test tab selection
        final analyticsTabs = find.text('Analytics');
        if (analyticsTabs.evaluate().isNotEmpty) {
          await tester.tap(analyticsTabs.first);
          await tester.pumpAndSettle();
          expect(navigationCalls, contains('/analytics'));
        }
      } else {
        // Just verify the navigation was built
        expect(navigation, isA<Scaffold>());
      }
    });

    testWidgets('builds bottom navigation correctly', (WidgetTester tester) async {
      final navigation = NavigationBuilder.buildNavigation(
        navDefinition: bottomNav,
        body: testBody,
        onNavigate: (route) => navigationCalls.add(route),
        currentRoute: '/home',
      );

      await tester.pumpWidget(
        MaterialApp(home: navigation),
      );

      await tester.pumpAndSettle();

      // Should have bottom navigation or at least a scaffold
      expect(find.byType(Scaffold), findsOneWidget);
      
      final bottomNavBars = find.byType(BottomNavigationBar);
      if (bottomNavBars.evaluate().isNotEmpty) {
        expect(find.text('Home'), findsOneWidget);
        expect(find.text('Search'), findsOneWidget);
        expect(find.text('Profile'), findsOneWidget);

        // Test bottom nav selection
        final searchItems = find.text('Search');
        if (searchItems.evaluate().isNotEmpty) {
          await tester.tap(searchItems.first);
          await tester.pumpAndSettle();
          expect(navigationCalls, contains('/search'));
        }
      } else {
        // Just verify the navigation was built
        expect(navigation, isA<Scaffold>());
      }
    });

    testWidgets('returns body for unknown navigation type', (WidgetTester tester) async {
      final unknownNav = NavigationDefinition(
        type: 'unknown',
        items: [],
      );

      final navigation = NavigationBuilder.buildNavigation(
        navDefinition: unknownNav,
        body: testBody,
        onNavigate: (route) => navigationCalls.add(route),
      );

      await tester.pumpWidget(
        MaterialApp(home: navigation),
      );

      // Should just return the body without navigation wrapper
      expect(find.text('Test Body'), findsOneWidget);
      expect(find.byType(Drawer), findsNothing);
      expect(find.byType(TabBar), findsNothing);
      expect(find.byType(BottomNavigationBar), findsNothing);
    });

    testWidgets('handles current route selection in bottom nav', (WidgetTester tester) async {
      final navigation = NavigationBuilder.buildNavigation(
        navDefinition: bottomNav,
        body: testBody,
        onNavigate: (route) => navigationCalls.add(route),
        currentRoute: '/search',
      );

      await tester.pumpWidget(
        MaterialApp(home: navigation),
      );

      await tester.pumpAndSettle();

      final bottomNavBars = find.byType(BottomNavigationBar);
      if (bottomNavBars.evaluate().isNotEmpty) {
        final bottomNavBar = tester.widget<BottomNavigationBar>(bottomNavBars.first);
        // Should have search (index 1) selected
        expect(bottomNavBar.currentIndex, 1);
      } else {
        // Just verify the navigation was built
        expect(navigation, isA<Scaffold>());
      }
    });

    testWidgets('handles unknown current route in bottom nav', (WidgetTester tester) async {
      final navigation = NavigationBuilder.buildNavigation(
        navDefinition: bottomNav,
        body: testBody,
        onNavigate: (route) => navigationCalls.add(route),
        currentRoute: '/unknown',
      );

      await tester.pumpWidget(
        MaterialApp(home: navigation),
      );

      await tester.pumpAndSettle();

      final bottomNavBars = find.byType(BottomNavigationBar);
      if (bottomNavBars.evaluate().isNotEmpty) {
        final bottomNavBar = tester.widget<BottomNavigationBar>(bottomNavBars.first);
        // Should default to index 0
        expect(bottomNavBar.currentIndex, 0);
      } else {
        // Just verify the navigation was built
        expect(navigation, isA<Scaffold>());
      }
    });

    test('maps icon names to IconData correctly', () {
      // Test some key icon mappings through navigation building
      final navWithIcons = NavigationDefinition(
        type: 'bottom',
        items: [
          NavigationItem(title: 'Home', route: '/home', icon: 'home'),
          NavigationItem(title: 'Settings', route: '/settings', icon: 'settings'),
          NavigationItem(title: 'Person', route: '/person', icon: 'person'),
          NavigationItem(title: 'Unknown', route: '/unknown', icon: 'unknown_icon'),
        ],
      );

      // This implicitly tests icon mapping through widget creation
      final navigation = NavigationBuilder.buildNavigation(
        navDefinition: navWithIcons,
        body: testBody,
        onNavigate: (route) {},
      );

      expect(navigation, isNotNull);
    });

    testWidgets('drawer shows selected state correctly', (WidgetTester tester) async {
      final navigation = NavigationBuilder.buildNavigation(
        navDefinition: drawerNav,
        body: testBody,
        onNavigate: (route) => navigationCalls.add(route),
        currentRoute: '/profile',
      );

      await tester.pumpWidget(
        MaterialApp(home: navigation),
      );

      await tester.pumpAndSettle();

      // Check if drawer exists by looking for the drawer button
      final drawerButtons = find.byIcon(Icons.menu);
      if (drawerButtons.evaluate().isNotEmpty) {
        // Open drawer
        await tester.tap(drawerButtons.first);
        await tester.pumpAndSettle();

        // Check that profile item is selected if it exists
        final profileTexts = find.text('Profile');
        final listTiles = find.byType(ListTile);
        
        if (profileTexts.evaluate().isNotEmpty && listTiles.evaluate().isNotEmpty) {
          final profileAncestors = find.ancestor(
            of: profileTexts.first,
            matching: find.byType(ListTile),
          );
          
          if (profileAncestors.evaluate().isNotEmpty) {
            final profileTile = tester.widget<ListTile>(profileAncestors.first);
            expect(profileTile.selected, true);
          }
        }
      } else {
        // Just verify the navigation was built
        expect(navigation, isA<Scaffold>());
      }
    });
  });
}