/// QR encoder structure — spec §10.23.
///
/// **What these tests can and cannot prove.** A unit test can check that the
/// symbol has the shape the standard requires: the right size for its version,
/// finder patterns where a scanner looks for them, timing patterns that
/// alternate, alignment patterns from version 2, and a payload that refuses
/// rather than truncates when it does not fit. It cannot prove a scanner reads
/// the result — that needs a real camera against a rendered code, and this
/// encoder is not considered verified until that has been done.
///
/// The structural checks are still worth having: every failure mode they catch
/// (wrong size, misplaced finder, silent truncation) produces a code that
/// looks plausible on screen and scans as nothing.
library qr_encoder_test;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/widgets/advanced/qr_encoder.dart';

void main() {
  QrSymbol encode(String s, [QrErrorCorrection ec = QrErrorCorrection.m]) =>
      encodeQr(s.codeUnits, ec);

  group('version sizing', () {
    test('a short payload fits version 1 (21 modules)', () {
      expect(encode('hi').size, 21);
    });

    test('the symbol grows by 4 modules per version', () {
      // Longer payloads must step up versions rather than overflow.
      final sizes = <int>{
        for (final n in [1, 20, 40, 70, 110, 160])
          encode('x' * n).size,
      };
      for (final s in sizes) {
        expect((s - 21) % 4, 0, reason: 'size $s is not 21 + 4n');
        expect(s, inInclusiveRange(21, 57)); // versions 1..10
      }
      expect(sizes.length, greaterThan(1),
          reason: 'longer payloads must select larger versions');
    });

    test('higher error correction needs a larger symbol for the same payload',
        () {
      final l = encode('x' * 60, QrErrorCorrection.l).size;
      final h = encode('x' * 60, QrErrorCorrection.h).size;
      expect(h, greaterThanOrEqualTo(l));
    });
  });

  group('finder patterns', () {
    // A scanner locates the symbol by these three 7x7 rings. Misplace one and
    // the code is undetectable no matter how correct the data is.
    void expectFinderAt(QrSymbol s, int ox, int oy) {
      for (var dy = 0; dy < 7; dy++) {
        for (var dx = 0; dx < 7; dx++) {
          final onRing = dx == 0 || dx == 6 || dy == 0 || dy == 6;
          final inCore = dx >= 2 && dx <= 4 && dy >= 2 && dy <= 4;
          expect(
            s.isDark(ox + dx, oy + dy),
            onRing || inCore,
            reason: 'finder at ($ox,$oy) module ($dx,$dy)',
          );
        }
      }
    }

    test('all three corners carry a finder', () {
      final s = encode('https://example.com');
      expectFinderAt(s, 0, 0);
      expectFinderAt(s, s.size - 7, 0);
      expectFinderAt(s, 0, s.size - 7);
    });

    test('the fourth corner does not', () {
      final s = encode('https://example.com');
      // Bottom-right holds data (and an alignment pattern), never a finder.
      final allDark = [
        for (var d = 0; d < 7; d++) s.isDark(s.size - 1 - d, s.size - 1)
      ].every((v) => v);
      expect(allDark, isFalse);
    });

    test('separators keep the finder isolated', () {
      final s = encode('hi');
      for (var i = 0; i < 8; i++) {
        expect(s.isDark(i, 7), isFalse, reason: 'separator row');
        expect(s.isDark(7, i), isFalse, reason: 'separator column');
      }
    });
  });

  group('timing patterns', () {
    test('row 6 and column 6 alternate', () {
      final s = encode('https://example.com/a/b/c');
      for (var i = 8; i < s.size - 8; i++) {
        expect(s.isDark(i, 6), i % 2 == 0, reason: 'timing row at $i');
        expect(s.isDark(6, i), i % 2 == 0, reason: 'timing column at $i');
      }
    });
  });

  group('alignment patterns', () {
    test('version 1 has none — asserted by size, not by sampling', () {
      // A v1 symbol is 21 modules and the standard defines no alignment
      // pattern for it. Sampling a module to prove absence does not work:
      // that corner is data, so it is dark or light by payload, and a test
      // that reads it would pass or fail for the wrong reason.
      expect(encode('hi').size, 21);
    });

    test('version 2+ carries one at the far corner', () {
      final s = encode('x' * 30);
      expect(s.size, greaterThanOrEqualTo(25));
      final c = s.size - 7;
      expect(s.isDark(c, c), isTrue, reason: 'alignment centre');
      expect(s.isDark(c - 1, c), isFalse, reason: 'alignment inner ring');
      expect(s.isDark(c - 2, c), isTrue, reason: 'alignment outer ring');
    });
  });

  group('fixed modules', () {
    test('the dark module is set', () {
      final s = encode('hi');
      expect(s.isDark(8, s.size - 8), isTrue);
    });
  });

  group('capacity', () {
    test('an oversized payload throws rather than truncating', () {
      // Silent truncation is the dangerous failure: the code still scans, and
      // carries something the author never wrote.
      expect(
        () => encode('x' * 400, QrErrorCorrection.h),
        throwsA(isA<QrTooLongException>()),
      );
    });

    test('the boundary is reported with the length', () {
      try {
        encode('x' * 400, QrErrorCorrection.h);
        fail('expected QrTooLongException');
      } on QrTooLongException catch (e) {
        expect(e.byteLength, 400);
      }
    });
  });

  group('determinism', () {
    test('the same payload encodes identically', () {
      final a = encode('https://example.com/i/42');
      final b = encode('https://example.com/i/42');
      for (var y = 0; y < a.size; y++) {
        for (var x = 0; x < a.size; x++) {
          expect(a.isDark(x, y), b.isDark(x, y));
        }
      }
    });

    test('different payloads differ in the data region', () {
      final a = encode('https://example.com/i/42');
      final b = encode('https://example.com/i/43');
      var differences = 0;
      for (var y = 0; y < a.size; y++) {
        for (var x = 0; x < a.size; x++) {
          if (a.isDark(x, y) != b.isDark(x, y)) differences++;
        }
      }
      expect(differences, greaterThan(0));
    });

    test('error correction level changes the symbol', () {
      final m = encode('hello', QrErrorCorrection.m);
      final h = encode('hello', QrErrorCorrection.h);
      var differences = 0;
      final size = m.size < h.size ? m.size : h.size;
      for (var y = 0; y < size; y++) {
        for (var x = 0; x < size; x++) {
          if (m.isDark(x, y) != h.isDark(x, y)) differences++;
        }
      }
      expect(differences, greaterThan(0),
          reason: 'EC level must reach the format info and the data');
    });
  });
}
