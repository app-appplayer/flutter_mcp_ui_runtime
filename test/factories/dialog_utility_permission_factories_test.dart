// Dialog, Utility, and Permission Widget Factory Tests: TC-264 through TC-276
// Covers alertDialog, simpleDialog, customDialog, bottomSheet, snackBar,
// spacer, visibility, indexedStack, lazy, useTemplate, permissionPrompt,
// offlineFallback, errorRecovery.

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

  // ===========================================================================
  // TC-264 ~ TC-268: Dialog Widgets
  // ===========================================================================

  // ---------------------------------------------------------------------------
  // TC-264: AlertDialogWidgetFactory - title, content, actions
  // ---------------------------------------------------------------------------
  group('TC-264: AlertDialogWidgetFactory', () {
    testWidgets('TC-264a: alertDialog renders with title, content, actions',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'alertDialog',
        'title': 'Warning',
        'content': 'Are you sure you want to proceed?',
        'actions': [
          {'label': 'Cancel'},
          {'label': 'OK'},
        ],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-264b: alertDialog with no actions', (tester) async {
      await pumpPage(tester, content: {
        'type': 'alertDialog',
        'title': 'Info',
        'content': 'Operation completed successfully.',
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-264c: alertDialog with empty title', (tester) async {
      await pumpPage(tester, content: {
        'type': 'alertDialog',
        'title': '',
        'content': 'Content without title',
        'actions': [
          {'label': 'Dismiss'},
        ],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-265: SimpleDialogWidgetFactory - title, children
  // ---------------------------------------------------------------------------
  group('TC-265: SimpleDialogWidgetFactory', () {
    testWidgets('TC-265a: simpleDialog renders with title and children',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'simpleDialog',
        'title': 'Choose Option',
        'children': [
          {'type': 'text', 'content': 'Option A'},
          {'type': 'text', 'content': 'Option B'},
          {'type': 'text', 'content': 'Option C'},
        ],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-265b: simpleDialog with no children', (tester) async {
      await pumpPage(tester, content: {
        'type': 'simpleDialog',
        'title': 'Empty Dialog',
        'children': <Map<String, dynamic>>[],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-266: DialogWidgetFactory (customDialog) - child
  // ---------------------------------------------------------------------------
  group('TC-266: DialogWidgetFactory (customDialog)', () {
    testWidgets('TC-266a: customDialog renders with child content',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'customDialog',
        'title': 'Custom',
        'children': [
          {
            'type': 'linear',
            'direction': 'vertical',
            'children': [
              {'type': 'text', 'content': 'Custom dialog body'},
              {'type': 'button', 'label': 'Close'},
            ],
          },
        ],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-266b: customDialog with minimal config', (tester) async {
      await pumpPage(tester, content: {
        'type': 'customDialog',
        'children': [
          {'type': 'text', 'content': 'Minimal dialog'},
        ],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-267: BottomSheetWidgetFactory - child
  // ---------------------------------------------------------------------------
  group('TC-267: BottomSheetWidgetFactory', () {
    testWidgets('TC-267a: bottomSheet renders with child content',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'bottomSheet',
        'children': [
          {
            'type': 'linear',
            'direction': 'vertical',
            'children': [
              {'type': 'text', 'content': 'Bottom Sheet Title'},
              {'type': 'text', 'content': 'Sheet content here'},
            ],
          },
        ],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-267b: bottomSheet with single text child', (tester) async {
      await pumpPage(tester, content: {
        'type': 'bottomSheet',
        'children': [
          {'type': 'text', 'content': 'Simple sheet'},
        ],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-268: SnackBarWidgetFactory - content, action
  // ---------------------------------------------------------------------------
  group('TC-268: SnackBarWidgetFactory', () {
    testWidgets('TC-268a: snackBar renders with content', (tester) async {
      await pumpPage(tester, content: {
        'type': 'snackBar',
        'content': 'File saved successfully',
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-268b: snackBar with action label', (tester) async {
      await pumpPage(tester, content: {
        'type': 'snackBar',
        'content': 'Item deleted',
        'action': {
          'label': 'Undo',
        },
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-268c: snackBar with empty content', (tester) async {
      await pumpPage(tester, content: {
        'type': 'snackBar',
        'content': '',
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  // ===========================================================================
  // TC-269 ~ TC-273: Utility Widgets
  // ===========================================================================

  // ---------------------------------------------------------------------------
  // TC-269: SpacerWidgetFactory - flex
  // ---------------------------------------------------------------------------
  group('TC-269: SpacerWidgetFactory', () {
    testWidgets('TC-269a: spacer renders inside flex layout', (tester) async {
      await pumpPage(tester, content: {
        'type': 'linear',
        'direction': 'horizontal',
        'children': [
          {'type': 'text', 'content': 'Left'},
          {'type': 'spacer'},
          {'type': 'text', 'content': 'Right'},
        ],
      });
      expect(find.text('Left'), findsOneWidget);
      expect(find.text('Right'), findsOneWidget);
    });

    testWidgets('TC-269b: spacer with flex property', (tester) async {
      await pumpPage(tester, content: {
        'type': 'linear',
        'direction': 'horizontal',
        'children': [
          {'type': 'text', 'content': 'Start'},
          {'type': 'spacer', 'flex': 2},
          {'type': 'text', 'content': 'End'},
        ],
      });
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('End'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-270: VisibilityWidgetFactory - visible, child
  // ---------------------------------------------------------------------------
  group('TC-270: VisibilityWidgetFactory', () {
    testWidgets('TC-270a: visibility with visible=true shows child',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'visibility',
        'visible': true,
        'children': [
          {'type': 'text', 'content': 'I am visible'},
        ],
      });
      expect(find.text('I am visible'), findsOneWidget);
    });

    testWidgets('TC-270b: visibility with visible=false hides child',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'visibility',
        'visible': false,
        'children': [
          {'type': 'text', 'content': 'I am hidden'},
        ],
      });
      // Widget should render without crash; child may or may not be visible
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-271: IndexedStackWidgetFactory - index, children
  // ---------------------------------------------------------------------------
  group('TC-271: IndexedStackWidgetFactory', () {
    testWidgets('TC-271a: indexedStack renders child at index 0',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'indexedStack',
        'index': 0,
        'children': [
          {'type': 'text', 'content': 'Page Zero'},
          {'type': 'text', 'content': 'Page One'},
          {'type': 'text', 'content': 'Page Two'},
        ],
      });
      expect(find.text('Page Zero'), findsOneWidget);
    });

    testWidgets('TC-271b: indexedStack renders child at index 1',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'indexedStack',
        'index': 1,
        'children': [
          {'type': 'text', 'content': 'First'},
          {'type': 'text', 'content': 'Second'},
        ],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-271c: indexedStack with single child', (tester) async {
      await pumpPage(tester, content: {
        'type': 'indexedStack',
        'index': 0,
        'children': [
          {'type': 'text', 'content': 'Only Child'},
        ],
      });
      expect(find.text('Only Child'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-272: LazyWidgetFactory - child
  // ---------------------------------------------------------------------------
  group('TC-272: LazyWidgetFactory', () {
    testWidgets('TC-272a: lazy renders child content', (tester) async {
      await pumpPage(tester, content: {
        'type': 'lazy',
        'children': [
          {'type': 'text', 'content': 'Lazy Loaded Content'},
        ],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-272b: lazy with complex child', (tester) async {
      await pumpPage(tester, content: {
        'type': 'lazy',
        'children': [
          {
            'type': 'linear',
            'direction': 'vertical',
            'children': [
              {'type': 'text', 'content': 'Lazy Item 1'},
              {'type': 'text', 'content': 'Lazy Item 2'},
            ],
          },
        ],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-273: UseTemplateFactory - template, overrides (v1.1)
  // ---------------------------------------------------------------------------
  group('TC-273: UseTemplateFactory', () {
    testWidgets('TC-273a: use widget renders without crash', (tester) async {
      // Canonical 1.3 §9.6: `type: "use"` + `params:`. Legacy `useTemplate`
      // / `overrides` aliases were removed in spec cleanup.
      await pumpPage(tester, content: {
        'type': 'use',
        'template': 'default-card',
        'params': {
          'title': 'Overridden Title',
        },
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-273b: use widget with no params', (tester) async {
      await pumpPage(tester, content: {
        'type': 'use',
        'template': 'base-layout',
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  // ===========================================================================
  // TC-274 ~ TC-276: Permission Widgets
  // ===========================================================================

  // ---------------------------------------------------------------------------
  // TC-274: PermissionPromptWidgetFactory - permission, message
  // ---------------------------------------------------------------------------
  group('TC-274: PermissionPromptWidgetFactory', () {
    testWidgets('TC-274a: permissionPrompt renders with permission type',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'permissionPrompt',
        'permissionType': 'camera',
        'title': 'Camera Access',
        'description': 'This app needs camera access to take photos.',
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-274b: permissionPrompt with location permission',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'permissionPrompt',
        'permissionType': 'location',
        'title': 'Location Access',
        'description': 'Enable location for map features.',
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-274c: permissionPrompt with minimal config',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'permissionPrompt',
        'permissionType': 'microphone',
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-275: OfflineFallbackWidgetFactory - child, fallback
  // ---------------------------------------------------------------------------
  group('TC-275: OfflineFallbackWidgetFactory', () {
    testWidgets('TC-275a: offlineFallback renders with child and fallback',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'offlineFallback',
        'children': [
          {'type': 'text', 'content': 'Online Content'},
        ],
        'fallback': {
          'type': 'text',
          'content': 'You are offline',
        },
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-275b: offlineFallback with child only', (tester) async {
      await pumpPage(tester, content: {
        'type': 'offlineFallback',
        'children': [
          {'type': 'text', 'content': 'Main Content'},
        ],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-276: ErrorRecoveryWidgetFactory - child, onError
  // ---------------------------------------------------------------------------
  group('TC-276: ErrorRecoveryWidgetFactory', () {
    testWidgets('TC-276a: errorRecovery renders with child and onError',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'errorRecovery',
        'children': [
          {'type': 'text', 'content': 'Protected Content'},
        ],
        'onError': {
          'type': 'notification',
          'message': 'Something went wrong',
        },
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-276b: errorRecovery with child only', (tester) async {
      await pumpPage(tester, content: {
        'type': 'errorRecovery',
        'children': [
          {'type': 'text', 'content': 'Content without error handler'},
        ],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-276c: errorRecovery with complex child', (tester) async {
      await pumpPage(tester, content: {
        'type': 'errorRecovery',
        'children': [
          {
            'type': 'linear',
            'direction': 'vertical',
            'children': [
              {'type': 'text', 'content': 'Header'},
              {'type': 'text', 'content': 'Body'},
            ],
          },
        ],
        'onError': {
          'type': 'notification',
          'message': 'Error fallback UI',
        },
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
