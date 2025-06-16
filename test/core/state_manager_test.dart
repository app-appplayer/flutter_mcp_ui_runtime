import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';

void main() {
  group('StateManager Tests', () {
    late StateManager stateManager;

    setUp(() {
      stateManager = StateManager();
    });

    tearDown(() {
      stateManager.dispose();
    });

    test('initializes state', () {
      stateManager.initialize({
        'user': {'name': 'John', 'age': 30},
        'app': {'version': '1.0.0'}
      });

      expect(stateManager.get<String>('user.name'), equals('John'));
      expect(stateManager.get<int>('user.age'), equals(30));
      expect(stateManager.get<String>('app.version'), equals('1.0.0'));
    });

    test('gets and sets simple values', () {
      stateManager.set('test', 'value');
      expect(stateManager.get<String>('test'), equals('value'));
    });

    test('gets and sets nested values', () {
      stateManager.set('user.name', 'Jane');
      stateManager.set('user.profile.email', 'jane@example.com');
      
      expect(stateManager.get<String>('user.name'), equals('Jane'));
      expect(stateManager.get<String>('user.profile.email'), equals('jane@example.com'));
    });

    test('updates multiple values at once', () {
      stateManager.updateAll({
        'user.name': 'Bob',
        'user.age': 25,
        'app.status': 'active'
      });

      expect(stateManager.get<String>('user.name'), equals('Bob'));
      expect(stateManager.get<int>('user.age'), equals(25));
      expect(stateManager.get<String>('app.status'), equals('active'));
    });

    test('increments numeric values', () {
      stateManager.set('counter', 5);
      stateManager.increment('counter');
      expect(stateManager.get<int>('counter'), equals(6));
      
      stateManager.increment('counter', 3);
      expect(stateManager.get<int>('counter'), equals(9));
    });

    test('decrements numeric values', () {
      stateManager.set('counter', 10);
      stateManager.decrement('counter');
      expect(stateManager.get<int>('counter'), equals(9));
      
      stateManager.decrement('counter', 4);
      expect(stateManager.get<int>('counter'), equals(5));
    });

    test('toggles boolean values', () {
      stateManager.set('flag', false);
      stateManager.toggle('flag');
      expect(stateManager.get<bool>('flag'), isTrue);
      
      stateManager.toggle('flag');
      expect(stateManager.get<bool>('flag'), isFalse);
    });

    test('appends to lists', () {
      stateManager.set('items', [1, 2, 3]);
      stateManager.append('items', 4);
      expect(stateManager.get<List>('items'), equals([1, 2, 3, 4]));
    });

    test('removes from lists', () {
      stateManager.set('items', [1, 2, 3, 2]);
      stateManager.remove('items', 2);
      expect(stateManager.get<List>('items'), equals([1, 3, 2]));
    });

    test('removes at index from lists', () {
      stateManager.set('items', ['a', 'b', 'c']);
      stateManager.removeAt('items', 1);
      expect(stateManager.get<List>('items'), equals(['a', 'c']));
    });

    test('clears lists and maps', () {
      stateManager.set('items', [1, 2, 3]);
      stateManager.set('data', {'key': 'value'});
      
      stateManager.clear('items');
      stateManager.clear('data');
      
      expect(stateManager.get<List>('items'), equals([]));
      expect(stateManager.get<Map>('data'), equals({}));
    });

    test('gets entire state', () {
      stateManager.initialize({'test': 'value'});
      final state = stateManager.getState();
      expect(state['test'], equals('value'));
    });

    test('replaces entire state', () {
      stateManager.initialize({'old': 'value'});
      stateManager.setState({'new': 'data'});
      
      expect(stateManager.get('old'), isNull);
      expect(stateManager.get<String>('new'), equals('data'));
    });

    test('clears all state', () {
      stateManager.initialize({'test': 'value'});
      stateManager.clearState();
      expect(stateManager.get('test'), isNull);
    });

    test('handles non-existent paths gracefully', () {
      expect(stateManager.get('non.existent.path'), isNull);
    });

    test('watches state changes', () async {
      final stream = stateManager.watch<String>('user.name');
      final values = <String>[];
      
      stream.listen((value) {
        values.add(value);
      });
      
      // Allow stream to emit current value (null in this case)
      await Future.delayed(const Duration(milliseconds: 10));
      
      stateManager.set('user.name', 'John');
      await Future.delayed(const Duration(milliseconds: 10));
      
      stateManager.set('user.name', 'Jane');
      await Future.delayed(const Duration(milliseconds: 10));
      
      expect(values, contains('John'));
      expect(values, contains('Jane'));
    });

    test('handles different data types', () {
      stateManager.set('string', 'text');
      stateManager.set('number', 42);
      stateManager.set('double', 3.14);
      stateManager.set('boolean', true);
      stateManager.set('list', [1, 2, 3]);
      stateManager.set('map', {'key': 'value'});
      
      expect(stateManager.get<String>('string'), equals('text'));
      expect(stateManager.get<int>('number'), equals(42));
      expect(stateManager.get<double>('double'), equals(3.14));
      expect(stateManager.get<bool>('boolean'), isTrue);
      expect(stateManager.get<List>('list'), equals([1, 2, 3]));
      expect(stateManager.get<Map>('map'), equals({'key': 'value'}));
    });

    test('maintains data integrity during concurrent operations', () {
      stateManager.set('counter', 0);
      
      // Simulate concurrent increments
      for (int i = 0; i < 10; i++) {
        stateManager.increment('counter');
      }
      
      expect(stateManager.get<int>('counter'), equals(10));
    });
  });
}