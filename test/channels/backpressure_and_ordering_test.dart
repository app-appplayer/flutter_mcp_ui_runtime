// `BackpressureController` (CH-07) and `MessageOrderer` (CH-08).
//
// Two hundred and forty lines of stream plumbing with no test at all. Both
// decide which of a server's messages a document ever sees — one by dropping
// them on purpose, the other by holding them back until the gaps fill — so a
// mistake here does not crash anything. It shows up as a chart missing a
// reading, or a log arriving shuffled, weeks later and unreproducibly.
//
// Every test drives a real broadcast stream and compares what came out the far
// end against what went in.

import 'dart:async';

import 'package:flutter_mcp_ui_runtime/src/channels/channel_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StreamController<dynamic> source;

  setUp(() => source = StreamController<dynamic>.broadcast());
  tearDown(() async {
    if (!source.isClosed) await source.close();
  });

  /// Collects from [stream] while [feed] pushes into the source.
  ///
  /// The controllers under test only subscribe to the source in `onListen`, so
  /// nothing may be pushed before the collector is attached — feeding first
  /// would test a stream nobody was listening to.
  Future<List<dynamic>> collect(
    Stream<dynamic> stream,
    Future<void> Function() feed, {
    Duration settle = const Duration(milliseconds: 50),
  }) async {
    final received = <dynamic>[];
    final subscription = stream.listen(received.add);
    await Future<void>.delayed(Duration.zero);
    await feed();
    await Future<void>.delayed(settle);
    await subscription.cancel();
    return received;
  }

  group('backpressure: buffer', () {
    test('every event reaches the listener', () async {
      final controller = BackpressureController(
        strategy: BackpressureStrategy.buffer,
        bufferSize: 3,
      );

      final received = await collect(controller.apply(source.stream), () async {
        for (var i = 0; i < 6; i++) {
          source.add(i);
        }
      });

      expect(received, [0, 1, 2, 3, 4, 5],
          reason: 'the buffer strategy keeps a bounded HISTORY; it is not a '
              'filter, and dropping live events here would silently lose data '
              'from a fast feed');
    });

    test('an error travels through and the close closes', () async {
      final controller = BackpressureController(
        strategy: BackpressureStrategy.buffer,
      );
      final errors = <Object>[];
      var done = false;
      final subscription = controller.apply(source.stream).listen(
            (_) {},
            onError: errors.add,
            onDone: () => done = true,
          );
      addTearDown(subscription.cancel);
      await Future<void>.delayed(Duration.zero);

      source.addError(StateError('wire broke'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(errors, hasLength(1),
          reason: 'an error swallowed by the transformer leaves the document '
              'showing stale data with no indication anything is wrong');

      await source.close();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(done, isTrue);
    });
  });

  group('backpressure: drop', () {
    test('the first bufferSize events pass and the rest are discarded',
        () async {
      final controller = BackpressureController(
        strategy: BackpressureStrategy.drop,
        bufferSize: 3,
      );

      final received = await collect(controller.apply(source.stream), () async {
        for (var i = 0; i < 10; i++) {
          source.add(i);
        }
      });

      expect(received, [0, 1, 2],
          reason: 'drop keeps the OLDEST — a document using this strategy is '
              'saying the first readings matter, so emitting the newest '
              'instead would invert its intent');
    });
  });

  group('backpressure: latest', () {
    test('a burst collapses to its last value', () async {
      final controller =
          BackpressureController(strategy: BackpressureStrategy.latest);

      final received = await collect(controller.apply(source.stream), () async {
        source.add('a');
        source.add('b');
        source.add('c');
      });

      expect(received, ['c'],
          reason: 'a gauge bound to a fast sensor only ever needs the current '
              'reading; emitting all three would be the buffer strategy. '
              'This is what caught the original defect: the collapse was '
              'scheduled on a microtask, which always ran between two stream '
              'events, so `latest` delivered everything');
    });

    test('separate bursts each emit their own last value', () async {
      final controller =
          BackpressureController(strategy: BackpressureStrategy.latest);

      final received = await collect(controller.apply(source.stream), () async {
        source.add(1);
        source.add(2);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        source.add(3);
        source.add(4);
      });

      expect(received, [2, 4],
          reason: 'collapsing across bursts would freeze the display between '
              'them');
    });
  });

  group('backpressure: throttle', () {
    test('one event per window gets through', () async {
      final controller = BackpressureController(
        strategy: BackpressureStrategy.throttle,
        windowMs: 80,
      );

      final received = await collect(
        controller.apply(source.stream),
        () async {
          source.add('first');
          source.add('immediately after'); // inside the window — dropped
          await Future<void>.delayed(const Duration(milliseconds: 120));
          source.add('next window');
        },
        settle: const Duration(milliseconds: 60),
      );

      expect(received, ['first', 'next window']);
    });
  });

  group('backpressure: debounce', () {
    test('only the last event of a burst is emitted, after the quiet period',
        () async {
      final controller = BackpressureController(
        strategy: BackpressureStrategy.debounce,
        windowMs: 60,
      );

      final received = <dynamic>[];
      final subscription =
          controller.apply(source.stream).listen(received.add);
      addTearDown(subscription.cancel);
      await Future<void>.delayed(Duration.zero);

      source.add('typing');
      source.add('typing t');
      source.add('typing th');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(received, isEmpty,
          reason: 'nothing may be emitted while the burst is still going — '
              'that is the difference between debounce and throttle');

      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(received, ['typing th']);
    });

    test('a close cancels the pending timer instead of firing after it',
        () async {
      final controller = BackpressureController(
        strategy: BackpressureStrategy.debounce,
        windowMs: 60,
      );

      final received = <dynamic>[];
      var done = false;
      final subscription = controller
          .apply(source.stream)
          .listen(received.add, onDone: () => done = true);
      addTearDown(subscription.cancel);
      await Future<void>.delayed(Duration.zero);

      source.add('pending');
      await source.close();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(done, isTrue);
      expect(received, isEmpty,
          reason: 'a timer that survives the close would add to a controller '
              'that is already closed');
    });
  });

  group('message ordering', () {
    MessageOrderer orderer({int maxBuffer = 50, int flushTimeoutMs = 5000}) =>
        MessageOrderer(maxBuffer: maxBuffer, flushTimeoutMs: flushTimeoutMs);

    test('messages already in order pass straight through', () async {
      final received = await collect(orderer().apply(source.stream), () async {
        source.add({'seq': 0, 'v': 'a'});
        source.add({'seq': 1, 'v': 'b'});
        source.add({'seq': 2, 'v': 'c'});
      });

      expect(received.map((m) => m['v']), ['a', 'b', 'c']);
    });

    test('a late arrival releases everything that was waiting behind it',
        () async {
      final received = await collect(orderer().apply(source.stream), () async {
        source.add({'seq': 0, 'v': 'a'});
        source.add({'seq': 2, 'v': 'c'}); // held
        source.add({'seq': 3, 'v': 'd'}); // held
        await Future<void>.delayed(const Duration(milliseconds: 10));
        source.add({'seq': 1, 'v': 'b'}); // fills the gap
      });

      expect(received.map((m) => m['v']), ['a', 'b', 'c', 'd'],
          reason: 'the whole point of the orderer: a document reading a log '
              'must not see line 3 before line 2');
    });

    test('a duplicate or replayed sequence is dropped', () async {
      final received = await collect(orderer().apply(source.stream), () async {
        source.add({'seq': 0, 'v': 'a'});
        source.add({'seq': 1, 'v': 'b'});
        source.add({'seq': 0, 'v': 'a again'});
        source.add({'seq': 2, 'v': 'c'});
      });

      expect(received.map((m) => m['v']), ['a', 'b', 'c'],
          reason: 'a reconnect that replays the tail must not append the same '
              'rows twice');
    });

    test('a message with no sequence number is passed through immediately',
        () async {
      final received = await collect(orderer().apply(source.stream), () async {
        source.add({'seq': 1, 'v': 'held'}); // waiting for 0
        source.add({'v': 'unsequenced'});
      });

      expect(received.map((m) => m['v']), ['unsequenced'],
          reason: 'a heartbeat or a status frame carries no sequence, and '
              'holding it behind a data gap would stall the connection '
              'indicator');
    });

    test('a payload that is not a map is passed through', () async {
      final received = await collect(orderer().apply(source.stream), () async {
        source.add('plain text');
        source.add(42);
      });
      expect(received, ['plain text', 42]);
    });

    test('a null sequence value is treated as unsequenced', () async {
      final received = await collect(orderer().apply(source.stream), () async {
        source.add({'seq': null, 'v': 'no seq'});
      });
      expect(received.single['v'], 'no seq');
    });

    test('a buffer that overflows is flushed in sequence order rather than '
        'growing without bound', () async {
      final received = await collect(
        orderer(maxBuffer: 3).apply(source.stream),
        () async {
          // 0 never arrives, so everything after it is held.
          source.add({'seq': 4, 'v': 'e'});
          source.add({'seq': 2, 'v': 'c'});
          source.add({'seq': 3, 'v': 'd'});
          source.add({'seq': 1, 'v': 'b'}); // exceeds maxBuffer → flush
        },
      );

      expect(received.map((m) => m['v']), ['b', 'c', 'd', 'e'],
          reason: 'giving up on the missing message is better than holding a '
              'growing buffer forever, but the order among what IS held has '
              'to be right');
    });

    test('a gap that never fills is flushed once the timeout expires',
        () async {
      final received = await collect(
        orderer(flushTimeoutMs: 60).apply(source.stream),
        () async {
          source.add({'seq': 3, 'v': 'held'});
          await Future<void>.delayed(const Duration(milliseconds: 30));
          expect(true, isTrue); // still inside the window
        },
        settle: const Duration(milliseconds: 120),
      );

      expect(received.map((m) => m['v']), ['held'],
          reason: 'a message dropped by the network must not silently take '
              'every later message with it');
    });

    test('after a timeout flush the stream continues from the new position',
        () async {
      final received = await collect(
        orderer(flushTimeoutMs: 50).apply(source.stream),
        () async {
          source.add({'seq': 5, 'v': 'first'});
          await Future<void>.delayed(const Duration(milliseconds: 90));
          source.add({'seq': 6, 'v': 'second'});
        },
        settle: const Duration(milliseconds: 60),
      );

      expect(received.map((m) => m['v']), ['first', 'second'],
          reason: 'the expected sequence has to advance past what was '
              'flushed, or every later message looks like a duplicate');
    });

    test('closing the source flushes whatever is still held', () async {
      final received = <dynamic>[];
      var done = false;
      final subscription = orderer()
          .apply(source.stream)
          .listen(received.add, onDone: () => done = true);
      addTearDown(subscription.cancel);
      await Future<void>.delayed(Duration.zero);

      source.add({'seq': 7, 'v': 'stranded'});
      await source.close();
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(received.map((m) => m['v']), ['stranded'],
          reason: 'a channel that closes with messages still buffered must '
              'deliver them, not discard them');
      expect(done, isTrue);
    });
  });
}
