import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/offline/connectivity_manager.dart';

void main() {
  group('ConnectivityManager Tests', () {
    late ConnectivityManager connectivity;

    setUp(() {
      connectivity = ConnectivityManager();
    });

    tearDown(() {
      connectivity.dispose();
    });

    group('TC-001: Network status binding - online', () {
      test('TC-001 Normal: online status set correctly', () {
        connectivity.updateStatus(NetworkStatus.online, type: NetworkType.wifi);
        expect(connectivity.status, NetworkStatus.online);
        expect(connectivity.isOnline, true);
        expect(connectivity.isOffline, false);
      });

      test('TC-001 Boundary: transition from offline to online', () async {
        connectivity.updateStatus(NetworkStatus.offline);
        expect(connectivity.isOffline, true);

        final completer = Completer<NetworkStatus>();
        connectivity.statusStream.listen((status) {
          if (!completer.isCompleted) completer.complete(status);
        });

        connectivity.updateStatus(NetworkStatus.online);
        final status = await completer.future;
        expect(status, NetworkStatus.online);
      });
    });

    group('TC-002: Network status binding - offline', () {
      test('TC-002 Normal: offline status set correctly', () {
        connectivity.updateStatus(NetworkStatus.offline);
        expect(connectivity.status, NetworkStatus.offline);
        expect(connectivity.isOffline, true);
        expect(connectivity.isOnline, false);
      });

      test('TC-002 Normal: type set to none when offline', () {
        connectivity.updateStatus(NetworkStatus.online, type: NetworkType.wifi);
        connectivity.updateStatus(NetworkStatus.offline);
        expect(connectivity.type, NetworkType.none);
      });

      test('TC-002 Boundary: transition from online to offline', () async {
        connectivity.updateStatus(NetworkStatus.online);

        final completer = Completer<NetworkStatus>();
        connectivity.statusStream.listen((status) {
          if (!completer.isCompleted) completer.complete(status);
        });

        connectivity.updateStatus(NetworkStatus.offline);
        final status = await completer.future;
        expect(status, NetworkStatus.offline);
      });
    });

    group('TC-003: Network status binding - slow', () {
      test('TC-003 Normal: slow status detected', () {
        connectivity.updateStatus(NetworkStatus.slow, type: NetworkType.cellular);
        expect(connectivity.status, NetworkStatus.slow);
        expect(connectivity.type, NetworkType.cellular);
      });
    });

    group('TC-004: Network type binding', () {
      test('TC-004 Normal: wifi type', () {
        connectivity.updateStatus(NetworkStatus.online, type: NetworkType.wifi);
        expect(connectivity.type, NetworkType.wifi);
      });

      test('TC-004 Normal: cellular type', () {
        connectivity.updateStatus(
            NetworkStatus.online, type: NetworkType.cellular);
        expect(connectivity.type, NetworkType.cellular);
      });

      test('TC-004 Normal: ethernet type', () {
        connectivity.updateStatus(
            NetworkStatus.online, type: NetworkType.ethernet);
        expect(connectivity.type, NetworkType.ethernet);
      });

      test('TC-004 Boundary: unknown type', () {
        connectivity.updateStatus(
            NetworkStatus.online, type: NetworkType.unknown);
        expect(connectivity.type, NetworkType.unknown);
      });
    });

    group('TC-005: Connectivity state transitions', () {
      test('TC-005 Normal: status change notifies all listeners', () async {
        final statuses = <NetworkStatus>[];
        connectivity.statusStream.listen((s) => statuses.add(s));

        connectivity.updateStatus(NetworkStatus.online);
        connectivity.updateStatus(NetworkStatus.offline);
        connectivity.updateStatus(NetworkStatus.online);

        await Future<void>.delayed(Duration.zero);

        expect(statuses, [
          NetworkStatus.online,
          NetworkStatus.offline,
          NetworkStatus.online,
        ]);
      });

      test('TC-005 Normal: same status does not fire notification', () async {
        final statuses = <NetworkStatus>[];
        connectivity.statusStream.listen((s) => statuses.add(s));

        connectivity.updateStatus(NetworkStatus.online);
        connectivity.updateStatus(NetworkStatus.online);

        await Future<void>.delayed(Duration.zero);

        expect(statuses.length, 1);
      });

      test('TC-005 Normal: lastStatusChange updated on change', () {
        expect(connectivity.lastStatusChange, isNull);

        connectivity.updateStatus(NetworkStatus.online);
        expect(connectivity.lastStatusChange, isNotNull);
      });
    });

    group('onStatusChange callback', () {
      test('callback receives previous and current status', () {
        NetworkStatus? prev;
        NetworkStatus? current;

        connectivity.onStatusChange((p, c) {
          prev = p;
          current = c;
        });

        connectivity.updateStatus(NetworkStatus.online);
        expect(prev, NetworkStatus.unknown);
        expect(current, NetworkStatus.online);

        connectivity.updateStatus(NetworkStatus.offline);
        expect(prev, NetworkStatus.online);
        expect(current, NetworkStatus.offline);
      });

      test('unregister callback stops notifications', () {
        int callCount = 0;
        final unregister = connectivity.onStatusChange((p, c) => callCount++);

        connectivity.updateStatus(NetworkStatus.online);
        expect(callCount, 1);

        unregister();
        connectivity.updateStatus(NetworkStatus.offline);
        expect(callCount, 1);
      });
    });

    group('statusDescription', () {
      test('online description includes type', () {
        connectivity.updateStatus(NetworkStatus.online, type: NetworkType.wifi);
        expect(connectivity.statusDescription, contains('Online'));
        expect(connectivity.statusDescription, contains('wifi'));
      });

      test('offline description', () {
        connectivity.updateStatus(NetworkStatus.offline);
        expect(connectivity.statusDescription, 'Offline');
      });

      test('slow description includes type', () {
        connectivity.updateStatus(
            NetworkStatus.slow, type: NetworkType.cellular);
        expect(connectivity.statusDescription, contains('Slow'));
      });

      test('unknown description', () {
        expect(connectivity.statusDescription, 'Unknown');
      });
    });

    group('Initial state', () {
      test('default status is unknown', () {
        expect(connectivity.status, NetworkStatus.unknown);
      });

      test('default type is unknown', () {
        expect(connectivity.type, NetworkType.unknown);
      });
    });
  });
}
