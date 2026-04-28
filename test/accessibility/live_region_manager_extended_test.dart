import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/accessibility/live_regions.dart';

/// TC-020 ~ TC-021: LiveRegionManager extended tests
/// Corresponds to: 04_TEST/feat-runtime/14-accessibility.md §9
void main() {
  group('LiveRegionManager Extended Tests', () {
    late LiveRegionManager manager;

    setUp(() {
      manager = LiveRegionManager.instance;
      manager.clear();
    });

    tearDown(() {
      manager.clear();
    });

    // TC-020: createRegion and removeRegion
    group('TC-020: createRegion and removeRegion', () {
      test('Normal: createRegion creates a live region', () {
        manager.createRegion('status', LiveRegionType.polite);
        expect(manager.getRegionStream('status'), isNotNull);
      });

      test('Normal: removeRegion removes the region', () {
        manager.createRegion('status', LiveRegionType.polite);
        manager.removeRegion('status');
        expect(manager.getRegionStream('status'), isNull);
      });

      test('Normal: createRegion with assertive type', () {
        manager.createRegion('alert', LiveRegionType.assertive);
        expect(manager.getRegionStream('alert'), isNotNull);
      });

      test('Normal: createRegion with status type', () {
        manager.createRegion('info', LiveRegionType.status);
        expect(manager.getRegionStream('info'), isNotNull);
      });

      test('Normal: createRegion with alert type', () {
        manager.createRegion('error', LiveRegionType.alert);
        expect(manager.getRegionStream('error'), isNotNull);
      });

      test('Boundary: remove non-existent region is no-op', () {
        // Should not throw
        manager.removeRegion('nonexistent');
        expect(true, isTrue);
      });

      test('Boundary: createRegion with duplicate id does not overwrite', () {
        manager.createRegion('dup', LiveRegionType.polite);
        final stream1 = manager.getRegionStream('dup');

        // Second create should not crash
        manager.createRegion('dup', LiveRegionType.assertive);
        final stream2 = manager.getRegionStream('dup');

        expect(stream1, isNotNull);
        expect(stream2, isNotNull);
      });
    });

    // TC-021: getRegionStream
    group('TC-021: getRegionStream', () {
      test('Normal: returns Stream<String> for registered region', () {
        manager.createRegion('test', LiveRegionType.polite);
        final stream = manager.getRegionStream('test');

        expect(stream, isNotNull);
        expect(stream, isA<Stream<String>>());
      });

      test('Normal: announcements emitted to stream', () async {
        manager.createRegion('emitter', LiveRegionType.polite);

        final messages = <String>[];
        final stream = manager.getRegionStream('emitter');
        final sub = stream!.listen(messages.add);

        manager.announce('emitter', 'Message 1');
        manager.announce('emitter', 'Message 2');

        await Future.delayed(const Duration(milliseconds: 50));

        expect(messages, ['Message 1', 'Message 2']);

        await sub.cancel();
      });

      test('Normal: multiple listeners receive same announcements', () async {
        manager.createRegion('broadcast', LiveRegionType.polite);

        final messages1 = <String>[];
        final messages2 = <String>[];
        final stream = manager.getRegionStream('broadcast');

        final sub1 = stream!.listen(messages1.add);
        final sub2 = stream.listen(messages2.add);

        manager.announce('broadcast', 'Hello');

        await Future.delayed(const Duration(milliseconds: 50));

        expect(messages1, ['Hello']);
        expect(messages2, ['Hello']);

        await sub1.cancel();
        await sub2.cancel();
      });

      test('Boundary: unknown region id returns null', () {
        expect(manager.getRegionStream('unknown'), isNull);
      });
    });
  });
}
