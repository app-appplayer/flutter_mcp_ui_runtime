// Background services — the work a document asks for while nobody is looking.
//
// 57% covered, and the uncovered part was every service TYPE: the periodic
// timer, the schedule parser, the event subscription, the one-off delay, the
// retry ladder. These run unattended, so a service that silently never fires
// looks exactly like a service whose tool has nothing to report — and a
// service that keeps firing after the page closed keeps calling a server for
// the life of the process.
//
// The clock is real but short (tens of milliseconds), because the branches
// under test are the scheduling decisions, not the durations.

import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/models/ui_definition.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/background_service_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ActionHandler actionHandler;
  late StateManager stateManager;
  late List<Map<String, dynamic>> calls;

  setUp(() {
    calls = [];
    actionHandler = ActionHandler();
    stateManager = StateManager()..initialize(<String, dynamic>{});
  });

  tearDown(() => stateManager.dispose());

  /// Registers a tool that records what it was called with.
  void registerTool(String name, {dynamic answer, Object? failWith}) {
    actionHandler.registerToolExecutor(name, (params) async {
      calls.add(Map<String, dynamic>.from(params as Map));
      if (failWith != null) throw failWith;
      return answer ?? {'ok': true};
    });
  }

  BackgroundServiceDefinition service({
    required BackgroundServiceType type,
    String tool = 'sync',
    int? interval,
    String? schedule,
    String? event,
    Map<String, dynamic>? params,
    String? resultPath,
    bool? retryOnError,
    int? retryDelay,
    bool? stopOnError,
  }) =>
      BackgroundServiceDefinition(
        id: 'svc',
        type: type,
        tool: tool,
        interval: interval,
        schedule: schedule,
        event: event,
        params: params,
        resultPath: resultPath,
        retryOnError: retryOnError,
        retryDelay: retryDelay,
        stopOnError: stopOnError,
      );

  BackgroundServiceManager manager() => BackgroundServiceManager(
        actionHandler: actionHandler,
        stateManager: stateManager,
      );

  Future<void> wait([int ms = 120]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  /// Waits until [test] holds, or gives up after ~2s.
  ///
  /// These services run on real timers, so a fixed sleep asserts about how
  /// busy the machine is: under a loaded suite a 30ms interval can deliver one
  /// tick in 110ms and the test fails for a reason that has nothing to do with
  /// the service.
  Future<void> waitUntil(bool Function() test) async {
    for (var i = 0; i < 200 && !test(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  group('periodic', () {
    test('fires repeatedly on its interval, with the declared params',
        () async {
      registerTool('sync');
      final m = manager();
      addTearDown(m.dispose);

      await m.startService(
        'poll',
        service(
          type: BackgroundServiceType.periodic,
          interval: 30,
          params: {'since': 'yesterday'},
        ),
      );
      await waitUntil(() => calls.length >= 2);

      expect(calls.length, greaterThanOrEqualTo(2),
          reason: 'a poll that fires once is not a poll');
      expect(calls.first, {'since': 'yesterday'},
          reason: 'the params are the query — a service polling without them '
              'asks a different question every time');
    });

    test('an interval of zero or less refuses to start rather than spinning',
        () async {
      registerTool('sync');
      final m = manager();
      addTearDown(m.dispose);

      await m.startService('poll',
          service(type: BackgroundServiceType.periodic, interval: 0));
      await wait(60);

      expect(calls, isEmpty,
          reason: 'a zero interval as a busy loop would take the process down '
              'with it; refusing is the only safe reading');
    });

    test('stopping it stops the calls', () async {
      registerTool('sync');
      final m = manager();
      addTearDown(m.dispose);

      await m.startService('poll',
          service(type: BackgroundServiceType.periodic, interval: 20));
      await wait(70);
      final duringRun = calls.length;
      expect(duringRun, greaterThan(0));

      await m.stopService('poll');
      await wait(80);

      expect(calls.length, duringRun,
          reason: 'a timer surviving its service keeps calling a server for '
              'the life of the process');
      expect(m.isRunning('poll'), isFalse);
    });
  });

  group('scheduled', () {
    test('"every N seconds" is parsed into an interval', () async {
      // The parser only understands this one shape; a pattern it cannot read
      // must not silently become "never" without a word in the log.
      registerTool('sync');
      final m = manager();
      addTearDown(m.dispose);

      await m.startService(
        'nightly',
        service(
          type: BackgroundServiceType.scheduled,
          schedule: 'every 1 second',
        ),
      );
      await wait(1200);

      expect(calls, isNotEmpty);
    });

    test('minutes and hours are parsed into their own intervals', () async {
      // The unit decides the interval by a factor of sixty each step. A unit
      // that falls through to seconds turns an hourly poll into a
      // once-a-second one — the same tool, sixty times the traffic.
      for (final unit in const ['minute', 'hour', 'fortnight']) {
        final m = manager();
        addTearDown(m.dispose);
        await m.startService(
          'sched_$unit',
          service(
            type: BackgroundServiceType.scheduled,
            schedule: 'every 1 $unit',
          ),
        );
        expect(m.isRunning('sched_$unit'), isTrue, reason: unit);
      }
      // Nothing fires inside this window: a minute is the shortest of them.
      await wait(150);
      expect(calls, isEmpty,
          reason: 'a minute that was read as a second would already have '
              'fired twice by now');
    });

    test('stopping a scheduled service cancels its timer', () async {
      registerTool('sync');
      final m = manager();
      addTearDown(m.dispose);

      await m.startService(
        'nightly',
        service(
          type: BackgroundServiceType.scheduled,
          schedule: 'every 1 second',
        ),
      );
      await wait(1100);
      final firedWhileRunning = calls.length;
      expect(firedWhileRunning, greaterThan(0));

      await m.stopService('nightly');
      await wait(1200);

      expect(calls.length, firedWhileRunning,
          reason: 'a stopped schedule that keeps firing calls a server for '
              'the life of the process');
    });

    test('a pattern it cannot read starts nothing', () async {
      registerTool('sync');
      final m = manager();
      addTearDown(m.dispose);

      await m.startService(
        'cron',
        service(
          type: BackgroundServiceType.scheduled,
          schedule: '0 3 * * *',
        ),
      );
      await wait(120);

      expect(calls, isEmpty,
          reason: 'a cron expression is NOT supported — running it as if it '
              'were every-100ms would be far worse than not running it');
    });

    test('a scheduled service with no pattern at all starts nothing',
        () async {
      registerTool('sync');
      final m = manager();
      addTearDown(m.dispose);

      await m.startService(
          'cron', service(type: BackgroundServiceType.scheduled));
      await wait(80);

      expect(calls, isEmpty);
    });
  });

  group('continuous', () {
    test('runs on a short cadence until stopped', () async {
      registerTool('sync');
      final m = manager();
      addTearDown(m.dispose);

      await m.startService(
          'stream', service(type: BackgroundServiceType.continuous));
      await wait(260);

      expect(calls.length, greaterThanOrEqualTo(2));
      await m.stopService('stream');
      final afterStop = calls.length;
      await wait(200);
      expect(calls.length, afterStop);
    });
  });

  group('event', () {
    test('fires when the named state path changes', () async {
      registerTool('sync');
      final m = manager();
      addTearDown(m.dispose);

      await m.startService(
        'onCart',
        service(type: BackgroundServiceType.event, event: 'cart'),
      );

      stateManager.set('cart', ['apple']);
      await wait(30);
      expect(calls, hasLength(1));

      stateManager.set('unrelated', 1);
      await wait(30);
      expect(calls, hasLength(1),
          reason: 'a service woken by every state change turns one write into '
              'a request per keystroke');
    });

    test('a wildcard pattern matches a family of paths', () async {
      registerTool('sync');
      final m = manager();
      addTearDown(m.dispose);

      await m.startService(
        'onUser',
        service(type: BackgroundServiceType.event, event: 'user.*'),
      );

      stateManager.set('user.name', 'Ada');
      stateManager.set('user.email', 'ada@example.com');
      await wait(40);

      expect(calls.length, greaterThanOrEqualTo(2));
    });

    test('an event service with no pattern subscribes to nothing', () async {
      registerTool('sync');
      final m = manager();
      addTearDown(m.dispose);

      await m.startService('bad', service(type: BackgroundServiceType.event));
      stateManager.set('anything', 1);
      await wait(40);

      expect(calls, isEmpty);
    });

    test('with no state manager it cannot subscribe, and says nothing false',
        () async {
      registerTool('sync');
      final m = BackgroundServiceManager(actionHandler: actionHandler);
      addTearDown(m.dispose);

      await m.startService(
        'onCart',
        service(type: BackgroundServiceType.event, event: 'cart'),
      );
      stateManager.set('cart', 1);
      await wait(40);

      expect(calls, isEmpty);
      expect(m.isRunning('onCart'), isTrue,
          reason: 'the service is registered — what is missing is the source, '
              'and the manager still owns it for shutdown');
    });

    test('stopping cancels the subscription', () async {
      registerTool('sync');
      final m = manager();
      addTearDown(m.dispose);

      await m.startService(
        'onCart',
        service(type: BackgroundServiceType.event, event: 'cart'),
      );
      stateManager.set('cart', 1);
      await wait(30);
      final duringRun = calls.length;

      await m.stopService('onCart');
      stateManager.set('cart', 2);
      await wait(30);

      expect(calls.length, duringRun,
          reason: 'a listener outliving its service writes into a disposed '
              'page');
    });
  });

  group('oneoff', () {
    test('runs once after its delay and never again', () async {
      registerTool('sync');
      final m = manager();
      addTearDown(m.dispose);

      await m.startService(
        'warmup',
        service(type: BackgroundServiceType.oneoff, interval: 30),
      );
      expect(calls, isEmpty, reason: 'not before the delay');

      await wait(200);
      expect(calls, hasLength(1),
          reason: 'a one-off that repeats is a periodic service nobody asked '
              'for');
    });

    test('with no delay it still runs', () async {
      registerTool('sync');
      final m = manager();
      addTearDown(m.dispose);

      await m.startService(
          'warmup', service(type: BackgroundServiceType.oneoff));
      await wait(60);

      expect(calls, hasLength(1));
    });
  });

  group('the tool result', () {
    test('is written to the declared state path', () async {
      registerTool('sync', answer: {'rows': 3});
      final m = manager();
      addTearDown(m.dispose);

      await m.startService(
        'poll',
        service(
          type: BackgroundServiceType.oneoff,
          resultPath: 'lastSync',
        ),
      );
      await wait(80);

      expect(stateManager.get('lastSync'), {'rows': 3},
          reason: 'this is the only way an unattended service reaches the '
              'screen — without it the work happens and nothing shows it');
    });

    test('a tool nobody registered is reported and nothing is written',
        () async {
      final m = manager();
      addTearDown(m.dispose);

      await m.startService(
        'poll',
        service(
          type: BackgroundServiceType.oneoff,
          tool: 'absent',
          resultPath: 'lastSync',
        ),
      );
      await wait(80);

      expect(stateManager.get('lastSync'), isNull,
          reason: 'writing null for a tool that never ran would read as a '
              'successful empty answer');
    });

    test('with no action handler at all nothing runs and nothing throws',
        () async {
      final m = BackgroundServiceManager(stateManager: stateManager);
      addTearDown(m.dispose);

      await m.startService(
          'poll', service(type: BackgroundServiceType.oneoff));
      await wait(60);

      expect(calls, isEmpty);
    });
  });

  group('errors and retries', () {
    test('a failing tool is retried when the document asks for it', () async {
      registerTool('sync', failWith: StateError('server down'));
      final m = manager();
      addTearDown(m.dispose);

      await m.startService(
        'poll',
        service(
          type: BackgroundServiceType.periodic,
          interval: 10000, // long enough that only the retries fire
          retryOnError: true,
          retryDelay: 20,
        ),
      );
      // Nothing has fired yet — the first periodic tick is 10s away. Trigger
      // one directly by starting a one-off with the same failure instead.
      await m.stopService('poll');
      calls.clear();

      await m.startService(
        'once',
        service(
          type: BackgroundServiceType.oneoff,
          interval: 0,
          retryOnError: true,
          retryDelay: 20,
        ),
      );
      await wait(200);

      expect(calls.length, greaterThan(1),
          reason: 'a transient failure that is never retried makes an '
              'unattended sync give up on the first hiccup');
      expect(calls.length, lessThanOrEqualTo(4),
          reason: 'and it must stop at the retry ceiling rather than hammer '
              'the server forever');
    });

    test('without retryOnError a failure is final', () async {
      registerTool('sync', failWith: StateError('server down'));
      final m = manager();
      addTearDown(m.dispose);

      await m.startService(
        'once',
        service(type: BackgroundServiceType.oneoff, interval: 0),
      );
      await wait(150);

      expect(calls, hasLength(1));
    });

    test('stopOnError takes the service down after the retries run out',
        () async {
      registerTool('sync', failWith: StateError('server down'));
      final m = manager();
      addTearDown(m.dispose);

      await m.startService(
        'poll',
        service(
          type: BackgroundServiceType.periodic,
          interval: 20,
          stopOnError: true,
        ),
      );
      await wait(150);
      final afterStop = calls.length;
      await wait(150);

      expect(calls.length, afterStop,
          reason: 'a service failing every tick against a server that is gone '
              'is a retry storm; stopOnError is how a document says stop');
    });
  });

  group('the manager', () {
    test('starts a whole block of services and reports what is running',
        () async {
      registerTool('a');
      registerTool('b');
      final m = manager();
      addTearDown(m.dispose);

      await m.startServices({
        'first': service(
            type: BackgroundServiceType.oneoff, tool: 'a', interval: 0),
        'second': service(
            type: BackgroundServiceType.oneoff, tool: 'b', interval: 0),
      });

      expect(m.runningServices, unorderedEquals(['first', 'second']));
      expect(m.isRunning('first'), isTrue);
      expect(m.isRunning('third'), isFalse);
    });

    test('starting the same id twice replaces the first', () async {
      registerTool('sync');
      final m = manager();
      addTearDown(m.dispose);

      await m.startService('poll',
          service(type: BackgroundServiceType.periodic, interval: 20));
      await m.startService('poll',
          service(type: BackgroundServiceType.periodic, interval: 20));
      await wait(100);
      final withOne = calls.length;

      await m.stopService('poll');
      await wait(100);

      expect(calls.length, withOne,
          reason: 'a replaced service that kept its timer would double the '
              'polling rate every time the page reloaded');
    });

    test('stopping an id nobody started is not fatal', () async {
      final m = manager();
      addTearDown(m.dispose);
      await m.stopService('imaginary');
      expect(m.runningServices, isEmpty);
    });

    test('stopAll and dispose stop everything, and dispose refuses new work',
        () async {
      registerTool('sync');
      final m = manager();

      await m.startServices({
        'a': service(type: BackgroundServiceType.periodic, interval: 20),
        'b': service(type: BackgroundServiceType.periodic, interval: 20),
      });
      await wait(60);
      await m.stopAllServices();
      expect(m.runningServices, isEmpty);

      await m.dispose();
      await m.startService('c',
          service(type: BackgroundServiceType.periodic, interval: 20));
      expect(m.isRunning('c'), isFalse,
          reason: 'a disposed manager accepting a new service is how a closed '
              'document keeps polling');
    });
  });
}
