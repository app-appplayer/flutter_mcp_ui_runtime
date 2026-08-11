// §5.3.4 has one reading now. These pin the holes that were open when four
// parsers each had their own.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/utils/color_parser.dart';
import 'package:flutter_mcp_ui_runtime/src/utils/mcp_logger.dart';

List<String> _capture(void Function() body) {
  final records = <String>[];
  MCPLogger.onRecord = (r) => records.add(r.message);
  DslColor.resetWarnings();
  try {
    body();
  } finally {
    MCPLogger.onRecord = null;
  }
  return records;
}

void main() {
  setUp(DslColor.resetWarnings);

  group('accepted spellings', () {
    test('hex in all three lengths, alpha first', () {
      expect(DslColor.parse('#fff'), const Color(0xFFFFFFFF));
      expect(DslColor.parse('#2196F3'), const Color(0xFF2196F3));
      expect(DslColor.parse('#80000000'), const Color(0x80000000));
    });

    test('the ten basic names, case-insensitively', () {
      expect(DslColor.parse('RED'), Colors.red);
      expect(DslColor.parse('grey'), Colors.grey);
      expect(DslColor.parse('gray'), Colors.grey);
    });

    test('functional rgb / rgba — §5.3.4 SHOULD', () {
      expect(DslColor.parse('rgb(33, 150, 243)'), const Color(0xFF2196F3));
      expect(DslColor.parse('rgba(0, 0, 0, 0.5)'), const Color(0x80000000));
    });

    test('a scheme slot resolves through the theme', () {
      expect(
        DslColor.parse('primary', slotResolver: (_) => const Color(0xFF112233)),
        const Color(0xFF112233),
      );
    });
  });

  group('what used to be silent', () {
    test('a malformed hex is reported, not dropped', () {
      final logs = _capture(() => DslColor.parse('#12345'));
      expect(logs.where((m) => m.contains('#12345')), hasLength(1),
          reason: 'the hex branch returned null without a word, which is the '
              'same failure the unrecognised-name warning was added for');
    });

    test('a channel out of range is reported', () {
      final logs = _capture(() => DslColor.parse('rgb(300, 0, 0)'));
      expect(logs.where((m) => m.contains('0-255')), hasLength(1));
    });

    test('an unrecognised name is reported', () {
      final logs = _capture(() => DslColor.parse('tomato'));
      expect(logs.where((m) => m.contains('tomato')), hasLength(1));
    });
  });

  group('what must stay silent', () {
    test('a valid slot on a surface with no theme is not called invalid', () {
      final logs = _capture(() => DslColor.parse('onSurfaceVariant'));
      expect(logs, isEmpty,
          reason: 'the name is valid; this surface simply has nothing to '
              'resolve it against, and blaming the document would send the '
              'author to fix a correct line');
      expect(DslColor.parse('onSurfaceVariant'), isNull);
    });

    test('an unresolved binding belongs to the binding layer', () {
      final logs = _capture(() => DslColor.parse('{{state.color}}'));
      expect(logs, isEmpty);
    });
  });

  test('a slot missing from the active theme is reported', () {
    final logs = _capture(() => DslColor.parse('tertiaryContainer',
        slotResolver: (_) => null));
    expect(logs.where((m) => m.contains('active theme')), hasLength(1));
  });

  test('a legacy alias whose canonical slot the theme lacks is reported by '
      'both names', () {
    // `divider` is accepted as an old spelling of `outlineVariant`. When the
    // theme has neither, the author needs to see WHICH slot was looked for —
    // being told "divider is missing" sends them to add a slot the runtime
    // does not read.
    final logs = _capture(
        () => DslColor.parse('divider', slotResolver: (_) => null));

    expect(logs.where((m) => m.contains('outlineVariant')), hasLength(1));
    expect(logs.single, contains('divider'));
  });

  test('an rgba alpha outside 0-1 is reported rather than clamped', () {
    // `rgba(0,0,0,255)` is the CSS-with-an-alpha-byte mistake. Clamping it to
    // opaque would draw the right thing for the wrong reason and leave the
    // document wrong everywhere else it uses that value.
    final logs = _capture(() => DslColor.parse('rgba(10, 20, 30, 255)'));

    expect(logs.where((m) => m.contains('0-1')), hasLength(1));
    expect(DslColor.parse('rgba(10, 20, 30, 255)'), isNull);
  });

  test('reporting is bounded — state can produce values without end', () {
    final logs = _capture(() {
      for (var i = 0; i < 400; i++) {
        DslColor.parse('notacolor$i');
      }
    });
    expect(logs.length, lessThan(140),
        reason: 'an unbounded warn-once set grows for the life of the '
            'process; the cap is the point');
    expect(logs.last, contains('stopped reporting'));
  });

  test('a legacy slot name resolves onto the role it meant', () {
    // A document written before §5.3.1's roles says `divider`. It used to
    // resolve to nothing — an invisible line — and after 1.4 typed the
    // property as `Color` it stopped loading at all.
    expect(
        DslColor.parse('divider',
            slotResolver: (slot) =>
                slot == 'outlineVariant' ? const Color(0xFF445566) : null),
        const Color(0xFF445566));
    expect(
        DslColor.parse('textOnSurface',
            slotResolver: (slot) =>
                slot == 'onSurface' ? const Color(0xFF112233) : null),
        const Color(0xFF112233));
  });

  test('the slots the schema declares are the slots this parser reads', () {
    // Two lists of scheme roles, written a year apart, in two repositories'
    // worth of file. When they disagree the failure is silent in both
    // directions: a name only the schema knows loads and paints nothing, and a
    // name only the parser knows is rejected before the document opens.
    final repo = Directory.current.path.split('/packages/')[0];
    final schemaFile = File(
        '$repo/specs/mcp_ui_dsl/spec/1.4/schema/widgets.schema.json');
    if (!schemaFile.existsSync()) return; // published checkout, no spec tree

    final color = (jsonDecode(schemaFile.readAsStringSync())
        as Map<String, dynamic>)[r'$defs']['Color'] as Map<String, dynamic>;
    final declared = <String>{
      for (final branch in color['oneOf'] as List)
        if (branch is Map && branch['enum'] is List)
          ...(branch['enum'] as List).cast<String>(),
    };

    // Legacy slot names count as read: they resolve through
    // `DslColor.legacyAliases` onto a canonical role.
    final readable =
        DslColor.schemeSlots.union(DslColor.legacyAliases.keys.toSet());
    expect(declared.difference(readable), isEmpty,
        reason: 'the schema accepts these names, so a document carrying one '
            'loads — and this parser answers null, which paints nothing');
    expect(readable.difference(declared), isEmpty,
        reason: 'this parser reads these names, but a document carrying one '
            'is rejected before it ever reaches the parser');
    for (final entry in DslColor.legacyAliases.entries) {
      expect(DslColor.schemeSlots, contains(entry.value),
          reason: '${entry.key} maps onto ${entry.value}, which is not a slot');
    }
  });
}
