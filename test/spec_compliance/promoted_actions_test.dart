// Every *action slot* promoted into the registry in spec 1.4.1.
//
// Kept apart from `promoted_properties_test.dart` on purpose: an action slot
// has to accept three shapes (one action, a list of them, a binding) and be
// dispatched, while a value property only has to carry a value. Judging a name
// like `onHover` or `onDeleted` by the property rules would let a slot pass
// while it was still read as `as Map<String, dynamic>?` — which is exactly the
// state seven of these were in when they were promoted.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_core/flutter_mcp_ui_core.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

class _Slot {
  final String widget;
  final String slot;
  final Map<String, dynamic> base;
  const _Slot(this.widget, this.slot, this.base);
}

void main() {
  const slots = <_Slot>[
    _Slot('bottomSheet', 'onClosing', <String, dynamic>{'type': 'bottomSheet'}),  // bottomSheet.onClosing
    _Slot('calendar', 'onMonthChange', <String, dynamic>{'type': 'calendar'}),  // calendar.onMonthChange
    _Slot('chip', 'onDeleted', <String, dynamic>{'type': 'chip', 'label': 'x'}),  // chip.onDeleted
    _Slot('draggable', 'onDragCompleted', <String, dynamic>{'type': 'draggable', 'data': 'x'}),  // draggable.onDragCompleted
    _Slot('draggable', 'onDragEnd', <String, dynamic>{'type': 'draggable', 'data': 'x'}),  // draggable.onDragEnd
    _Slot('draggable', 'onDragStarted', <String, dynamic>{'type': 'draggable', 'data': 'x'}),  // draggable.onDragStarted
    _Slot('draggable', 'onDraggableCanceled', <String, dynamic>{'type': 'draggable', 'data': 'x'}),  // draggable.onDraggableCanceled
    _Slot('gestureDetector', 'onScaleUpdate', <String, dynamic>{'type': 'gestureDetector'}),  // gestureDetector.onScaleUpdate
    _Slot('inkWell', 'onHighlightChanged', <String, dynamic>{'type': 'inkWell'}),  // inkWell.onHighlightChanged
    _Slot('inkWell', 'onHover', <String, dynamic>{'type': 'inkWell'}),  // inkWell.onHover
    _Slot('inkWell', 'onTapCancel', <String, dynamic>{'type': 'inkWell'}),  // inkWell.onTapCancel
    _Slot('inkWell', 'onTapDown', <String, dynamic>{'type': 'inkWell'}),  // inkWell.onTapDown
    _Slot('inkWell', 'onTapUp', <String, dynamic>{'type': 'inkWell'}),  // inkWell.onTapUp
    _Slot('lottieAnimation', 'onComplete', <String, dynamic>{'type': 'lottieAnimation'}),  // lottieAnimation.onComplete
    _Slot('mediaPlayer', 'onSeek', <String, dynamic>{'type': 'mediaPlayer'}),  // mediaPlayer.onSeek
    _Slot('networkGraph', 'onEdgeTap', <String, dynamic>{'type': 'networkGraph'}),  // networkGraph.onEdgeTap
    _Slot('popupMenuButton', 'onCanceled', <String, dynamic>{'type': 'popupMenuButton', 'items': <dynamic>[]}),  // popupMenuButton.onCanceled
    _Slot('popupMenuButton', 'onOpened', <String, dynamic>{'type': 'popupMenuButton', 'items': <dynamic>[]}),  // popupMenuButton.onOpened
    _Slot('rangeSlider', 'onChangeEnd', <String, dynamic>{'type': 'rangeSlider'}),  // rangeSlider.onChangeEnd
    _Slot('rangeSlider', 'onChangeStart', <String, dynamic>{'type': 'rangeSlider'}),  // rangeSlider.onChangeStart
    _Slot('signature', 'onSignatureStart', <String, dynamic>{'type': 'signature'}),  // signature.onSignatureStart
    _Slot('slider', 'onChangeEnd', <String, dynamic>{'type': 'slider'}),  // slider.onChangeEnd
    _Slot('slider', 'onChangeStart', <String, dynamic>{'type': 'slider'}),  // slider.onChangeStart
  ];

  Map<String, dynamic> one() => <String, dynamic>{
        'type': 'state',
        'action': 'set',
        'binding': 'a',
        'value': 'ran',
      };

  test('every promoted action slot takes one action', () {
    final bad = <String>[];
    for (final s in slots) {
      final r = validateMcpUiDslWidget(<String, dynamic>{...s.base, s.slot: one()});
      if (!r.isValid) bad.add('${s.widget}.${s.slot}: ${r.errors.take(1).join()}');
    }
    expect(bad, isEmpty, reason: bad.take(10).join('\n'));
  });

  test('every promoted action slot takes a list of actions', () {
    final bad = <String>[];
    for (final s in slots) {
      final r = validateMcpUiDslWidget(
          <String, dynamic>{...s.base, s.slot: <dynamic>[one(), one()]});
      if (!r.isValid) bad.add('${s.widget}.${s.slot}: ${r.errors.take(1).join()}');
    }
    expect(bad, isEmpty,
        reason: 'a slot that refuses the list form makes the array spelling '
            'an authoring error:\n${bad.take(10).join('\n')}');
  });

  test('every promoted action slot takes a binding', () {
    final bad = <String>[];
    for (final s in slots) {
      final r = validateMcpUiDslWidget(
          <String, dynamic>{...s.base, s.slot: '{{state.handler}}'});
      if (!r.isValid) bad.add('${s.widget}.${s.slot}: ${r.errors.take(1).join()}');
    }
    expect(bad, isEmpty, reason: bad.take(10).join('\n'));
  });

  // Sheets and dialogs draw when they are *shown*, not where they are written,
  // so putting one in page content renders nothing. Their slots stay covered by
  // the three validation cases above.
  const notInlineRendered = <String>{
    'bottomSheet', 'snackBar', 'alertDialog', 'customDialog', 'simpleDialog'
  };

  for (final s in slots) {
    if (notInlineRendered.contains(s.widget)) continue;
    testWidgets('${s.widget}.${s.slot} renders with a list of actions',
        (tester) async {
      final runtime = MCPUIRuntime();
      await runtime.initialize(<String, dynamic>{
        'type': 'page',
        'state': <String, dynamic>{
          'initial': <String, dynamic>{'a': 'untouched'},
        },
        'content': <String, dynamic>{...s.base, s.slot: <dynamic>[one(), one()]},
      });
      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // A tree that never mounted contains no error either, so "no error" only
      // means something when something was drawn.
      expect(tester.allWidgets.length, greaterThan(20),
          reason: '${s.widget} did not mount, so this case proves nothing');
      expect(find.textContaining('Error rendering'), findsNothing,
          reason: '${s.widget}.${s.slot} fails on the list form');
      await runtime.destroy();
    });
  }
}
