// `07_Security.md §7.2.1` — what the runtime does with a `validation` block.
//
// The section is normative and says runtimes "MUST support **both shapes**":
// Shape A, the constraint object (`{kind, sanitize, maxLength, pattern,
// message}`), and Shape B, the rule array (`[{rule, value, message}]`).
//
// This file measures both against the engine that `textInput` actually uses,
// through the documented spelling only. Nothing here asserts a spelling the
// spec does not publish.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_core/flutter_mcp_ui_core.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

void main() {
  group('§7.2.1 Shape B — rule array', () {
    test('a required rule, spelled as the spec spells it, is parsed', () {
      final rules = ValidationEngine.parseValidation(<Object>[
        <String, dynamic>{'rule': 'required', 'message': 'Name is required'},
      ]);
      expect(rules, isNotEmpty,
          reason: 'a document written to §7.2.1 must produce a rule');
    });

    test('every rule the section publishes is parsed', () {
      for (final rule in <String>[
        'required',
        'minLength',
        'maxLength',
        'min',
        'max',
        'pattern',
        'email',
        'url',
        'phone',
        'number',
        'integer',
        'date',
      ]) {
        final rules = ValidationEngine.parseValidation(<Object>[
          <String, dynamic>{'rule': rule, 'value': 2, 'message': 'nope'},
        ]);
        expect(rules, isNotEmpty, reason: 'rule `$rule` produced nothing');
      }
    });
  });

  group('§7.2.1 Shape A — constraint object', () {
    test('a constraint object is parsed', () {
      final rules = ValidationEngine.parseValidation(<String, dynamic>{
        'kind': 'email',
        'maxLength': 255,
        'message': 'Enter a valid email',
      });
      expect(rules, isNotEmpty,
          reason: 'the section requires both shapes, not just the array');
    });

    test('each declared constraint rejects, and a good value passes', () {
      final rules = ValidationEngine.parseValidation(<String, dynamic>{
        'kind': 'email',
        'maxLength': 12,
        'message': 'nope',
      });
      expect(ValidationEngine.validate('not-an-email', rules).isValid, isFalse);
      expect(ValidationEngine.validate('someone@example.com', rules).isValid,
          isFalse,
          reason: 'maxLength 12 must still apply alongside kind');
      expect(ValidationEngine.validate('a@b.co', rules).isValid, isTrue);
    });
  });

  // Parsing a rule is not applying it. Asserting only on the rule list would
  // pass for a rule type the validator has no case for — which is exactly how
  // four published rules sat unimplemented behind a parser that never saw
  // them.
  group('the published rules actually reject', () {
    void check(String rule, {Object? param, required Object bad, required Object good}) {
      final rules = ValidationEngine.parseValidation(<Object>[
        <String, dynamic>{
          'rule': rule,
          if (param != null) 'value': param,
          'message': 'nope',
        },
      ]);
      expect(ValidationEngine.validate(bad, rules).isValid, isFalse,
          reason: '`$rule` accepted $bad');
      expect(ValidationEngine.validate(good, rules).isValid, isTrue,
          reason: '`$rule` rejected $good');
    }

    test('phone', () => check('phone', bad: 'not a phone', good: '+82 10-1234-5678'));
    test('number', () => check('number', bad: 'twelve', good: '12.5'));
    test('integer', () => check('integer', bad: '12.5', good: '12'));
    test('date', () => check('date', bad: 'someday', good: '2026-08-05'));
    test('email', () => check('email', bad: 'nope', good: 'a@b.co'));
    test('minLength', () => check('minLength', param: 3, bad: 'ab', good: 'abc'));
  });

  group('the shipped spelling keeps working', () {
    test('`type` is still read, so documents that validate today still do', () {
      final rules = ValidationEngine.parseValidation(<Object>[
        <String, dynamic>{'type': 'required', 'message': 'nope'},
      ]);
      expect(rules, hasLength(1));
      expect(ValidationEngine.validate('', rules).isValid, isFalse);
    });
  });

  // The registry half of this work is PARKED, not landed.
  //
  // `textInput.validation` emits unconstrained because `ValidationConfig` is
  // referenced and undefined. Defining it constrains a slot that accepted
  // anything — and a runtime validates documents at load, so every published
  // bundle carrying a `validation` block the definition did not admit would
  // stop opening. That is a bundle break, which is not allowed.
  //
  // So the fix above is runtime-only: documents that already declare
  // constraints start having them applied, and nothing that opened yesterday
  // stops opening. The definition is kept at
  // `configs/widget/_ValidationConfig.yaml` for a release allowed to break.
  group('the registry is deliberately unchanged', () {
    Map<String, dynamic> field(Object validation) => <String, dynamic>{
          'type': 'textInput',
          'label': 'x',
          'validation': validation,
        };

    test('the published spelling validates', () {
      final r = validateMcpUiDslWidget(field(<Object>[
        <String, dynamic>{'rule': 'required', 'message': 'Name is required'},
      ]));
      expect(r.isValid, isTrue, reason: r.errors.take(2).join('\n'));
    });

    // The one that matters: a bundle authored against the shipped engine.
    // If this ever goes red, a schema change has broken existing bundles.
    test('the legacy `type` spelling still opens', () {
      final r = validateMcpUiDslWidget(field(<Object>[
        <String, dynamic>{'type': 'required', 'message': 'nope'},
      ]));
      expect(r.isValid, isTrue,
          reason: 'narrowing this slot stops published bundles from loading');
    });

    test('Shape A still opens', () {
      final r = validateMcpUiDslWidget(field(<String, dynamic>{
        'kind': 'email',
        'maxLength': 255,
      }));
      expect(r.isValid, isTrue, reason: r.errors.take(2).join('\n'));
    });
  });
  // Shape A names the constraint by `kind`. Each kind produces its own rule;
  // a kind that falls through produces none, so a field the document declared
  // as an email address accepts anything, and nothing says so.
  group('§7.2.1 Shape A — every declared kind', () {
    test('each published kind produces a rule that refuses bad input', () {
      const cases = <String, String>{
        'email': 'not-an-email',
        'url': 'not a url',
        'phone': 'abc',
        'number': 'twelve',
        'date': 'someday',
      };

      cases.forEach((kind, bad) {
        final rules = ValidationEngine.parseValidation(<String, dynamic>{
          'kind': kind,
        });
        expect(rules, isNotEmpty, reason: '$kind produced no rule at all');

        final verdict = ValidationEngine.validate(bad, rules);
        expect(verdict.isValid, isFalse,
            reason: 'a field declared as $kind that accepts "$bad" is a '
                'validation the document asked for and did not get');
      });
    });

    test('`text` and an absent kind carry no constraint of their own', () {
      for (final validation in <Map<String, dynamic>>[
        <String, dynamic>{'kind': 'text'},
        <String, dynamic>{'sanitize': true},
      ]) {
        final rules = ValidationEngine.parseValidation(validation);
        expect(ValidationEngine.validate('anything', rules).isValid, isTrue,
            reason: 'sanitize is a normalisation hint, not a rejection rule');
      }
    });

    test('a kind nobody published applies no constraint rather than guessing',
        () {
      final rules = ValidationEngine.parseValidation(<String, dynamic>{
        'kind': 'iban',
      });

      expect(ValidationEngine.validate('anything', rules).isValid, isTrue,
          reason: 'inventing a constraint for an unknown kind would refuse '
              'input the document never restricted');
    });

    test('maxLength and pattern come from the same block', () {
      final rules = ValidationEngine.parseValidation(<String, dynamic>{
        'kind': 'text',
        'maxLength': 3,
        'pattern': r'^[a-z]+$',
        'message': 'Three lower-case letters',
      });

      expect(ValidationEngine.validate('abcd', rules).isValid, isFalse);
      expect(ValidationEngine.validate('AB', rules).isValid, isFalse);
      expect(ValidationEngine.validate('abc', rules).isValid, isTrue);
    });
  });

  group('the integer rule', () {
    test('a whole number passes and a fractional one does not', () {
      final rules = ValidationEngine.parseValidation(<Object>[
        <String, dynamic>{'rule': 'integer', 'message': 'Whole numbers only'},
      ]);

      expect(ValidationEngine.validate(4, rules).isValid, isTrue);
      expect(ValidationEngine.validate(4.5, rules).isValid, isFalse,
          reason: 'a quantity field that accepts 4.5 lets an order through '
              'that the warehouse cannot pick');
      expect(ValidationEngine.validate('4', rules).isValid, isTrue);
      expect(ValidationEngine.validate('4.5', rules).isValid, isFalse);
    });
  });
}
