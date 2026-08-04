// The rest of what the 1.4 cut narrowed.
//
// `intended_narrowing_test.dart` locks the headline axes on one slot each.
// This file walks the axes the diff against 0.4.3 actually produced, slot by
// slot, so restoring a broken form later cannot quietly re-open a neighbour:
//
//   AssetRef        5 slots — a bare filename is no longer an asset
//   IconRef         8 slots — a number is no longer an icon
//   Dimension       2 slots — a string is no longer a size
//   Color          47 slots — only the five spellings of §5.3.4
//   array<X>       52 slots — a scalar is no longer a list
//   string → enum  ~30 slots — a free string is no longer a mode
//   required        1 slot  — `graph` cannot omit its data
//
// Each case is a *pair*: the same document with a good value must be accepted
// and with a bad value rejected. A rejection on its own proves nothing — a
// missing required property rejects too, and would make the case pass for a
// reason that has nothing to do with the axis under test.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_core/flutter_mcp_ui_core.dart';

void main() {
  /// The axis under test is `prop` on `base`: `good` must pass, `bad` must not.
  void narrows(
    String axis,
    Map<String, dynamic> base,
    String prop, {
    required Object? good,
    required Object? bad,
  }) {
    test('$axis — ${base['type']}.$prop', () {
      final ok = validateMcpUiDslWidget(<String, dynamic>{...base, prop: good});
      expect(ok.isValid, isTrue,
          reason: 'the accepted form stopped being accepted: $prop = $good\n'
              '${ok.errors.take(2).join('\n')}');
      final no = validateMcpUiDslWidget(<String, dynamic>{...base, prop: bad});
      expect(no.isValid, isFalse,
          reason: 'the narrowing was lost: $prop = $bad is valid again');
    });
  }

  group('AssetRef stays narrowed (§2.6) — a bare filename is not an asset', () {
    const bad = 'photo.png';
    for (final slot in const <List<String>>[
      ['avatar', 'src'],
      ['image', 'src'],
      ['image', 'source'],
      ['image', 'backgroundImage'],
      ['lottieAnimation', 'src'],
    ]) {
      narrows('AssetRef', <String, dynamic>{'type': slot[0]}, slot[1],
          good: 'assets/logo.png', bad: bad);
    }

    // The other spellings the primitive names, on one slot.
    const image = <String, dynamic>{'type': 'image'};
    for (final form in const <String>[
      'bundle://img/logo.png',
      'https://example.com/logo.png',
      'data:image/png;base64,iVBORw0KGgo=',
      'client://files/logo.png',
      '{{state.logo}}',
    ]) {
      test('AssetRef — the $form spelling still resolves', () {
        final r =
            validateMcpUiDslWidget(<String, dynamic>{...image, 'src': form});
        expect(r.isValid, isTrue, reason: r.errors.take(2).join('\n'));
      });
    }

    narrows('AssetRef object form', image, 'src',
        good: <String, dynamic>{'uri': 'ui://logo'},
        bad: <String, dynamic>{'url': 'ui://logo'});
    narrows('AssetRef object form with origin', image, 'src',
        good: <String, dynamic>{
          'uri': 'ui://logo',
          'origin': <String, dynamic>{'connection': 'design-server'},
        },
        bad: <String, dynamic>{
          'uri': 'ui://logo',
          'origin': <String, dynamic>{'server': 'design-server'},
        });
    narrows('AssetRef is not a number', image, 'src', good: 'assets/a.png', bad: 7);
  });

  group('IconRef stays narrowed (§2.5) — on every slot that takes one', () {
    for (final slot in const <List<String>>[
      ['button', 'icon'],
      ['floatingActionButton', 'icon'],
      ['icon', 'icon'],
      ['iconButton', 'icon'],
      ['offlineFallback', 'icon'],
      ['permissionPrompt', 'icon'],
      ['rating', 'icon'],
    ]) {
      narrows('IconRef', <String, dynamic>{'type': slot[0]}, slot[1],
          good: 'home', bad: 42);
    }
    narrows(
        'IconRef',
        <String, dynamic>{
          'type': 'popupMenuButton',
          'items': <dynamic>[
            <String, dynamic>{'value': 'a', 'label': 'A'},
          ],
        },
        'icon',
        good: 'home',
        bad: 42);

    const icon = <String, dynamic>{'type': 'icon'};
    narrows('IconRef codepoint form', icon, 'icon',
        good: <String, dynamic>{'codepoint': 0xe88a},
        bad: <String, dynamic>{'code': 0xe88a});
    narrows('IconRef is not a bool', icon, 'icon', good: 'home', bad: true);
  });

  group('Dimension stays narrowed — a size is a number, not text', () {
    const box = <String, dynamic>{'type': 'box'};
    for (final prop in const <String>['width', 'height']) {
      narrows('Dimension', box, prop, good: 120, bad: '120');
      narrows('Dimension (unit suffix)', box, prop, good: 120.5, bad: '120px');
      narrows('Dimension object form', box, prop,
          good: <String, dynamic>{'value': 120, 'unit': 'px'},
          bad: <String, dynamic>{'value': '120', 'unit': 'px'});
      narrows('Dimension object keys', box, prop,
          good: <String, dynamic>{'value': 120},
          bad: <String, dynamic>{'size': 120});
    }
    test('Dimension — a binding still resolves', () {
      final r = validateMcpUiDslWidget(
          <String, dynamic>{'type': 'box', 'width': '{{layout.w}}'});
      expect(r.isValid, isTrue, reason: r.errors.take(2).join('\n'));
    });
  });

  group('Color stays narrowed (§5.3.4) — on every slot that takes one', () {
    const badName = 'tomato';
    for (final slot in const <List<String>>[
      ['avatar', 'color'],
      ['avatar', 'backgroundColor'],
      ['badge', 'color'],
      ['bottomSheet', 'backgroundColor'],
      ['box', 'backgroundColor'],
      ['card', 'color'],
      ['card', 'backgroundColor'],
      ['codeEditor', 'backgroundColor'],
      ['codeEditor', 'textColor'],
      ['decoration', 'color'],
      ['divider', 'color'],
      ['fileExplorer', 'selectedColor'],
      ['graph', 'lineColor'],
      ['graph', 'fillColor'],
      ['graph', 'gridColor'],
      ['headerBar', 'backgroundColor'],
      ['icon', 'color'],
      ['iconButton', 'color'],
      ['lightbox', 'backgroundColor'],
      ['markdown', 'textColor'],
      ['markdown', 'linkColor'],
      ['markdown', 'codeBackgroundColor'],
      ['placeholder', 'color'],
      ['progressBar', 'color'],
      ['progressBar', 'backgroundColor'],
      ['rating', 'color'],
      ['signature', 'penColor'],
      ['signature', 'color'],
      ['signature', 'backgroundColor'],
      ['signature', 'borderColor'],
      ['terminal', 'backgroundColor'],
      ['terminal', 'textColor'],
      ['terminal', 'promptColor'],
      ['tree', 'selectedColor'],
      ['tree', 'lineColor'],
      ['verticalDivider', 'color'],
    ]) {
      final base = <String, dynamic>{'type': slot[0]};
      // A widget whose required property is missing rejects for a reason that
      // is not the axis, so the pair would pass without proving anything.
      if (slot[0] == 'graph') base['data'] = <dynamic>[];
      if (slot[0] == 'tree') base['data'] = <dynamic>[];
      if (slot[0] == 'icon' || slot[0] == 'iconButton') base['icon'] = 'home';
      if (slot[0] == 'lightbox') base['images'] = <dynamic>[];
      narrows('Color', base, slot[1], good: '#ff0000', bad: badName);
    }

    // Required-property widgets, spelled out rather than defaulted.
    narrows(
        'Color',
        <String, dynamic>{'type': 'gauge', 'value': 0.5},
        'valueColor',
        good: 'primary',
        bad: badName);
    narrows(
        'Color',
        <String, dynamic>{'type': 'gauge', 'value': 0.5},
        'backgroundColor',
        good: 'surfaceVariant',
        bad: badName);

    // The nested config types reached through a widget property.
    narrows('Color inside BoxDecoration', <String, dynamic>{'type': 'box'},
        'decoration',
        good: <String, dynamic>{'color': '#112233'},
        bad: <String, dynamic>{'color': badName});
    narrows('Color inside BorderSide', <String, dynamic>{'type': 'box'},
        'decoration',
        good: <String, dynamic>{
          'border': <String, dynamic>{'color': 'outline', 'width': 1},
        },
        bad: <String, dynamic>{
          'border': <String, dynamic>{'color': badName, 'width': 1},
        });
    narrows('Color inside BoxShadow', <String, dynamic>{'type': 'box'},
        'decoration',
        good: <String, dynamic>{
          'boxShadow': <dynamic>[
            <String, dynamic>{'color': '#00000033', 'blurRadius': 4},
          ],
        },
        bad: <String, dynamic>{
          'boxShadow': <dynamic>[
            <String, dynamic>{'color': badName, 'blurRadius': 4},
          ],
        });

    // The five spellings §5.3.4 does name, on one slot.
    for (final form in const <String>[
      'primary',
      '#f00',
      '#ff0000',
      '#ccff0000',
      'red',
      'rgb(255, 0, 0)',
      'rgba(255, 0, 0, 0.5)',
      '{{theme.color.primary}}',
    ]) {
      test('Color — the $form spelling still resolves', () {
        final r = validateMcpUiDslWidget(
            <String, dynamic>{'type': 'box', 'color': form});
        expect(r.isValid, isTrue, reason: r.errors.take(2).join('\n'));
      });
    }
  });

  group('array<X> stays narrowed — a scalar is not a list', () {
    // The 52 slots that took anything before the cut. `'nope'` is not a
    // binding, so the string branch cannot catch it.
    for (final slot in const <List<String>>[
      ['carousel', 'children'],
      ['decoration', 'children'],
      ['dragTarget', 'children'],
      ['drawer', 'children'],
      ['errorRecovery', 'children'],
      ['flow', 'children'],
      ['form', 'children'],
      ['grid', 'children'],
      ['indexedStack', 'children'],
      ['list', 'children'],
      ['pageView', 'children'],
      ['scrollBar', 'children'],
      ['scrollView', 'children'],
      ['simpleDialog', 'children'],
      ['singleChildScrollView', 'children'],
      ['stack', 'children'],
      ['staggeredGrid', 'children'],
      ['tabBarView', 'children'],
      ['visibility', 'children'],
      ['wrap', 'children'],
    ]) {
      final base = <String, dynamic>{'type': slot[0]};
      if (slot[0] == 'staggeredGrid') base['columns'] = 2;
      narrows('array<Widget>', base, slot[1],
          good: <dynamic>[
            <String, dynamic>{'type': 'text', 'content': 'x'},
          ],
          bad: 'nope');
    }

    for (final slot in const <List<String>>[
      ['checkboxGroup', 'options'],
      ['checkboxGroup', 'items'],
      ['radioGroup', 'options'],
      ['radioGroup', 'items'],
      ['segmentedControl', 'options'],
      ['segmentedControl', 'segments'],
      ['select', 'options'],
      ['select', 'items'],
      ['simpleDialog', 'options'],
    ]) {
      narrows('array<Option>', <String, dynamic>{'type': slot[0]}, slot[1],
          good: <dynamic>[
            <String, dynamic>{'value': 'a', 'label': 'A'},
          ],
          bad: 'nope');
    }

    narrows('array<string>', <String, dynamic>{'type': 'fileExplorer'}, 'files',
        good: <dynamic>['a.txt'], bad: 'a.txt');
    narrows('array<string>', <String, dynamic>{'type': 'fileExplorer'},
        'directories', good: <dynamic>['src'], bad: 'src');
    narrows('array<string>',
        <String, dynamic>{'type': 'permissionPrompt'}, 'permissions',
        good: <dynamic>['camera'], bad: 'camera');
    narrows(
        'array<string>',
        <String, dynamic>{
          'type': 'heatmap',
          'data': <dynamic>[
            <dynamic>[1, 2],
          ],
        },
        'rowLabels',
        good: <dynamic>['Mon'],
        bad: 'Mon');
    narrows(
        'array<string>',
        <String, dynamic>{
          'type': 'heatmap',
          'data': <dynamic>[
            <dynamic>[1, 2],
          ],
        },
        'columnLabels',
        good: <dynamic>['AM'],
        bad: 'AM');

    narrows('array<object>', <String, dynamic>{'type': 'banner', 'message': 'x'},
        'actions',
        good: <dynamic>[
          <String, dynamic>{'label': 'OK'},
        ],
        bad: 'OK');
    narrows('array<object>', <String, dynamic>{'type': 'bottomNavigation'},
        'items',
        good: <dynamic>[
          <String, dynamic>{'label': 'Home', 'icon': 'home'},
        ],
        bad: 'Home');
    narrows('array<object>', <String, dynamic>{'type': 'navigationRail'},
        'destinations',
        good: <dynamic>[
          <String, dynamic>{'label': 'Home', 'icon': 'home'},
        ],
        bad: 'Home');
    narrows('array<object>', <String, dynamic>{'type': 'drawer'}, 'items',
        good: <dynamic>[
          <String, dynamic>{'label': 'Home'},
        ],
        bad: 'Home');
    narrows(
        'array<object>',
        <String, dynamic>{
          'type': 'dataTable',
          'rows': <dynamic>[],
        },
        'columns',
        good: <dynamic>[
          <String, dynamic>{'label': 'Name', 'field': 'name'},
        ],
        bad: 'Name');
    narrows('array<object>', <String, dynamic>{'type': 'gauge', 'value': 0.5},
        'segments',
        good: <dynamic>[
          <String, dynamic>{'from': 0, 'to': 1, 'color': '#f00'},
        ],
        bad: 'red');
    narrows('array<object>', <String, dynamic>{'type': 'map'}, 'markers',
        good: <dynamic>[
          <String, dynamic>{'latitude': 0, 'longitude': 0},
        ],
        bad: '0,0');
    narrows('array<object>', <String, dynamic>{'type': 'popupMenuButton'},
        'items',
        good: <dynamic>[
          <String, dynamic>{'value': 'a', 'label': 'A'},
        ],
        bad: 'A');
    narrows('array<object>', <String, dynamic>{'type': 'stepper'}, 'steps',
        good: <dynamic>[
          <String, dynamic>{'title': 'One'},
        ],
        bad: 'One');
    narrows('array<object>', <String, dynamic>{'type': 'tabBar'}, 'tabs',
        good: <dynamic>[
          <String, dynamic>{'label': 'One'},
        ],
        bad: 'One');
    narrows('array<object>', <String, dynamic>{'type': 'timeline'}, 'items',
        good: <dynamic>[
          <String, dynamic>{'title': 'One'},
        ],
        bad: 'One');
    narrows('array<object>', <String, dynamic>{'type': 'table'}, 'rows',
        good: <dynamic>[
          <String, dynamic>{'cells': <dynamic>[]},
        ],
        bad: 'One');
    narrows('array<object>', <String, dynamic>{'type': 'conditional'}, 'cases',
        good: <dynamic>[
          <String, dynamic>{
            'value': 'a',
            'child': <String, dynamic>{'type': 'text', 'content': 'x'},
          },
        ],
        bad: 'a');
    // `graph.data` also declares the state-path spelling (`"chart.points"`),
    // so a bare word is accepted there on purpose. The scalar is what narrowed.
    narrows('array<object>', <String, dynamic>{'type': 'graph'}, 'data',
        good: <dynamic>[
          <String, dynamic>{'x': 0, 'y': 1},
        ],
        bad: 42);

    // A list slot still accepts the binding that produces the list.
    for (final slot in const <List<String>>[
      ['wrap', 'children'],
      ['select', 'options'],
      ['tabBar', 'tabs'],
    ]) {
      test('array<X> — ${slot[0]}.${slot[1]} still takes a binding', () {
        final r = validateMcpUiDslWidget(
            <String, dynamic>{'type': slot[0], slot[1]: '{{state.items}}'});
        expect(r.isValid, isTrue, reason: r.errors.take(2).join('\n'));
      });
    }
  });

  group('array<Widget> checks its elements, not just its shape', () {
    narrows('element type', <String, dynamic>{'type': 'wrap'}, 'children',
        good: <dynamic>[
          <String, dynamic>{'type': 'text', 'content': 'x'},
        ],
        bad: <dynamic>['x']);
    narrows('element is a known widget', <String, dynamic>{'type': 'stack'},
        'children',
        good: <dynamic>[
          <String, dynamic>{'type': 'box'},
        ],
        bad: <dynamic>[
          <String, dynamic>{'type': 'telepathy'},
        ]);
    narrows('element required property', <String, dynamic>{'type': 'linear'},
        'children',
        good: <dynamic>[
          <String, dynamic>{'type': 'icon', 'icon': 'home'},
        ],
        bad: <dynamic>[
          <String, dynamic>{'type': 'icon'},
        ]);
    narrows('nested element colour', <String, dynamic>{'type': 'linear'},
        'children',
        good: <dynamic>[
          <String, dynamic>{
            'type': 'wrap',
            'children': <dynamic>[
              <String, dynamic>{'type': 'box', 'color': '#fff'},
            ],
          },
        ],
        bad: <dynamic>[
          <String, dynamic>{
            'type': 'wrap',
            'children': <dynamic>[
              <String, dynamic>{'type': 'box', 'color': 'tomato'},
            ],
          },
        ]);
  });

  group('a free string is no longer a mode — enum slots', () {
    for (final c in const <List<String>>[
      // widget, property, accepted, invented
      ['banner', 'severity', 'warning', 'catastrophic'],
      ['button', 'style', 'outlined', 'chunky'],
      ['calendar', 'view', 'week', 'fortnight'],
      ['carousel', 'scrollDirection', 'vertical', 'sideways'],
      ['carousel', 'transition', 'fade', 'dissolve'],
      ['carousel', 'indicatorPosition', 'top', 'left'],
      ['codeEditor', 'language', 'dart', 'cobol'],
      ['codeEditor', 'theme', 'monokai', 'sunset'],
      ['colorPicker', 'pickerType', 'palette', 'rainbow'],
      ['dateField', 'mode', 'input', 'telepathy'],
      ['decoration', 'shape', 'circle', 'blob'],
      ['fittedBox', 'fit', 'cover', 'squish'],
      ['flow', 'alignment', 'center', 'middleish'],
      ['form', 'showErrorsOn', 'blur', 'never'],
      ['icon', 'sizeToken', 'lg', 'huge'],
      ['image', 'fit', 'cover', 'squish'],
      ['kenBurnsImage', 'fit', 'fitWidth', 'squish'],
      ['linear', 'mainAxisSize', 'min', 'medium'],
      ['linear', 'alignment', 'center', 'middleish'],
    ]) {
      final base = <String, dynamic>{'type': c[0]};
      if (c[0] == 'banner') base['message'] = 'x';
      if (c[0] == 'flow' || c[0] == 'linear' || c[0] == 'form') {
        base['children'] = <dynamic>[];
      }
      if (c[0] == 'kenBurnsImage') base['src'] = 'assets/a.png';
      if (c[0] == 'icon') base['icon'] = 'home';
      narrows('enum', base, c[1], good: c[2], bad: c[3]);
    }

    narrows('enum', <String, dynamic>{'type': 'chart', 'data': <dynamic>[]},
        'chartType',
        good: 'bar', bad: 'pictogram');
    narrows('enum', <String, dynamic>{'type': 'graph', 'data': <dynamic>[]},
        'chartType',
        good: 'area', bad: 'pictogram');
    narrows('enum', <String, dynamic>{'type': 'imageFilter'}, 'filter',
        good: 'sepia', bad: 'vintage');

    test('enum — a binding still chooses the value', () {
      final r = validateMcpUiDslWidget(<String, dynamic>{
        'type': 'image',
        'fit': "{{wide ? 'cover' : 'contain'}}",
      });
      expect(r.isValid, isTrue, reason: r.errors.take(2).join('\n'));
    });
  });

  group('a required property added by the cut stays required', () {
    test('graph without data is rejected', () {
      expect(validateMcpUiDslWidget(<String, dynamic>{'type': 'graph'}).isValid,
          isFalse);
    });
    test('graph with data is accepted', () {
      final r = validateMcpUiDslWidget(<String, dynamic>{
        'type': 'graph',
        'data': <dynamic>[
          <String, dynamic>{'x': 0, 'y': 1},
        ],
      });
      expect(r.isValid, isTrue, reason: r.errors.take(2).join('\n'));
    });
  });
}
