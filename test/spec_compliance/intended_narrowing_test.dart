// The 1.4 cut was a minor because it *narrows*: `AssetRef` / `IconRef` /
// `Color` replaced slots that used to take any string. Restoring
// backward compatibility for the forms that cut broke by accident must not
// also restore the ones it broke on purpose — otherwise the minor bought
// nothing and the next document to write `color: "tomato"` gets an uncoloured
// box with no diagnostic again.
//
// Each case here is a document the registry is *supposed* to reject.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_core/flutter_mcp_ui_core.dart';

void main() {
  void rejects(String why, Map<String, dynamic> doc) {
    test(why, () {
      final r = validateMcpUiDslWidget(doc);
      expect(r.isValid, isFalse, reason: 'should have been rejected: $doc');
    });
  }

  void accepts(String why, Map<String, dynamic> doc) {
    test(why, () {
      final r = validateMcpUiDslWidget(doc);
      expect(r.isValid, isTrue,
          reason: 'should have been accepted: $doc\n${r.errors.take(2).join('\n')}');
    });
  }

  group('Color stays narrowed (§5.3.4)', () {
    rejects('a CSS keyword outside the ten basic names',
        <String, dynamic>{'type': 'box', 'color': 'tomato'});
    rejects('a scheme slot that does not exist',
        <String, dynamic>{'type': 'box', 'color': 'textOnSurface'});
    rejects('a dimension string in a colour slot',
        <String, dynamic>{'type': 'box', 'color': '16px'});
    accepts('hex, slot and the ten names still pass',
        <String, dynamic>{'type': 'box', 'color': '#fff'});
    accepts('a binding still passes',
        <String, dynamic>{'type': 'box', 'color': '{{theme.color.primary}}'});
  });

  group('IconRef stays narrowed (§2.5)', () {
    rejects('a number is not an icon',
        <String, dynamic>{'type': 'icon', 'icon': 42});
    accepts('the name form',
        <String, dynamic>{'type': 'icon', 'icon': 'home'});
    accepts('the codepoint object form', <String, dynamic>{
      'type': 'icon',
      'icon': <String, dynamic>{'codepoint': 0xe88a},
    });
  });

  group('enum values stay checked', () {
    rejects('an undeclared variant literal',
        <String, dynamic>{'type': 'button', 'label': 'x', 'variant': 'gigantic'});
    accepts('a declared variant',
        <String, dynamic>{'type': 'button', 'label': 'x', 'variant': 'filled'});
    accepts('a binding choosing the variant', <String, dynamic>{
      'type': 'button',
      'label': 'x',
      'variant': "{{sel ? 'filled' : 'outlined'}}",
    });
  });

  group('structure stays checked', () {
    rejects('children must be a list, not a string',
        <String, dynamic>{'type': 'linear', 'children': 'nope'});
    rejects('a required property still cannot be omitted',
        <String, dynamic>{'type': 'richText'});
    rejects('an unknown widget type is still not a widget',
        <String, dynamic>{'type': 'telepathy'});
  });

  group('what the cut broke by accident is accepted again', () {
    accepts('a list of actions in one slot', <String, dynamic>{
      'type': 'button',
      'label': 'x',
      'click': <dynamic>[
        <String, dynamic>{'type': 'state', 'action': 'set', 'binding': 'a', 'value': 1},
        <String, dynamic>{'type': 'tool', 'tool': 't'},
      ],
    });
    accepts('the single-edge border shorthand', <String, dynamic>{
      'type': 'box',
      'decoration': <String, dynamic>{
        'border': <String, dynamic>{'bottom': true, 'color': '#fff', 'width': 1},
      },
    });
    accepts('the CSS numeric font weight', <String, dynamic>{
      'type': 'text',
      'content': 'x',
      'style': <String, dynamic>{'fontWeight': '700'},
    });
  });
}
