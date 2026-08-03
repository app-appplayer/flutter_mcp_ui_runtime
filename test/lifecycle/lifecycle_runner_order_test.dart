// `onPause` means the instance survives.
//
// The unmount sequence used to open with `onPause`, citing §6.8.3 — which did
// say so, while §1.5.1 defined the same hook as losing focus *without* being
// destroyed and §1.5.2 drew it as half of `(onPause ↔ onResume)*`. The spec
// contradicted itself and the runtime followed the wrong half.
//
// What that cost an author: `onPause` reads as "stepping away, back shortly",
// so a draft save or a timer stop goes there. On a routed page it fired only
// on the way to destruction and `onResume` never fired at all — so the work
// appeared to run, and every return started from nothing.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/models/ui_definition.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/lifecycle_runner.dart';

LifecycleDefinition _allSeven() => LifecycleDefinition.fromJson(
      <String, dynamic>{
        for (final hook in <String>[
          'onInit',
          'onMount',
          'onReady',
          'onPause',
          'onResume',
          'onUnmount',
          'onDestroy',
        ])
          hook: <String, dynamic>{'type': 'tool', 'tool': hook},
      },
    );

void main() {
  late List<String> fired;
  late LifecycleRunner runner;

  setUp(() {
    fired = <String>[];
    runner = LifecycleRunner(
      lifecycle: _allSeven(),
      execute: (action) async => fired.add(action['tool'] as String),
    );
  });

  test('mount runs the three §1.5.2 hooks in order', () async {
    await runner.mount();
    expect(fired, <String>['onInit', 'onMount', 'onReady']);
  });

  test('a destroyed instance does not fire onPause', () async {
    await runner.mount();
    fired.clear();
    await runner.unmount();
    expect(fired, <String>['onUnmount', 'onDestroy']);
    expect(fired, isNot(contains('onPause')),
        reason: 'this instance is being destroyed — §1.5.1 reserves onPause '
            'for one that is not');
  });

  test('a surviving instance pauses and resumes', () async {
    await runner.mount();
    fired.clear();
    await runner.pause();
    await runner.resume();
    await runner.pause();
    await runner.resume();
    expect(fired,
        <String>['onPause', 'onResume', 'onPause', 'onResume'],
        reason: '§1.5.2 draws these as a pair that may cycle');
  });

  test('a paused instance that is then destroyed still skips onPause '
      'on the way out', () async {
    await runner.mount();
    await runner.pause();
    fired.clear();
    await runner.unmount();
    expect(fired, <String>['onUnmount', 'onDestroy']);
  });

  test('unmount is a no-op for an instance that never mounted', () async {
    await runner.unmount();
    expect(fired, isEmpty,
        reason: 'releasing what was never started would tear down a resource '
            'this definition does not hold');
  });

  test('mount and unmount are each idempotent', () async {
    await runner.mount();
    await runner.mount();
    await runner.unmount();
    await runner.unmount();
    expect(fired, <String>[
      'onInit',
      'onMount',
      'onReady',
      'onUnmount',
      'onDestroy',
    ]);
  });
}
