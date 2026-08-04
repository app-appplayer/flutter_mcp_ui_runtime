// `ViewMode` and its resolver had no test at all — 0 of 27 lines. It decides
// which layout a document gets, and its whole job is a priority chain, which
// is the kind of thing that looks right and picks the wrong source.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/form_factor/view_mode.dart';
import 'package:flutter_mcp_ui_runtime/src/form_factor/form_factor.dart';

void main() {
  group('ViewMode.parse — persisted pins', () {
    test('every canonical spelling round-trips through value', () {
      for (final mode in ViewMode.values) {
        expect(ViewMode.parse(mode.value), mode,
            reason: '${mode.value} is what gets written to AppConfig');
      }
    });

    test('the hyphenated spelling is accepted for extraLarge', () {
      expect(ViewMode.parse('extra-large'), ViewMode.extraLarge);
    });

    test('unknown, empty and non-string collapse to auto', () {
      expect(ViewMode.parse('gigantic'), ViewMode.auto);
      expect(ViewMode.parse(''), ViewMode.auto);
      expect(ViewMode.parse(null), ViewMode.auto);
      expect(ViewMode.parse(3), ViewMode.auto);
      expect(ViewMode.parse(<String>['compact']), ViewMode.auto);
    });
  });

  group('ViewMode.toFormFactor', () {
    test('auto declines to answer so the chain can continue', () {
      expect(ViewMode.auto.toFormFactor(), isNull);
    });

    test('every concrete pin maps to its form factor', () {
      expect(ViewMode.compact.toFormFactor(), FormFactor.compact);
      expect(ViewMode.medium.toFormFactor(), FormFactor.medium);
      expect(ViewMode.expanded.toFormFactor(), FormFactor.expanded);
      expect(ViewMode.large.toFormFactor(), FormFactor.large);
      expect(ViewMode.extraLarge.toFormFactor(), FormFactor.extraLarge);
    });
  });

  group('ViewModeResolver — the priority chain', () {
    const wide = 2000.0; // would auto-resolve well above compact

    test('a per-app pin wins over everything', () {
      expect(
        ViewModeResolver.resolve(
          perApp: ViewMode.compact,
          global: ViewMode.large,
          dslHint: ViewMode.expanded,
          windowWidth: wide,
        ),
        FormFactor.compact,
      );
    });

    test('a global pin wins when the app defers', () {
      expect(
        ViewModeResolver.resolve(
          perApp: ViewMode.auto,
          global: ViewMode.medium,
          dslHint: ViewMode.expanded,
          windowWidth: wide,
        ),
        FormFactor.medium,
      );
    });

    test('the DSL hint is consulted only when both pins defer', () {
      expect(
        ViewModeResolver.resolve(
          perApp: ViewMode.auto,
          global: ViewMode.auto,
          dslHint: ViewMode.expanded,
          windowWidth: wide,
        ),
        FormFactor.expanded,
      );
    });

    test('with nothing pinned the window decides', () {
      expect(
        ViewModeResolver.resolve(windowWidth: 400),
        FormFactor.fromWidth(400),
      );
      expect(
        ViewModeResolver.resolve(
          perApp: ViewMode.auto,
          global: ViewMode.auto,
          dslHint: ViewMode.auto,
          windowWidth: wide,
        ),
        FormFactor.fromWidth(wide),
      );
    });

    test('nulls are skipped the same way auto is', () {
      expect(
        ViewModeResolver.resolve(
          perApp: null,
          global: null,
          dslHint: ViewMode.large,
          windowWidth: 300,
        ),
        FormFactor.large,
      );
    });
  });
}
