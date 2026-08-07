// Differential probe, not an assertion suite.
//
// Prints accept/reject for a matrix of `box` inset values so the same matrix
// can be run against the published registry and the local one and diffed. A
// change to these slots is allowed to turn reject into accept; turning accept
// into reject would stop an already-published bundle from opening, because
// the runtime validates documents at load.
//
// Run: flutter test test/spec_compliance/box_spacing_widening_probe.dart -r silent
// (the matrix goes to stdout through print, one line per case)

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_core/flutter_mcp_ui_core.dart';

void main() {
  test('matrix', () {
    final values = <String, Object?>{
      'number': 8,
      'zero': 0,
      'negative': -4,
      'dimension object': <String, dynamic>{'value': 8, 'unit': 'px'},
      'all': <String, dynamic>{'all': 8},
      'symmetric': <String, dynamic>{'horizontal': 8, 'vertical': 4},
      'edges': <String, dynamic>{'top': 1, 'right': 2, 'bottom': 3, 'left': 4},
      'edge bound': <String, dynamic>{'left': '{{a}}', 'top': 6},
      'binding': '{{layout.pad}}',
      'token': 'md',
      'token 2xl': '2xl',
      'custom slot': 'roomy',
      'token object': <String, dynamic>{'token': 'md'},
      'not a token': '16px',
      'unit string': '1rem',
      'empty string': '',
      'zero string': '0',
      'responsive': <String, dynamic>{'compact': 8, 'expanded': 24},
      'bool': true,
      'list': <dynamic>[8],
    };
    final out = <String>[];
    for (final slot in <String>['padding', 'margin']) {
      values.forEach((name, v) {
        final r = validateMcpUiDslWidget(
            <String, dynamic>{'type': 'box', slot: v});
        out.add('$slot|$name|${r.isValid ? "accept" : "reject"}');
      });
    }
    // ignore: avoid_print
    print('MATRIX_BEGIN\n${out.join('\n')}\nMATRIX_END');
  });
}
