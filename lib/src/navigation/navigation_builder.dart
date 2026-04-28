import 'package:flutter/material.dart';
import '../form_factor/form_factor.dart';
import '../models/ui_definition.dart';
import '../utils/icon_resolver.dart';

/// Builds navigation UI based on [NavigationDefinition].
///
/// When the DSL declares `navigation: drawer` the builder returns one of
/// three equivalent Material containers picked from the active
/// [FormFactor] (responsive-rendering plan §3.2 tier B allow-list):
///
/// - `compact` → modal [Drawer] opened from the AppBar
/// - `medium` → [NavigationRail] beside the body
/// - `expanded` / `large` → permanent side drawer in a [Row]
///
/// `tabs` and `bottom` navigation types are not in the auto-swap
/// allow-list and render identically regardless of form factor.
class NavigationBuilder {
  static Widget buildNavigation({
    required NavigationDefinition navDefinition,
    required Widget body,
    required Function(String route) onNavigate,
    String? currentRoute,
    FormFactor? formFactor,
  }) {
    switch (navDefinition.type) {
      case 'drawer':
        final ff = formFactor ?? FormFactor.compact;
        switch (ff) {
          case FormFactor.compact:
          case FormFactor.embedded:
            return _buildDrawerNavigation(
              navDefinition: navDefinition,
              body: body,
              onNavigate: onNavigate,
              currentRoute: currentRoute,
            );
          case FormFactor.medium:
            return _buildRailNavigation(
              navDefinition: navDefinition,
              body: body,
              onNavigate: onNavigate,
              currentRoute: currentRoute,
              extended: false,
            );
          case FormFactor.expanded:
          case FormFactor.large:
          case FormFactor.extraLarge:
            return _buildPermanentDrawerNavigation(
              navDefinition: navDefinition,
              body: body,
              onNavigate: onNavigate,
              currentRoute: currentRoute,
            );
        }
      case 'tabs':
        return _buildTabNavigation(
          navDefinition: navDefinition,
          body: body,
          onNavigate: onNavigate,
          currentRoute: currentRoute,
        );
      case 'bottomNavigation':
      case 'bottom':
        return _buildBottomNavigation(
          navDefinition: navDefinition,
          body: body,
          onNavigate: onNavigate,
          currentRoute: currentRoute,
        );
      default:
        return body;
    }
  }

  static Widget _buildDrawerNavigation({
    required NavigationDefinition navDefinition,
    required Widget body,
    required Function(String route) onNavigate,
    String? currentRoute,
  }) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MCP Application'),
      ),
      drawer: Builder(
        builder: (bctx) => Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _buildDrawerHeader(bctx),
              ...navDefinition.items.map((item) => _buildDrawerItem(
                    item: item,
                    onNavigate: onNavigate,
                    isSelected: currentRoute == item.route,
                  )),
            ],
          ),
        ),
      ),
      body: body,
    );
  }

  static Widget _buildRailNavigation({
    required NavigationDefinition navDefinition,
    required Widget body,
    required Function(String route) onNavigate,
    String? currentRoute,
    required bool extended,
  }) {
    final selectedIndex =
        navDefinition.items.indexWhere((item) => item.route == currentRoute);
    return Scaffold(
      appBar: AppBar(title: const Text('MCP Application')),
      body: Row(
        children: [
          NavigationRail(
            extended: extended,
            selectedIndex: selectedIndex >= 0 ? selectedIndex : 0,
            onDestinationSelected: (index) =>
                onNavigate(navDefinition.items[index].route),
            labelType:
                extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
            destinations: navDefinition.items
                .map((item) => NavigationRailDestination(
                      icon: Icon(_getIconData(item.icon ?? 'home')),
                      label: Text(item.title),
                    ))
                .toList(),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: body),
        ],
      ),
    );
  }

  static Widget _buildPermanentDrawerNavigation({
    required NavigationDefinition navDefinition,
    required Widget body,
    required Function(String route) onNavigate,
    String? currentRoute,
  }) {
    return Scaffold(
      appBar: AppBar(title: const Text('MCP Application')),
      body: Row(
        children: [
          Builder(
            builder: (bctx) => Drawer(
              elevation: 0,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildDrawerHeader(bctx),
                  ...navDefinition.items.map((item) => _buildDrawerItem(
                        item: item,
                        onNavigate: onNavigate,
                        isSelected: currentRoute == item.route,
                      )),
                ],
              ),
            ),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: body),
        ],
      ),
    );
  }

  static Widget _buildTabNavigation({
    required NavigationDefinition navDefinition,
    required Widget body,
    required Function(String route) onNavigate,
    String? currentRoute,
  }) {
    return DefaultTabController(
      length: navDefinition.items.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('MCP Application'),
          bottom: TabBar(
            tabs: navDefinition.items
                .map((item) => Tab(
                      text: item.title,
                      icon: item.icon != null
                          ? Icon(_getIconData(item.icon!))
                          : null,
                    ))
                .toList(),
            onTap: (index) {
              final item = navDefinition.items[index];
              onNavigate(item.route);
            },
          ),
        ),
        body: body,
      ),
    );
  }

  static Widget _buildBottomNavigation({
    required NavigationDefinition navDefinition,
    required Widget body,
    required Function(String route) onNavigate,
    String? currentRoute,
  }) {
    final currentIndex = navDefinition.items.indexWhere(
      (item) => item.route == currentRoute,
    );

    return Scaffold(
      body: body,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: currentIndex >= 0 ? currentIndex : 0,
        onTap: (index) {
          final item = navDefinition.items[index];
          onNavigate(item.route);
        },
        items: navDefinition.items
            .map((item) => BottomNavigationBarItem(
                  icon: Icon(_getIconData(item.icon ?? 'home')),
                  label: item.title,
                ))
            .toList(),
      ),
    );
  }

  /// Drawer header uses the active theme's primary swatch + onPrimary
  /// text so it reads correctly in both light and dark modes rather than
  /// pinning to a Material-2 blue.
  static Widget _buildDrawerHeader(BuildContext bctx) {
    final cs = Theme.of(bctx).colorScheme;
    return DrawerHeader(
      decoration: BoxDecoration(color: cs.primary),
      child: Text(
        'Navigation',
        style: TextStyle(
          color: cs.onPrimary,
          fontSize: 24,
        ),
      ),
    );
  }

  static Widget _buildDrawerItem({
    required NavigationItem item,
    required Function(String route) onNavigate,
    bool isSelected = false,
  }) {
    return ListTile(
      leading: item.icon != null ? Icon(_getIconData(item.icon!)) : null,
      title: Text(item.title),
      selected: isSelected,
      onTap: () => onNavigate(item.route),
    );
  }

  static IconData _getIconData(String iconName) => resolveIconData(iconName);
}
