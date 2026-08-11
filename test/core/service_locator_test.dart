// ServiceLocator — how a host hands a running document its services, and how
// a widget deep in the tree gets one.
//
// The uncovered two thirds were everything below `register`/`get`: the lazy
// and factory registrations (which differ in exactly one way — whether the
// second caller gets the same object), scopes, dependency validation, and the
// `ServiceProvider` / `ServiceLocatorMixin` pair that is how a widget reaches
// any of it. A locator that hands out a second instance of a singleton is a
// second connection, a second cache and a second set of listeners.

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/core/service_locator.dart';
import 'package:flutter_test/flutter_test.dart';

class _Counter {
  _Counter() {
    instances++;
  }

  static int instances = 0;
  int value = 0;
}

class _Other {}

class _TestService extends BaseService {
  bool initialised = false;
  bool disposed = false;
  bool failOnInit = false;

  @override
  Future<void> onInitialize() async {
    if (failOnInit) throw StateError('cannot start');
    initialised = true;
  }

  @override
  Future<void> onDispose() async {
    disposed = true;
  }
}

class _ConsumerWidget extends StatefulWidget {
  const _ConsumerWidget();

  @override
  State<_ConsumerWidget> createState() => _ConsumerWidgetState();
}

class _ConsumerWidgetState extends State<_ConsumerWidget>
    with ServiceLocatorMixin<_ConsumerWidget> {
  @override
  Widget build(BuildContext context) {
    final counter = getService<_Counter>();
    final missing = getService<_Other?>(optional: true);
    return Text('value ${counter.value}, other ${missing == null}');
  }
}

