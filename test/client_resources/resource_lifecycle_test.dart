import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/client_resources/client_resource_resolver.dart';
import 'package:flutter_mcp_ui_runtime/src/core/client_resource_manager.dart'
    show ResourceLifecycleState;

void main() {
  group('ResourceEntry Lifecycle Tests', () {
    group('TC-023: loading -> ready transition', () {
      test('TC-023 Normal: initial state is loading', () {
        final entry = ResourceEntry(uri: 'client://file/test.txt');
        expect(entry.state, ResourceLifecycleState.loading);
      });

      test('TC-023 Normal: markReady transitions to ready', () {
        final entry = ResourceEntry(uri: 'client://file/test.txt');
        entry.markReady('content');
        expect(entry.state, ResourceLifecycleState.ready);
        expect(entry.content, 'content');
        expect(entry.error, isNull);
        expect(entry.loadedAt, isNotNull);
      });

      test('TC-023 Error: markError transitions to error', () {
        final entry = ResourceEntry(uri: 'client://file/test.txt');
        entry.markError('File not found');
        expect(entry.state, ResourceLifecycleState.error);
        expect(entry.error, 'File not found');
      });
    });

    group('TC-024: ready -> stale -> expired transitions', () {
      test('TC-024 Normal: ready resource becomes stale after staleDuration', () {
        final entry = ResourceEntry(
          uri: 'client://file/test.txt',
          staleDuration: Duration.zero,
          expireDuration: const Duration(hours: 1),
        );
        entry.markReady('content');
        expect(entry.state, ResourceLifecycleState.ready);

        // After updateState, should be stale since staleDuration is zero
        entry.updateState();
        expect(entry.state, ResourceLifecycleState.stale);
      });

      test('TC-024 Boundary: stale resource becomes expired after expireDuration', () {
        final entry = ResourceEntry(
          uri: 'client://file/test.txt',
          staleDuration: Duration.zero,
          expireDuration: Duration.zero,
        );
        entry.markReady('content');

        entry.updateState();
        expect(entry.state, ResourceLifecycleState.expired);
      });
    });

    group('TC-025: expired state behavior', () {
      test('TC-025 Normal: expired resource detected by updateState', () {
        final entry = ResourceEntry(
          uri: 'client://file/test.txt',
          staleDuration: Duration.zero,
          expireDuration: Duration.zero,
        );
        entry.markReady('content');
        entry.updateState();
        expect(entry.state, ResourceLifecycleState.expired);
      });
    });

    group('TC-026: error state behavior', () {
      test('TC-026 Normal: error state is set by markError', () {
        final entry = ResourceEntry(uri: 'client://file/test.txt');
        entry.markError('Network failure');
        expect(entry.state, ResourceLifecycleState.error);
        expect(entry.error, 'Network failure');
      });

      test('TC-026 Normal: updateState does not change error state', () {
        final entry = ResourceEntry(uri: 'client://file/test.txt');
        entry.markError('Network failure');
        entry.updateState();
        expect(entry.state, ResourceLifecycleState.error);
      });

      test('TC-026 Normal: retry from error transitions to ready', () {
        final entry = ResourceEntry(uri: 'client://file/test.txt');
        entry.markError('Network failure');
        // Simulate retry by marking ready again
        entry.markReady('retry content');
        expect(entry.state, ResourceLifecycleState.ready);
        expect(entry.content, 'retry content');
        expect(entry.error, isNull);
      });
    });

    group('TC-027: disposed state (terminal)', () {
      test('TC-027 Normal: dispose sets state to disposed and clears content', () {
        final entry = ResourceEntry(uri: 'client://file/test.txt');
        entry.markReady('content');
        entry.dispose();
        expect(entry.state, ResourceLifecycleState.disposed);
        expect(entry.content, isNull);
        expect(entry.error, isNull);
      });

      test('TC-027 Normal: updateState does not change disposed state', () {
        final entry = ResourceEntry(uri: 'client://file/test.txt');
        entry.markReady('content');
        entry.dispose();
        entry.updateState();
        expect(entry.state, ResourceLifecycleState.disposed);
      });
    });
  });
}
