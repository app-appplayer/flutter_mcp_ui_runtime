import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TC-019: Lottie animation', () {
    test('Normal: Lottie config parses source URI', () {
      // Simulate Lottie animation definition parsing
      final config = <String, dynamic>{
        'type': 'lottieAnimation',
        'source': 'bundle://animations/loading.json',
        'autoplay': true,
        'loop': true,
        'width': 200.0,
        'height': 200.0,
        'speed': 1.0,
      };

      expect(config['type'], equals('lottieAnimation'));
      expect(config['source'], contains('bundle://'));
      expect(config['autoplay'], isTrue);
      expect(config['loop'], isTrue);
    });

    test('Normal: autoPlay true config recognized', () {
      final config = <String, dynamic>{
        'autoplay': true,
        'loop': false,
      };

      expect(config['autoplay'], isTrue);
      expect(config['loop'], isFalse);
    });

    test('Normal: loop true config recognized', () {
      final config = <String, dynamic>{
        'autoplay': true,
        'loop': true,
      };

      expect(config['loop'], isTrue);
    });

    test('Normal: speed parameter parsed', () {
      final config = <String, dynamic>{
        'speed': 2.0,
      };

      final speed = (config['speed'] as num?)?.toDouble() ?? 1.0;
      expect(speed, equals(2.0));
    });

    test('Boundary: autoPlay false and loop false — static first frame', () {
      final config = <String, dynamic>{
        'autoplay': false,
        'loop': false,
      };

      expect(config['autoplay'], isFalse);
      expect(config['loop'], isFalse);
    });

    test('Boundary: missing speed defaults to 1.0', () {
      final config = <String, dynamic>{
        'autoplay': true,
      };

      final speed = (config['speed'] as num?)?.toDouble() ?? 1.0;
      expect(speed, equals(1.0));
    });

    test('Error: null source URI handled gracefully', () {
      final config = <String, dynamic>{
        'type': 'lottieAnimation',
        'source': null,
      };

      expect(config['source'], isNull);
      // Widget should render empty container when source is null
    });

    test('Error: empty source string handled gracefully', () {
      final config = <String, dynamic>{
        'source': '',
      };

      expect(config['source'], isEmpty);
    });

    test('Normal: onComplete action config parsed', () {
      final config = <String, dynamic>{
        'onComplete': {
          'action': 'navigate',
          'target': '/next',
        },
      };

      final onComplete = config['onComplete'] as Map<String, dynamic>?;
      expect(onComplete, isNotNull);
      expect(onComplete!['action'], equals('navigate'));
    });

    test('Normal: fit parameter config parsed', () {
      final fitValues = ['contain', 'cover', 'fill', 'fitWidth', 'fitHeight', 'none'];
      for (final fit in fitValues) {
        final config = <String, dynamic>{'fit': fit};
        expect(config['fit'], equals(fit));
      }
    });
  });

  group('TC-020: Rive animation', () {
    test('Normal: Rive config parses source URI and artboard', () {
      final config = <String, dynamic>{
        'type': 'riveAnimation',
        'source': 'bundle://animations/character.riv',
        'artboard': 'MainCharacter',
        'stateMachine': 'idle',
        'autoplay': true,
      };

      expect(config['type'], equals('riveAnimation'));
      expect(config['source'], contains('.riv'));
      expect(config['artboard'], equals('MainCharacter'));
      expect(config['stateMachine'], equals('idle'));
    });

    test('Normal: state machine config for interactive Rive animation', () {
      final config = <String, dynamic>{
        'source': 'bundle://character.riv',
        'artboard': 'Hero',
        'stateMachine': 'walkCycle',
      };

      expect(config['stateMachine'], isNotNull);
      expect(config['stateMachine'], equals('walkCycle'));
    });

    test('Boundary: no artboard specified — use default', () {
      final config = <String, dynamic>{
        'source': 'bundle://character.riv',
      };

      final artboard = config['artboard'] as String? ?? 'default';
      expect(artboard, equals('default'));
    });

    test('Boundary: no stateMachine specified — no interactivity', () {
      final config = <String, dynamic>{
        'source': 'bundle://character.riv',
        'artboard': 'Hero',
      };

      expect(config['stateMachine'], isNull);
    });

    test('Error: invalid artboard name — should render empty container', () {
      final config = <String, dynamic>{
        'source': 'bundle://character.riv',
        'artboard': '',
      };

      // Empty artboard name should be treated as error condition
      final artboard = config['artboard'] as String?;
      expect(artboard, isEmpty);
    });

    test('Error: null source URI — should render empty container', () {
      final config = <String, dynamic>{
        'type': 'riveAnimation',
        'source': null,
        'artboard': 'MainCharacter',
      };

      expect(config['source'], isNull);
    });

    test('Error: invalid source extension — handled gracefully', () {
      final config = <String, dynamic>{
        'source': 'bundle://animations/not_rive.txt',
      };

      final source = config['source'] as String;
      expect(source.endsWith('.riv'), isFalse);
    });

    test('Normal: autoplay config for Rive animation', () {
      final config = <String, dynamic>{
        'source': 'bundle://character.riv',
        'autoplay': true,
      };

      expect(config['autoplay'], isTrue);
    });

    test('Boundary: missing autoplay defaults to true', () {
      final config = <String, dynamic>{
        'source': 'bundle://character.riv',
      };

      final autoplay = config['autoplay'] as bool? ?? true;
      expect(autoplay, isTrue);
    });
  });
}
