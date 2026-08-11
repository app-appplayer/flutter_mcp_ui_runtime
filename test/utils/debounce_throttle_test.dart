// The rate-shaping utilities, none of which had a test.
//
// `Debouncer` is used by `textfield` and by the custom validator; `Throttler`,
// `RateLimiter` and the two mixins are not referenced anywhere in the runtime
// today. Untested and unused is how a utility rots into something that looks
// available and is not — so this asks each of them the question its name makes:
// does it actually delay, coalesce, limit.
//
// Timers are driven with `FakeAsync` rather than real waits: a test that sleeps
// is slow AND flaky, and both of those end with someone deleting it.

import 'package:fake_async/fake_async.dart';
import 'package:flutter_mcp_ui_runtime/src/utils/debounce.dart';
import 'package:flutter_test/flutter_test.dart';

class _Debounced with DebounceMixin {}

class _Throttled with ThrottleMixin {}

void main() {
  group('Debouncer', () {
    test('runs once, after the delay, with only the last action', () {
      FakeAsync().run((async) {
        final debouncer = Debouncer(milliseconds: 100);
        final calls = <String>[];

        debouncer.run(() => calls.add('first'));
        async.elapse(const Duration(milliseconds: 50));
        expect(calls, isEmpty, reason: 'the delay has not passed');
        expect(debouncer.isActive, isTrue);

        debouncer.run(() => calls.add('second'));
        async.elapse(const Duration(milliseconds: 99));
        expect(calls, isEmpty, reason: 'the second call restarted the clock');

        async.elapse(const Duration(milliseconds: 1));
        expect(calls, ['second'],
            reason: 'coalescing means the last action wins, not the first');
        expect(debouncer.isActive, isFalse);
      });
    });

    test('runAsync awaits the action', () {
      FakeAsync().run((async) {
        final debouncer = Debouncer(milliseconds: 10);
        var finished = false;
        debouncer.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 5));
          finished = true;
        });
        async.elapse(const Duration(milliseconds: 10));
        expect(finished, isFalse, reason: 'the action itself is still running');
        async.elapse(const Duration(milliseconds: 5));
        expect(finished, isTrue);
      });
    });

    test('cancel and dispose drop a pending action', () {
      FakeAsync().run((async) {
        final cancelled = Debouncer(milliseconds: 10)..run(() => fail('ran'));
        cancelled.cancel();
        expect(cancelled.isActive, isFalse);

        final disposed = Debouncer(milliseconds: 10)..run(() => fail('ran'));
        disposed.dispose();
        async.elapse(const Duration(milliseconds: 50));
      });
    });
  });

  group('Throttler', () {
    test('the first call runs immediately, the next one waits out the window',
        () {
      FakeAsync().run((async) {
        final throttler = Throttler(milliseconds: 100);
        final calls = <int>[];

        throttler.run(() => calls.add(1));
        expect(calls, [1], reason: 'a throttle leads, a debounce trails');

        async.elapse(const Duration(milliseconds: 20));
        throttler.run(() => calls.add(2));
        expect(calls, [1], reason: 'inside the window, so it is scheduled');

        // The trailing call fires at the end of the window, and the LAST
        // action queued during it is the one that runs.
        throttler.run(() => calls.add(3));
        async.elapse(const Duration(milliseconds: 100));
        expect(calls, [1, 3]);
      });
    });

    test('runAsync goes through the same gate', () {
      FakeAsync().run((async) {
        final throttler = Throttler(milliseconds: 50);
        final ran = <int>[];
        throttler.runAsync(() async => ran.add(1));
        expect(ran, [1]);
        throttler.runAsync(() async => ran.add(2));
        expect(ran, [1]);
        async.elapse(const Duration(milliseconds: 50));
        expect(ran, [1, 2]);
      });
    });

    test('reset forgets the last run, so the next call leads again', () {
      FakeAsync().run((async) {
        final throttler = Throttler(milliseconds: 100);
        final calls = <int>[];
        throttler.run(() => calls.add(1));
        throttler.run(() => calls.add(2)); // scheduled
        expect(throttler.isActive, isTrue);

        throttler.reset();
        expect(throttler.isActive, isFalse);
        async.elapse(const Duration(milliseconds: 200));
        expect(calls, [1], reason: 'the scheduled action was dropped by reset');

        throttler.run(() => calls.add(3));
        expect(calls, [1, 3], reason: 'reset cleared the window');
        throttler.dispose();
      });
    });
  });

  group('RateLimiter', () {
    // Real waits, deliberately short: this class reads `DateTime.now()`
    // directly, so a fake clock does not age its window and a FakeAsync test
    // would assert against a window that never slides — green for the wrong
    // reason.
    test('allows maxCalls inside the window and refuses the next', () async {
      final limiter =
          RateLimiter(maxCalls: 2, window: const Duration(milliseconds: 60));
      final ran = <int>[];

      expect(limiter.canExecute(), isTrue);
      expect(limiter.execute(() => ran.add(1)), isTrue);
      expect(limiter.execute(() => ran.add(2)), isTrue);
      expect(limiter.remainingCalls, 0);

      expect(limiter.execute(() => ran.add(3)), isFalse,
          reason: 'over the limit, and the action must not run');
      expect(ran, [1, 2]);
      expect(limiter.timeUntilNextCall, isNot(Duration.zero));

      // The window slides: once the oldest call ages out, room reappears.
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(limiter.canExecute(), isTrue);
      expect(limiter.timeUntilNextCall, Duration.zero);
      limiter.dispose();
    });

    test('executeAsync refuses over the limit and awaits under it', () async {
      final limiter =
          RateLimiter(maxCalls: 1, window: const Duration(seconds: 10));
      var done = false;

      expect(await limiter.executeAsync(() async => done = true), isTrue);
      expect(done, isTrue);
      expect(await limiter.executeAsync(() async => fail('must not run')),
          isFalse);
      limiter.dispose();
    });

    test('reset clears the recorded calls', () {
      final limiter =
          RateLimiter(maxCalls: 1, window: const Duration(seconds: 10));
      expect(limiter.execute(() {}), isTrue);
      expect(limiter.execute(() {}), isFalse);
      limiter.reset();
      expect(limiter.execute(() {}), isTrue);
      limiter.dispose();
    });
  });

  group('mixins', () {
    test('DebounceMixin keeps one debouncer per key', () {
      FakeAsync().run((async) {
        final host = _Debounced();
        final calls = <String>[];

        expect(host.debouncer('search'), same(host.debouncer('search')),
            reason: 'a new debouncer per call would never coalesce anything');

        // A trap worth pinning: the instance is created on FIRST access and
        // keeps the delay it was created with. `debouncer('search')` above used
        // the 300 ms default, so the 50 ms asked for here is ignored — a caller
        // who reads the delay from a document would silently get someone
        // else's.
        host.debounce('search', () => calls.add('a'), milliseconds: 50);
        host.debounce('search', () => calls.add('b'), milliseconds: 50);
        host.debounce('other', () => calls.add('other'), milliseconds: 50);
        async.elapse(const Duration(milliseconds: 50));
        expect(calls, ['other'],
            reason: 'the fresh key uses 50 ms; `search` still has its 300 ms');

        async.elapse(const Duration(milliseconds: 250));
        expect(calls, ['other', 'b'],
            reason: 'same key coalesces to the last action');

        host.debounce('search', () => fail('disposed'), milliseconds: 50);
        host.disposeDebouncers();
        async.elapse(const Duration(milliseconds: 100));
      });
    });

    test('ThrottleMixin keeps one throttler per key', () {
      FakeAsync().run((async) {
        final host = _Throttled();
        final calls = <String>[];

        expect(host.throttler('scroll'), same(host.throttler('scroll')));

        // Same trap as above: `throttler('scroll')` created it with the 300 ms
        // default, so the window is 300 ms whatever this call asks for.
        host.throttle('scroll', () => calls.add('a'), milliseconds: 50);
        host.throttle('scroll', () => calls.add('b'), milliseconds: 50);
        expect(calls, ['a'], reason: 'the throttle leads');
        async.elapse(const Duration(milliseconds: 50));
        expect(calls, ['a'], reason: 'still inside the 300 ms window');
        async.elapse(const Duration(milliseconds: 300));
        expect(calls, ['a', 'b']);

        host.disposeThrottlers();
        host.throttle('scroll', () => calls.add('c'), milliseconds: 50);
        expect(calls, ['a', 'b', 'c'],
            reason: 'after disposal a fresh throttler leads again');
      });
    });
  });
}
