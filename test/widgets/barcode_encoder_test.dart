/// Barcode encoders — spec §10.24.
///
/// Same limit as the QR tests: structure is checkable here, readability is
/// not. What these do cover is the failure that matters most for 1-D codes —
/// a payload that does not satisfy its symbology must be refused, because an
/// EAN-13 with a wrong check digit scans perfectly and reports a different
/// product.
library barcode_encoder_test;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/widgets/advanced/barcode_encoder.dart';

void main() {
  group('EAN-13', () {
    test('accepts a valid 13-digit payload unchanged', () {
      // 4006381333931 is a well-formed EAN-13 (check digit 1).
      final p = encodeBarcode('4006381333931', BarcodeFormat.ean13);
      expect(p.text, '4006381333931');
    });

    test('completes an omitted check digit rather than refusing', () {
      final p = encodeBarcode('400638133393', BarcodeFormat.ean13);
      expect(p.text, '4006381333931');
    });

    test('refuses a wrong check digit', () {
      // The dangerous case: this renders and scans, and means another product.
      expect(
        () => encodeBarcode('4006381333939', BarcodeFormat.ean13),
        throwsA(isA<BarcodeFormatException>()),
      );
    });

    test('refuses non-digits and wrong lengths', () {
      expect(() => encodeBarcode('40063813339A1', BarcodeFormat.ean13),
          throwsA(isA<BarcodeFormatException>()));
      expect(() => encodeBarcode('40063', BarcodeFormat.ean13),
          throwsA(isA<BarcodeFormatException>()));
    });

    test('has the standard module count: 95', () {
      // 3 guard + 6x7 + 5 centre + 6x7 + 3 guard.
      final p = encodeBarcode('4006381333931', BarcodeFormat.ean13);
      expect(p.moduleCount, 95);
    });

    test('starts and ends with the guard pattern', () {
      final p = encodeBarcode('4006381333931', BarcodeFormat.ean13);
      expect(p.bars.take(3).toList(), [true, false, true]);
      expect(p.bars.skip(92).toList(), [true, false, true]);
    });

    test('carries the centre guard at the midpoint', () {
      final p = encodeBarcode('4006381333931', BarcodeFormat.ean13);
      expect(p.bars.skip(45).take(5).toList(),
          [false, true, false, true, false]);
    });
  });

  group('EAN-8', () {
    test('completes the check digit and has 67 modules', () {
      final p = encodeBarcode('9638507', BarcodeFormat.ean8);
      expect(p.text.length, 8);
      expect(p.moduleCount, 67);
    });
  });

  group('UPC-A', () {
    test('is EAN-13 with a leading zero', () {
      final upc = encodeBarcode('03600029145', BarcodeFormat.upcA);
      final ean = encodeBarcode('003600029145', BarcodeFormat.ean13);
      expect(upc.bars, ean.bars);
    });
  });

  group('Code 128', () {
    test('encodes printable ASCII', () {
      final p = encodeBarcode('ABC-123', BarcodeFormat.code128);
      expect(p.text, 'ABC-123');
      expect(p.moduleCount, greaterThan(0));
    });

    test('refuses control characters', () {
      expect(() => encodeBarcode('AB', BarcodeFormat.code128),
          throwsA(isA<BarcodeFormatException>()));
    });

    test('module count grows with payload length', () {
      final a = encodeBarcode('A', BarcodeFormat.code128).moduleCount;
      final b = encodeBarcode('AAAA', BarcodeFormat.code128).moduleCount;
      expect(b, greaterThan(a));
      // Each symbol is 11 modules, plus a 13-module stop.
      expect((b - a) % 11, 0);
    });
  });

  group('Code 39', () {
    test('uppercases and wraps in start/stop', () {
      final p = encodeBarcode('ab-1', BarcodeFormat.code39);
      expect(p.text, 'AB-1');
    });

    test('refuses characters outside the set', () {
      expect(() => encodeBarcode('a=b', BarcodeFormat.code39),
          throwsA(isA<BarcodeFormatException>()));
    });
  });

  group('ITF', () {
    test('pads an odd digit count with a leading zero', () {
      // Digits interleave in pairs, so an odd count cannot be encoded.
      final p = encodeBarcode('12345', BarcodeFormat.itf);
      expect(p.text, '012345');
    });

    test('refuses non-digits', () {
      expect(() => encodeBarcode('12A45', BarcodeFormat.itf),
          throwsA(isA<BarcodeFormatException>()));
    });
  });

  group('Codabar', () {
    test('supplies start/stop letters when absent', () {
      final p = encodeBarcode('1234', BarcodeFormat.codabar);
      expect(p.text, 'A1234B');
    });

    test('keeps author-supplied start/stop', () {
      final p = encodeBarcode('C1234D', BarcodeFormat.codabar);
      expect(p.text, 'C1234D');
    });
  });

  group('unsupported', () {
    test('UPC-E reports rather than rendering something else', () {
      expect(() => encodeBarcode('01234565', BarcodeFormat.upcE),
          throwsA(isA<BarcodeFormatException>()));
    });
  });

  group('a payload the format cannot carry', () {
    test('an out-of-alphabet character is named, with the format', () {
      // Codabar carries digits and six symbols; a letter in the middle is the
      // ordinary mistake, and the message has to say WHICH character so the
      // author can find it in a long payload.
      Object? thrown;
      try {
        encodeBarcode('12X4', BarcodeFormat.codabar);
      } catch (e) {
        thrown = e;
      }

      expect(thrown, isA<BarcodeFormatException>());
      expect(thrown.toString(), contains('codabar'));
      expect(thrown.toString(), contains('X'),
          reason: 'a refusal that does not name the character leaves the '
              'author diffing the payload by eye');
    });
  });

  group('determinism', () {
    test('the same payload encodes identically', () {
      final a = encodeBarcode('4006381333931', BarcodeFormat.ean13);
      final b = encodeBarcode('4006381333931', BarcodeFormat.ean13);
      expect(a.bars, b.bars);
    });

    test('different payloads differ', () {
      final a = encodeBarcode('4006381333931', BarcodeFormat.ean13);
      final b = encodeBarcode('4006381333948', BarcodeFormat.ean13);
      expect(a.bars, isNot(equals(b.bars)));
    });
  });
}
