import 'package:flutter/material.dart';
import '../models/ui_definition.dart';

/// Builds navigation UI based on NavigationDefinition
class NavigationBuilder {
  static Widget buildNavigation({
    required NavigationDefinition navDefinition,
    required Widget body,
    required Function(String route) onNavigate,
    String? currentRoute,
  }) {
    switch (navDefinition.type) {
      case 'drawer':
        return _buildDrawerNavigation(
          navDefinition: navDefinition,
          body: body,
          onNavigate: onNavigate,
          currentRoute: currentRoute,
        );
      case 'tabs':
        return _buildTabNavigation(
          navDefinition: navDefinition,
          body: body,
          onNavigate: onNavigate,
          currentRoute: currentRoute,
        );
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
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                'Navigation',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ...navDefinition.items.map((item) => _buildDrawerItem(
              item: item,
              onNavigate: onNavigate,
              isSelected: currentRoute == item.route,
            )),
          ],
        ),
      ),
      body: body,
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
            tabs: navDefinition.items.map((item) => Tab(
              text: item.title,
              icon: item.icon != null ? Icon(_getIconData(item.icon!)) : null,
            )).toList(),
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
        items: navDefinition.items.map((item) => BottomNavigationBarItem(
          icon: Icon(_getIconData(item.icon ?? 'home')),
          label: item.title,
        )).toList(),
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

  static IconData _getIconData(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'home':
      case 'dashboard':
        return Icons.home;
      case 'settings':
        return Icons.settings;
      case 'person':
      case 'profile':
        return Icons.person;
      case 'menu':
        return Icons.menu;
      case 'search':
        return Icons.search;
      case 'favorite':
      case 'heart':
        return Icons.favorite;
      case 'star':
        return Icons.star;
      case 'add':
        return Icons.add;
      case 'edit':
        return Icons.edit;
      case 'delete':
        return Icons.delete;
      case 'info':
        return Icons.info;
      case 'warning':
        return Icons.warning;
      case 'error':
        return Icons.error;
      case 'check':
        return Icons.check;
      case 'close':
        return Icons.close;
      case 'arrow_back':
        return Icons.arrow_back;
      case 'arrow_forward':
        return Icons.arrow_forward;
      case 'refresh':
        return Icons.refresh;
      case 'download':
        return Icons.download;
      case 'upload':
        return Icons.upload;
      case 'share':
        return Icons.share;
      case 'email':
        return Icons.email;
      case 'phone':
        return Icons.phone;
      case 'location':
        return Icons.location_on;
      case 'calendar':
        return Icons.calendar_today;
      case 'clock':
        return Icons.access_time;
      case 'calculate':
      case 'calculator':
        return Icons.calculate;
      case 'thermostat':
      case 'temperature':
        return Icons.thermostat;
      default:
        return Icons.circle;
    }
  }
}