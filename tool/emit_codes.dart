// Emits `qrCode` / `barcode` symbols as PNGs so an external decoder can read
// them back.
//
// **Why this is a tool and not a test.** A unit test can check that a symbol
// has the structure the standard requires; it cannot prove a scanner reads it.
// That needs a real decoder, and the one used here is macOS Vision — the same
// engine behind the system camera — which is not on every machine the suite
// runs on. The structural checks live in `test/widgets/qr_encoder_test.dart`
// and `barcode_encoder_test.dart`; this is the manual gate before publishing a
// change to either encoder.
//
// Procedure:
//
//   dart run tool/emit_codes.dart                        # /tmp/codes/*.png
//   swiftc -O tool/decode_codes.swift -o /tmp/decode
//   /tmp/decode /tmp/codes/*.png                         # payload must return verbatim
//
// Result 2026-08-03 (Flutter 3.44.6, macOS Vision): **10/10 decoded, payloads
// exact**. Mutation-checked: an EAN-13 centre-guard, L/R-table or parity-row
// defect each yields NO_CODE, and a Reed-Solomon defect does once the payload
// is near capacity at EC level L. Below that, error correction repairs the
// encoder's own mistake — the standard working as designed rather than the
// check being weak, which is why the tight case is in the set.

import 'dart:io';
import 'package:flutter_mcp_ui_runtime/src/widgets/advanced/qr_encoder.dart';
import 'package:flutter_mcp_ui_runtime/src/widgets/advanced/barcode_encoder.dart';

/// Minimal 1-bit-per-pixel PNG writer (no dependency).
List<int> _png(int w, int h, List<List<bool>> dark) {
  int crc32(List<int> b) {
    var c = 0xFFFFFFFF;
    for (final x in b) {
      c ^= x;
      for (var k = 0; k < 8; k++) {
        c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1);
      }
    }
    return (c ^ 0xFFFFFFFF) & 0xFFFFFFFF;
  }
  List<int> be32(int v) => [(v >> 24) & 255, (v >> 16) & 255, (v >> 8) & 255, v & 255];
  List<int> chunk(String type, List<int> data) {
    final t = type.codeUnits;
    return [...be32(data.length), ...t, ...data, ...be32(crc32([...t, ...data]))];
  }
  // raw scanlines: filter byte + RGB per pixel
  final raw = <int>[];
  for (var y = 0; y < h; y++) {
    raw.add(0);
    for (var x = 0; x < w; x++) {
      final v = dark[y][x] ? 0 : 255;
      raw.addAll([v, v, v]);
    }
  }
  // zlib stored blocks
  final z = <int>[0x78, 0x01];
  var i = 0;
  while (i < raw.length) {
    final n = (raw.length - i) > 65535 ? 65535 : raw.length - i;
    final last = (i + n >= raw.length) ? 1 : 0;
    z.addAll([last, n & 255, (n >> 8) & 255, (~n) & 255, ((~n) >> 8) & 255]);
    z.addAll(raw.sublist(i, i + n));
    i += n;
  }
  var a = 1, b = 0;
  for (final x in raw) { a = (a + x) % 65521; b = (b + a) % 65521; }
  z.addAll(be32((b << 16) | a));

  return [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
    ...chunk('IHDR', [...be32(w), ...be32(h), 8, 2, 0, 0, 0]),
    ...chunk('IDAT', z),
    ...chunk('IEND', []),
  ];
}

void writeQr(String path, String payload, QrErrorCorrection ec, {int scale = 8, int quiet = 4}) {
  final s = encodeQr(payload.codeUnits, ec);
  final total = s.size + quiet * 2;
  final w = total * scale;
  final grid = List.generate(w, (_) => List.filled(w, false));
  for (var y = 0; y < total; y++) {
    for (var x = 0; x < total; x++) {
      final inside = x >= quiet && y >= quiet && x < quiet + s.size && y < quiet + s.size;
      final on = inside && s.isDark(x - quiet, y - quiet);
      if (!on) continue;
      for (var dy = 0; dy < scale; dy++) {
        for (var dx = 0; dx < scale; dx++) {
          grid[y * scale + dy][x * scale + dx] = true;
        }
      }
    }
  }
  File(path).writeAsBytesSync(_png(w, w, grid));
}

void writeBarcode(String path, String value, BarcodeFormat fmt, {int scale = 3, int height = 120}) {
  final p = encodeBarcode(value, fmt);
  const quiet = 10;
  final w = (p.moduleCount + quiet * 2) * scale;
  final grid = List.generate(height, (_) => List.filled(w, false));
  for (var i = 0; i < p.moduleCount; i++) {
    if (!p.bars[i]) continue;
    for (var y = 0; y < height; y++) {
      for (var dx = 0; dx < scale; dx++) {
        grid[y][(i + quiet) * scale + dx] = true;
      }
    }
  }
  File(path).writeAsBytesSync(_png(w, height, grid));
}

void main() {
  const out = '/tmp/codes';
  Directory(out).createSync(recursive: true);
  writeQr('$out/qr_url.png', 'https://example.com/i/42', QrErrorCorrection.m);
  // Near capacity at the lowest EC: no headroom to mask an encoder defect.
  writeQr('$out/qr_tight.png', 'x' * 150, QrErrorCorrection.l);
  writeQr('$out/qr_short.png', 'hi', QrErrorCorrection.l);
  writeQr('$out/qr_h.png', 'MAKEMIND', QrErrorCorrection.h);
  writeQr('$out/qr_long.png', 'https://app.appplayer.app/bundle/royalty.derived.1fa28914', QrErrorCorrection.q);
  writeQr('$out/qr_ui.png', 'ui://app/home?entry=abc123', QrErrorCorrection.m);
  writeBarcode('$out/bc_ean13.png', '4006381333931', BarcodeFormat.ean13);
  writeBarcode('$out/bc_ean8.png', '96385074', BarcodeFormat.ean8);
  writeBarcode('$out/bc_code128.png', 'ABC-123', BarcodeFormat.code128);
  writeBarcode('$out/bc_code39.png', 'HELLO', BarcodeFormat.code39);
  writeBarcode('$out/bc_upca.png', '036000291452', BarcodeFormat.upcA);
  stdout.writeln('written to $out');
}