void main() {
  late ServiceLocator locator;

  setUp(() {
    locator = ServiceLocator.instance..clear();
    _Counter.instances = 0;
  });

  tearDown(() => ServiceLocator.instance.clear());

  group('singletons', () {
    test('a registered instance is the one every caller gets', () {
      final counter = _Counter();
      locator.register<_Counter>(counter);

      expect(locator.get<_Counter>(), same(counter));
      expect(locator.get<_Counter>(), same(counter),
          reason: 'a second instance is a second connection and a second '
              'cache, and the two disagree from the first write');
    });

    test('isRegistered reports what is there and what is not', () {
      locator.register<_Counter>(_Counter());

      expect(locator.isRegistered<_Counter>(), isTrue);
      expect(locator.isRegistered<_Other>(), isFalse);
    });

    test('an unregistered service is refused by name', () {
      expect(() => locator.get<_Other>(), throwsA(isA<ServiceNotFoundException>()));
      expect(ServiceNotFoundException('nope').toString(),
          contains('ServiceNotFoundException'));
    });

    test('an optional service answers null when the type can hold null', () {
      expect(locator.get<_Other?>(optional: true), isNull,
          reason: 'this is what lets a widget degrade rather than take the '
              'page down when a host did not wire something');
    });

    test('an optional lookup on a non-nullable type says what to write instead',
        () {
      // `null as T` throws for every non-nullable T, so the old degrade path
      // raised a cast error no caller could handle. It cannot answer null
      // here — but it can say why in a sentence that names the fix.
      expect(
        () => locator.get<_Other>(optional: true),
        throwsA(isA<ServiceNotFoundException>().having(
            (e) => e.message, 'message', contains('nullable'))),
      );
    });

    test('unregister removes it', () {
      locator.register<_Counter>(_Counter());
      locator.unregister<_Counter>();

      expect(locator.isRegistered<_Counter>(), isFalse);
    });

    test('clear removes everything', () {
      locator
        ..register<_Counter>(_Counter())
        ..register<_Other>(_Other())
        ..clear();

      expect(locator.isRegistered<_Counter>(), isFalse);
      expect(locator.isRegistered<_Other>(), isFalse);
    });
  });

  group('lazy singletons and factories', () {
    test('a lazy service is not built until it is asked for', () {
      locator.registerLazy<_Counter>(_Counter.new);

      expect(_Counter.instances, 0,
          reason: 'a lazy registration that builds eagerly opens a connection '
              'the document may never use');

      locator.get<_Counter>();
      expect(_Counter.instances, 1);
    });

    test('a lazy service is built once and cached', () {
      locator.registerLazy<_Counter>(_Counter.new);

      final first = locator.get<_Counter>()..value = 7;
      final second = locator.get<_Counter>();

      expect(second.value, 7);
      expect(_Counter.instances, 1);
      expect(identical(first, second), isTrue);
    });

    test('a factory builds a new instance every time', () {
      locator.registerFactory<_Counter>(_Counter.new);

      final first = locator.get<_Counter>()..value = 7;
      final second = locator.get<_Counter>();

      expect(second.value, 0,
          reason: 'the whole difference between registerFactory and '
              'registerLazy is this line; if it caches, one form is a silent '
              'alias for the other');
      expect(identical(first, second), isFalse);
      expect(_Counter.instances, 2);
    });

    test('isRegistered is true for a lazy service before it is built', () {
      locator.registerLazy<_Counter>(_Counter.new);
      expect(locator.isRegistered<_Counter>(), isTrue);
      expect(_Counter.instances, 0);
    });
  });

  group('dependencies', () {
    test('declared dependencies are readable', () {
      locator.register<_Counter>(_Counter(), dependencies: [_Other]);

      expect(locator.getDependencies<_Counter>(), [_Other]);
      expect(locator.getDependencies<_Other>(), isNull);
    });

    test('a lazy or factory registration can declare them too', () {
      locator
        ..registerLazy<_Counter>(_Counter.new, dependencies: [_Other])
        ..registerFactory<_Other>(_Other.new, dependencies: [_Counter]);

      expect(locator.getDependencies<_Counter>(), [_Other]);
      expect(locator.getDependencies<_Other>(), [_Counter]);
    });

    test('a straight dependency chain validates', () {
      locator
        ..register<_Counter>(_Counter(), dependencies: [_Other])
        ..register<_Other>(_Other());

      expect(locator.validateDependencies, returnsNormally);
    });

    test('a cycle is reported with the path in it', () {
      locator
        ..register<_Counter>(_Counter(), dependencies: [_Other])
        ..register<_Other>(_Other(), dependencies: [_Counter]);

      expect(
        locator.validateDependencies,
        throwsA(isA<CircularDependencyException>()),
        reason: 'the alternative is a stack overflow at the first resolution',
      );
      expect(CircularDependencyException('a -> b -> a').toString(),
          contains('a -> b -> a'));
    });
  });

  group('scopes', () {
    test('a scope reads through to its parent', () {
      final shared = _Counter();
      locator.register<_Counter>(shared);

      final scope = locator.createScope();
      expect(scope.get<_Counter>(), same(shared));
      expect(scope.isRegistered<_Counter>(), isTrue);
    });

    test('a scope\'s own registration shadows the parent\'s', () {
      locator.register<_Counter>(_Counter()..value = 1);

      final scope = locator.createScope()
        ..register<_Counter>(_Counter()..value = 2);

      expect(scope.get<_Counter>().value, 2);
      expect(locator.get<_Counter>().value, 1,
          reason: 'a scoped override that leaks upward would change every '
              'other document sharing the host');
    });

    test('a scope does not report the parent\'s missing services as present',
        () {
      final scope = locator.createScope();

      expect(scope.isRegistered<_Other>(), isFalse);
      expect(() => scope.get<_Other>(), throwsA(isA<ServiceNotFoundException>()));
      expect(scope.get<_Other?>(optional: true), isNull);
    });
  });

  group('BaseService lifecycle', () {
    test('a service moves uninitialized → ready → disposed', () async {
      final service = _TestService();
      expect(service.status, ServiceStatus.uninitialized);

      await service.initialize();
      expect(service.status, ServiceStatus.ready);
      expect(service.initialised, isTrue);

      await service.dispose();
      expect(service.status, ServiceStatus.disposed);
      expect(service.disposed, isTrue);
    });

    test('initialising twice is refused', () async {
      final service = _TestService();
      await service.initialize();

      await expectLater(service.initialize(), throwsA(isA<StateError>()),
          reason: 'a second initialize would open a second connection under '
              'the same service');
    });

    test('a failed start leaves the service in error, and says why', () async {
      final service = _TestService()..failOnInit = true;

      await expectLater(service.initialize(), throwsA(isA<StateError>()));
      expect(service.status, ServiceStatus.error,
          reason: 'a service left "initializing" is one nothing will ever '
              'retry or tear down');
    });

    test('disposing twice is a no-op', () async {
      final service = _TestService();
      await service.initialize();
      await service.dispose();
      service.disposed = false;

      await service.dispose();
      expect(service.disposed, isFalse);
    });
  });

  group('reaching the locator from the widget tree', () {
    testWidgets('ServiceProvider hands the locator down', (tester) async {
      locator.register<_Counter>(_Counter()..value = 42);

      await tester.pumpWidget(MaterialApp(
        home: ServiceProvider(
          serviceLocator: locator,
          child: const _ConsumerWidget(),
        ),
      ));

      expect(find.text('value 42, other true'), findsOneWidget);
    });

    test('a service registered by run-time type, with its dependencies, is '
        'reachable that way', () {
      final locator = ServiceLocator();
      final counter = _Counter()..value = 3;

      // The `Type`-keyed door: a host that builds its service map from
      // configuration has no static type to hand `register<T>`.
      locator.registerByType(_Counter, counter, dependencies: [String]);

      expect(locator.get<_Counter>().value, 3,
          reason: 'registered by type and read by type must be the same '
              'entry, or a host wiring services from config gets "not '
              'registered" for something it just registered');
      expect(locator.isRegistered<_Counter>(), isTrue);
    });

    testWidgets('maybeOf answers null outside a provider', (tester) async {
      ServiceLocator? seen;
      var checked = false;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          seen = ServiceProvider.maybeOf(context);
          checked = true;
          return const SizedBox();
        }),
      ));

      expect(checked, isTrue);
      expect(seen, isNull);
    });

    testWidgets('of() outside a provider is an error a developer can read',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          ServiceProvider.of(context);
          return const SizedBox();
        }),
      ));

      expect(tester.takeException(), isA<FlutterError>());
    });

    testWidgets('replacing the locator notifies its dependents',
        (tester) async {
      final first = ServiceLocator.instance;
      final second = first.createScope()
        ..register<_Counter>(_Counter()..value = 9);
      first.register<_Counter>(_Counter()..value = 1);

      Widget app(ServiceLocator which) => MaterialApp(
            home: ServiceProvider(
              serviceLocator: which,
              child: const _ConsumerWidget(),
            ),
          );

      await tester.pumpWidget(app(first));
      expect(find.text('value 1, other true'), findsOneWidget);

      await tester.pumpWidget(app(second));
      expect(find.text('value 9, other true'), findsOneWidget,
          reason: 'a provider that swaps its locator without notifying leaves '
              'every consumer reading the old one');
    });
  });
}
