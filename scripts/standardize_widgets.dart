#!/usr/bin/env dart

import 'dart:io';

/// Script to help standardize widget factories to follow MCP UI DSL v1.0
void main() async {
  final singleChildWidgets = {
    'container', 'center', 'padding', 'align', 'sizedbox',
    'expanded', 'flexible', 'aspectratio', 'fittedbox',
    'constrainedbox', 'limitedbox', 'intrinsicheight', 
    'intrinsicwidth', 'baseline', 'positioned',
    'singlechildscrollview', 'cliprrect', 'clipoval',
    'decoratedbox', 'tooltip', 'card', 'inkwell',
    'gesturedetector', 'visibility', 'banner', 'badge',
    'placeholder', 'animatedcontainer', 'floatingactionbutton'
  };
  
  final multiChildWidgets = {
    'column', 'row', 'stack', 'wrap', 'flow',
    'listview', 'gridview', 'table', 'pageview',
    'popupmenubutton', 'drawer'
  };
  
  print('Widget Standardization Helper');
  print('=============================\n');
  
  // Read all widget factory files
  final widgetsDir = Directory('lib/src/widgets');
  final files = await widgetsDir
      .list(recursive: true)
      .where((entity) => entity is File && entity.path.endsWith('_factory.dart'))
      .cast<File>()
      .toList();
  
  print('Found ${files.length} widget factory files\n');
  
  for (final file in files) {
    final content = await file.readAsString();
    final fileName = file.path.split('/').last;
    
    // Extract widget type from filename
    final widgetType = fileName
        .replaceAll('_factory.dart', '')
        .replaceAll('_', '');
    
    // Check if file needs updating
    if (content.contains("properties['children'] as List<dynamic>? ??") &&
        content.contains("definition['children']")) {
      
      print('File: $fileName');
      
      if (singleChildWidgets.contains(widgetType)) {
        print('  Type: Single-child widget');
        print('  Action: Convert to use properties["child"]');
        print('  Pattern to replace:');
        print('    FROM: properties["children"] ?? definition["children"]');
        print('    TO: properties["child"] as Map<String, dynamic>?');
      } else if (multiChildWidgets.contains(widgetType)) {
        print('  Type: Multi-child widget');
        print('  Action: Use only definition["children"]');
        print('  Pattern to replace:');
        print('    FROM: properties["children"] ?? definition["children"]');
        print('    TO: definition["children"] as List<dynamic>?');
      } else {
        print('  Type: Unknown - needs manual review');
      }
      print('');
    }
  }
  
  print('\nSummary:');
  print('- Single-child widgets: Place child in properties.child');
  print('- Multi-child widgets: Place children at root level');
  print('- No-child widgets: No children property needed');
}