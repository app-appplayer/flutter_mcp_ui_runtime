import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_watcher.dart';

void main() {
  group('StateWatcher Tests', () {
    group('Basic Functionality', () {
      test('should create state watcher', () {
        var callbackCalled = false;
        
        final watcher = StateWatcher(
          path: 'user.name',
          onChange: (newValue, oldValue) async {
            callbackCalled = true;
          },
        );

        expect(watcher.path, equals('user.name'));
        expect(watcher.debounceMs, equals(0));
        expect(watcher.isInitialized, isFalse);
        expect(watcher.lastValue, isNull);
      });

      test('should initialize on first trigger', () async {
        var callbackCalled = false;
        
        final watcher = StateWatcher(
          path: 'counter',
          onChange: (newValue, oldValue) async {
            callbackCalled = true;
          },
        );

        await watcher.trigger(5, null);
        
        expect(watcher.isInitialized, isTrue);
        expect(watcher.lastValue, equals(5));
        expect(callbackCalled, isFalse); // Callback not called on initialization
      });

      test('should trigger onChange when value changes', () async {
        dynamic newValueReceived;
        dynamic oldValueReceived;
        
        final watcher = StateWatcher(
          path: 'counter',
          onChange: (newValue, oldValue) async {
            newValueReceived = newValue;
            oldValueReceived = oldValue;
          },
        );

        // Initialize
        await watcher.trigger(5, null);
        
        // Change value
        await watcher.trigger(10, 5);
        
        expect(newValueReceived, equals(10));
        expect(oldValueReceived, equals(5));
        expect(watcher.lastValue, equals(10));
      });

      test('should not trigger when value is unchanged', () async {
        var callbackCount = 0;
        
        final watcher = StateWatcher(
          path: 'value',
          onChange: (newValue, oldValue) async {
            callbackCount++;
          },
        );

        // Initialize
        await watcher.trigger('test', null);
        
        // Try to trigger with same value
        await watcher.trigger('test', 'test');
        await watcher.trigger('test', 'test');
        
        expect(callbackCount, equals(0));
      });
    });

    group('Conditional Triggers', () {
      test('should respect condition function', () async {
        var callbackCalled = false;
        
        final watcher = StateWatcher(
          path: 'temperature',
          onChange: (newValue, oldValue) async {
            callbackCalled = true;
          },
          condition: (newValue, oldValue) {
            // Only trigger if temperature rises above 100
            return newValue > 100 && (oldValue == null || oldValue <= 100);
          },
        );

        // Initialize
        await watcher.trigger(50, null);
        
        // Change but condition not met
        await watcher.trigger(80, 50);
        expect(callbackCalled, isFalse);
        
        // Change and condition is met
        await watcher.trigger(110, 80);
        expect(callbackCalled, isTrue);
      });

      test('should handle complex conditions', () async {
        final triggeredValues = <dynamic>[];
        
        final watcher = StateWatcher(
          path: 'user.status',
          onChange: (newValue, oldValue) async {
            triggeredValues.add(newValue);
          },
          condition: (newValue, oldValue) {
            // Only trigger for specific status transitions
            return oldValue == 'pending' && newValue == 'active';
          },
        );

        // Initialize
        await watcher.trigger('pending', null);
        
        // Valid transition
        await watcher.trigger('active', 'pending');
        expect(triggeredValues, equals(['active']));
        
        // Invalid transition
        await watcher.trigger('inactive', 'active');
        expect(triggeredValues.length, equals(1));
      });
    });

    group('Debouncing', () {
      test('should debounce rapid changes', () async {
        final triggeredValues = <dynamic>[];
        
        final watcher = StateWatcher(
          path: 'search',
          onChange: (newValue, oldValue) async {
            triggeredValues.add(newValue);
          },
          debounceMs: 100,
        );

        // Initialize
        await watcher.trigger('', null);
        
        // Rapid changes
        await watcher.trigger('h', '');
        await watcher.trigger('he', 'h');
        await watcher.trigger('hel', 'he');
        await watcher.trigger('hell', 'hel');
        await watcher.trigger('hello', 'hell');
        
        // Immediately after rapid changes
        expect(triggeredValues, isEmpty);
        
        // Wait for debounce
        await Future.delayed(const Duration(milliseconds: 150));
        
        // Should only have the last value
        expect(triggeredValues.length, lessThanOrEqualTo(1));
        if (triggeredValues.isNotEmpty) {
          expect(triggeredValues.last, equals('hello'));
        }
      });

      test('should handle spaced out changes with debounce', () async {
        final triggeredValues = <dynamic>[];
        
        final watcher = StateWatcher(
          path: 'value',
          onChange: (newValue, oldValue) async {
            triggeredValues.add(newValue);
          },
          debounceMs: 50,
        );

        // Initialize
        await watcher.trigger(0, null);
        
        // First change
        await watcher.trigger(1, 0);
        await Future.delayed(const Duration(milliseconds: 60));
        expect(triggeredValues, equals([1]));
        
        // Second change after debounce period
        await watcher.trigger(2, 1);
        await Future.delayed(const Duration(milliseconds: 60));
        expect(triggeredValues, equals([1, 2]));
      });
    });

    group('Error Handling', () {
      test('should handle errors in onChange callback', () async {
        final watcher = StateWatcher(
          path: 'error.path',
          onChange: (newValue, oldValue) async {
            throw Exception('Test error');
          },
        );

        // Initialize
        await watcher.trigger('initial', null);
        
        // Should throw when triggering onChange
        expect(
          () => watcher.trigger('changed', 'initial'),
          throwsException,
        );
      });

      test('should maintain state even after error', () async {
        var successfulCalls = 0;
        
        final watcher = StateWatcher(
          path: 'sometimes.fails',
          onChange: (newValue, oldValue) async {
            if (newValue == 'error') {
              throw Exception('Triggered error');
            }
            successfulCalls++;
          },
        );

        // Initialize
        await watcher.trigger('ok', null);
        
        // Successful change
        await watcher.trigger('good', 'ok');
        expect(successfulCalls, equals(1));
        expect(watcher.lastValue, equals('good'));
        
        // Failed change
        try {
          await watcher.trigger('error', 'good');
        } catch (_) {
          // Expected error
        }
        
        // State should be updated to the error value even though callback failed
        expect(watcher.lastValue, equals('error'));
        
        // Can continue after error
        await watcher.trigger('recovered', 'error');
        expect(successfulCalls, equals(2));
      });
    });

    group('Value Comparison', () {
      test('should handle different types of values', () async {
        final changes = <String>[];
        
        final watcher = StateWatcher(
          path: 'mixed.type',
          onChange: (newValue, oldValue) async {
            changes.add('$oldValue -> $newValue');
          },
        );

        // Initialize with null
        await watcher.trigger(null, null);
        
        // Change to number
        await watcher.trigger(42, null);
        expect(changes, equals(['null -> 42']));
        
        // Change to string
        await watcher.trigger('42', 42);
        expect(changes.length, equals(2));
        
        // Change to boolean
        await watcher.trigger(true, '42');
        expect(changes.length, equals(3));
        
        // Change to list
        await watcher.trigger([1, 2, 3], true);
        expect(changes.length, equals(4));
        
        // Change to map
        await watcher.trigger({'key': 'value'}, [1, 2, 3]);
        expect(changes.length, equals(5));
      });

      test('should detect changes in collections', () async {
        var changeCount = 0;
        
        final watcher = StateWatcher(
          path: 'collection',
          onChange: (newValue, oldValue) async {
            changeCount++;
          },
        );

        // Initialize
        final list1 = [1, 2, 3];
        await watcher.trigger(list1, null);
        
        // Same reference - no change
        await watcher.trigger(list1, list1);
        expect(changeCount, equals(0));
        
        // Different list with same content - triggers change
        final list2 = [1, 2, 3];
        await watcher.trigger(list2, list1);
        expect(changeCount, equals(1));
        
        // Modified list
        final list3 = [1, 2, 3, 4];
        await watcher.trigger(list3, list2);
        expect(changeCount, equals(2));
      });
    });

    group('Debug Mode', () {
      test('should respect debug mode setting', () {
        final watcherWithDebug = StateWatcher(
          path: 'debug.enabled',
          onChange: (newValue, oldValue) async {},
          enableDebugMode: true,
        );

        final watcherWithoutDebug = StateWatcher(
          path: 'debug.disabled',
          onChange: (newValue, oldValue) async {},
          enableDebugMode: false,
        );

        expect(watcherWithDebug.enableDebugMode, isTrue);
        expect(watcherWithoutDebug.enableDebugMode, isFalse);
      });
    });
  });
}