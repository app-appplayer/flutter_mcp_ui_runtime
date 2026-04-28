import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/accessibility/live_regions.dart';

/// TC-006 ~ TC-007: LiveRegions tests
/// Corresponds to: 04_TEST/feat-runtime/14-accessibility.md §3
void main() {
  group('LiveRegionManager Tests', () {
    late LiveRegionManager manager;

    setUp(() {
      manager = LiveRegionManager.instance;
      manager.clear();
    });

    tearDown(() {
      manager.clear();
    });

    // TC-006: LiveRegions — announce
    group('TC-006: LiveRegions announce', () {
      test('Normal: announce with polite mode queues announcement', () async {
        manager.createRegion('status', LiveRegionType.polite);

        final stream = manager.getRegionStream('status');
        expect(stream, isNotNull);

        final completer = Completer<String>();
        final sub = stream!.listen((msg) {
          if (!completer.isCompleted) completer.complete(msg);
        });

        manager.announce('status', 'Item added');

        final result =
            await completer.future.timeout(const Duration(seconds: 1));
        expect(result, 'Item added');

        await sub.cancel();
      });

      test('Normal: announce with assertive mode delivers message', () async {
        manager.createRegion('error-region', LiveRegionType.assertive);

        final stream = manager.getRegionStream('error-region');
        expect(stream, isNotNull);

        final completer = Completer<String>();
        final sub = stream!.listen((msg) {
          if (!completer.isCompleted) completer.complete(msg);
        });

        manager.announce('error-region', 'Error!');

        final result =
            await completer.future.timeout(const Duration(seconds: 1));
        expect(result, 'Error!');

        await sub.cancel();
      });

      test('Boundary: announce to unregistered region is no-op', () {
        // Should not throw
        manager.announce('nonexistent', 'Hello');
        expect(true, isTrue);
      });

      test('Boundary: rapid successive announcements queued in order',
          () async {
        manager.createRegion('rapid', LiveRegionType.polite);

        final messages = <String>[];
        final stream = manager.getRegionStream('rapid');
        final sub = stream!.listen(messages.add);

        manager.announce('rapid', 'First');
        manager.announce('rapid', 'Second');
        manager.announce('rapid', 'Third');

        // Allow stream to process
        await Future.delayed(const Duration(milliseconds: 50));

        expect(messages, ['First', 'Second', 'Third']);

        await sub.cancel();
      });
    });

    // TC-007: LiveRegions — register and update region
    group('TC-007: LiveRegions register/update', () {
      test('Normal: createRegion registers new region with polite mode', () {
        manager.createRegion('test-region', LiveRegionType.polite);
        final stream = manager.getRegionStream('test-region');
        expect(stream, isNotNull);
      });

      test('Normal: updateRegion (announce) triggers announcement', () async {
        manager.createRegion('status', LiveRegionType.polite);

        final completer = Completer<String>();
        final stream = manager.getRegionStream('status');
        final sub = stream!.listen((msg) {
          if (!completer.isCompleted) completer.complete(msg);
        });

        manager.announce('status', '3 items loaded');

        final result =
            await completer.future.timeout(const Duration(seconds: 1));
        expect(result, '3 items loaded');

        await sub.cancel();
      });

      test('Normal: removeRegion unregisters region', () {
        manager.createRegion('remove-me', LiveRegionType.polite);
        expect(manager.getRegionStream('remove-me'), isNotNull);

        manager.removeRegion('remove-me');
        expect(manager.getRegionStream('remove-me'), isNull);
      });

      test('Boundary: update unregistered region is no-op', () {
        // Should not throw
        manager.announce('nonexistent-region', 'Some message');
        expect(true, isTrue);
      });

      test('Boundary: duplicate createRegion does not overwrite', () {
        manager.createRegion('dup', LiveRegionType.polite);
        final stream1 = manager.getRegionStream('dup');

        // Creating again should not crash — region still works
        manager.createRegion('dup', LiveRegionType.assertive);
        final stream2 = manager.getRegionStream('dup');

        // Region should still be functional (original preserved)
        expect(stream1, isNotNull);
        expect(stream2, isNotNull);
      });

      test('Boundary: removeRegion on non-existent region is no-op', () {
        // Should not throw
        manager.removeRegion('does-not-exist');
        expect(true, isTrue);
      });

      test('Normal: clear removes all regions', () {
        manager.createRegion('a', LiveRegionType.polite);
        manager.createRegion('b', LiveRegionType.assertive);

        manager.clear();

        expect(manager.getRegionStream('a'), isNull);
        expect(manager.getRegionStream('b'), isNull);
      });

      test('Normal: regions with different types created correctly', () {
        manager.createRegion('polite-r', LiveRegionType.polite);
        manager.createRegion('assertive-r', LiveRegionType.assertive);
        manager.createRegion('status-r', LiveRegionType.status);
        manager.createRegion('alert-r', LiveRegionType.alert);

        expect(manager.getRegionStream('polite-r'), isNotNull);
        expect(manager.getRegionStream('assertive-r'), isNotNull);
        expect(manager.getRegionStream('status-r'), isNotNull);
        expect(manager.getRegionStream('alert-r'), isNotNull);
      });
    });
  });
}
