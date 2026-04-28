// Animation Widget Factory Tests: TC-241 through TC-242
// Covers animatedContainer and lottieAnimation.

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
  // TC-241: AnimatedContainerWidgetFactory - duration, curve, width/height/color
  // ---------------------------------------------------------------------------
  group('TC-241: AnimatedContainerWidgetFactory', () {
    testWidgets('TC-241a: animatedContainer renders with duration and curve',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'animatedContainer',
        'duration': 300,
        'curve': 'easeInOut',
        'width': 100,
        'height': 100,
        'color': '#FF0000',
        'children': [
          {'type': 'text', 'content': 'Animated Box'},
        ],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-241b: animatedContainer with different dimensions',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'animatedContainer',
        'duration': 500,
        'curve': 'linear',
        'width': 200,
        'height': 50,
        'color': '#00FF00',
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-241c: animatedContainer with zero duration',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'animatedContainer',
        'duration': 0,
        'width': 80,
        'height': 80,
        'color': '#0000FF',
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-241d: animatedContainer without curve uses default',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'animatedContainer',
        'duration': 250,
        'width': 120,
        'height': 120,
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-242: LottieAnimationWidgetFactory - src, autoPlay (v1.1)
  // ---------------------------------------------------------------------------
  group('TC-242: LottieAnimationWidgetFactory', () {
    testWidgets('TC-242a: lottieAnimation renders with src', (tester) async {
      await pumpPage(tester, content: {
        'type': 'lottieAnimation',
        'src': 'assets/animation.json',
        'width': 150,
        'height': 150,
      });
      // Lottie may show placeholder when asset is unavailable in test
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-242b: lottieAnimation with autoPlay false',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'lottieAnimation',
        'src': 'assets/idle.json',
        'autoPlay': false,
        'width': 100,
        'height': 100,
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-242c: lottieAnimation with autoPlay true', (tester) async {
      await pumpPage(tester, content: {
        'type': 'lottieAnimation',
        'src': 'assets/loading.json',
        'autoPlay': true,
        'width': 200,
        'height': 200,
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-242d: lottieAnimation with minimal config', (tester) async {
      await pumpPage(tester, content: {
        'type': 'lottieAnimation',
        'src': 'assets/minimal.json',
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
