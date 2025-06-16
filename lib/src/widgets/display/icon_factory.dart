import 'package:flutter/material.dart';

import '../../renderer/render_context.dart';
import '../widget_factory.dart';

/// Factory for Icon widgets
class IconWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);
    
    // Extract properties
    final icon = properties['icon'] as String? ?? 'circle';
    final size = properties['size']?.toDouble() ?? 24.0;
    final color = parseColor(context.resolve(properties['color']));
    
    // Build icon
    Widget iconWidget = Icon(
      _parseIcon(icon),
      size: size,
      color: color,
    );
    
    return applyCommonWrappers(iconWidget, properties, context);
  }

  IconData _parseIcon(String iconName) {
    // Material Icons mapping - subset of most common icons
    switch (iconName) {
      // Navigation
      case 'home':
        return Icons.home;
      case 'menu':
        return Icons.menu;
      case 'arrow_back':
        return Icons.arrow_back;
      case 'arrow_forward':
        return Icons.arrow_forward;
      case 'arrow_upward':
        return Icons.arrow_upward;
      case 'arrow_downward':
        return Icons.arrow_downward;
      case 'close':
        return Icons.close;
      case 'more_vert':
        return Icons.more_vert;
      case 'more_horiz':
        return Icons.more_horiz;
      
      // Actions
      case 'add':
        return Icons.add;
      case 'remove':
        return Icons.remove;
      case 'edit':
        return Icons.edit;
      case 'delete':
        return Icons.delete;
      case 'save':
        return Icons.save;
      case 'check':
        return Icons.check;
      case 'clear':
        return Icons.clear;
      case 'refresh':
        return Icons.refresh;
      case 'search':
        return Icons.search;
      case 'filter_list':
        return Icons.filter_list;
      case 'sort':
        return Icons.sort;
      
      // Content
      case 'content_copy':
        return Icons.content_copy;
      case 'content_cut':
        return Icons.content_cut;
      case 'content_paste':
        return Icons.content_paste;
      case 'select_all':
        return Icons.select_all;
      
      // Media
      case 'play_arrow':
        return Icons.play_arrow;
      case 'pause':
        return Icons.pause;
      case 'stop':
        return Icons.stop;
      case 'volume_up':
        return Icons.volume_up;
      case 'volume_down':
        return Icons.volume_down;
      case 'volume_off':
        return Icons.volume_off;
      
      // Communication
      case 'call':
        return Icons.call;
      case 'message':
        return Icons.message;
      case 'email':
        return Icons.email;
      case 'share':
        return Icons.share;
      case 'send':
        return Icons.send;
      
      // Interface
      case 'settings':
        return Icons.settings;
      case 'help':
        return Icons.help;
      case 'info':
        return Icons.info;
      case 'warning':
        return Icons.warning;
      case 'error':
        return Icons.error;
      case 'check_circle':
        return Icons.check_circle;
      case 'cancel':
        return Icons.cancel;
      
      // Toggle
      case 'visibility':
        return Icons.visibility;
      case 'visibility_off':
        return Icons.visibility_off;
      case 'thumb_up':
        return Icons.thumb_up;
      case 'thumb_down':
        return Icons.thumb_down;
      case 'favorite':
        return Icons.favorite;
      case 'favorite_border':
        return Icons.favorite_border;
      case 'star':
        return Icons.star;
      case 'star_border':
        return Icons.star_border;
      
      // File/Folder
      case 'folder':
        return Icons.folder;
      case 'folder_open':
        return Icons.folder_open;
      case 'insert_drive_file':
        return Icons.insert_drive_file;
      case 'download':
        return Icons.download;
      case 'upload':
        return Icons.upload;
      case 'cloud':
        return Icons.cloud;
      case 'cloud_download':
        return Icons.cloud_download;
      case 'cloud_upload':
        return Icons.cloud_upload;
      
      // User
      case 'person':
        return Icons.person;
      case 'group':
        return Icons.group;
      case 'account_circle':
        return Icons.account_circle;
      case 'account_box':
        return Icons.account_box;
      
      // Location
      case 'location_on':
        return Icons.location_on;
      case 'location_off':
        return Icons.location_off;
      case 'map':
        return Icons.map;
      case 'place':
        return Icons.place;
      
      // Time
      case 'access_time':
        return Icons.access_time;
      case 'today':
        return Icons.today;
      case 'date_range':
        return Icons.date_range;
      case 'schedule':
        return Icons.schedule;
      
      // Device
      case 'phone':
        return Icons.phone;
      case 'computer':
        return Icons.computer;
      case 'tablet':
        return Icons.tablet;
      case 'watch':
        return Icons.watch;
      case 'tv':
        return Icons.tv;
      
      // Shopping
      case 'shopping_cart':
        return Icons.shopping_cart;
      case 'shopping_bag':
        return Icons.shopping_bag;
      case 'store':
        return Icons.store;
      case 'payment':
        return Icons.payment;
      case 'local_offer':
        return Icons.local_offer;
      
      default:
        return Icons.circle; // Default fallback icon
    }
  }
}