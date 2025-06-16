import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/services/state_service.dart';

void main() {
  group('StateService Tests', () {
    late StateService stateService;

    setUp(() {
      stateService = StateService(enableDebugMode: false);
    });

    tearDown(() async {
      await stateService.dispose();
    });

    test('initializes with initial state', () async {
      final config = {
        'initialState': {
          'counter': 0,
          'user': null,
          'items': [],
        },
      };

      await stateService.initialize(config);

      expect(stateService.state['counter'], 0);
      expect(stateService.state['user'], isNull);
      expect(stateService.state['items'], isEmpty);
    });

    test('gets and sets values at path', () async {
      await stateService.initialize({
        'initialState': {
          'user': {
            'name': 'John Doe',
            'age': 30,
          },
        },
      });

      expect(stateService.getValue('user.name'), 'John Doe');
      expect(stateService.getValue('user.age'), 30);

      await stateService.setValue('user.name', 'Jane Doe');
      expect(stateService.getValue('user.name'), 'Jane Doe');
    });

    test('increments and decrements values', () async {
      await stateService.initialize({
        'initialState': {
          'counter': 5,
        },
      });

      await stateService.increment('counter');
      expect(stateService.getValue('counter'), 6);

      await stateService.decrement('counter', 2);
      expect(stateService.getValue('counter'), 4);
    });

    test('toggles boolean values', () async {
      await stateService.initialize({
        'initialState': {
          'isEnabled': false,
        },
      });

      await stateService.toggle('isEnabled');
      expect(stateService.getValue('isEnabled'), true);

      await stateService.toggle('isEnabled');
      expect(stateService.getValue('isEnabled'), false);
    });

    test('appends and removes from arrays', () async {
      await stateService.initialize({
        'initialState': {
          'items': [1, 2, 3],
        },
      });

      await stateService.append('items', 4);
      expect(stateService.getValue('items'), [1, 2, 3, 4]);

      await stateService.remove('items', 2);
      expect(stateService.getValue('items'), [1, 3, 4]);

      await stateService.removeAt('items', 0);
      expect(stateService.getValue('items'), [3, 4]);
    });

    test('merges objects', () async {
      await stateService.initialize({
        'initialState': {
          'settings': {
            'theme': 'light',
            'notifications': true,
          },
        },
      });

      await stateService.merge('settings', {
        'theme': 'dark',
        'language': 'en',
      });

      expect(stateService.getValue('settings'), {
        'theme': 'dark',
        'notifications': true,
        'language': 'en',
      });
    });
  });
}