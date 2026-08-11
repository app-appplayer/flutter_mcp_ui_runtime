// Design tokens resolved against the active form factor.
//
// 9% covered: the constants were read, and every `.of(context)` — the part
// that makes a phone, a desktop and an industrial panel look different — was
// not. A token set that stops scaling produces a screen that is merely wrong
// in proportion, which no assertion elsewhere in this package would catch, and
// which on embedded chrome means a target too small for a gloved hand.

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/form_factor/app_tokens.dart';
import 'package:flutter_mcp_ui_runtime/src/form_factor/form_factor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Resolves [read] under a pinned form factor.
  Future<T> under<T>(
    WidgetTester tester,
    FormFactor formFactor,
    T Function(BuildContext context) read,
  ) async {
    late T value;
    await tester.pumpWidget(MaterialApp(
      home: FormFactorScope(
        formFactor: formFactor,
        child: Builder(builder: (context) {
          value = read(context);
          return const SizedBox();
        }),
      ),
    ));
    return value;
  }

  group('FormFactor', () {
    testWidgets('an injected scope wins over the window width',
        (tester) async {
      // Embedded chrome is never inferred from width — a vehicle panel can be
      // any size, and guessing would give it phone spacing.
      final resolved = await under(
          tester, FormFactor.embedded, (context) => FormFactor.of(context));
      expect(resolved, FormFactor.embedded);
    });

    testWidgets('with no scope it comes from the width', (tester) async {
      late FormFactor resolved;
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(400, 800)),
          child: Builder(builder: (context) {
            resolved = FormFactor.of(context);
            return const SizedBox();
          }),
        ),
      ));
      expect(resolved, FormFactor.compact);
    });

    test('the width bands are contiguous and ordered', () {
      expect(FormFactor.fromWidth(599), FormFactor.compact);
      expect(FormFactor.fromWidth(600), FormFactor.medium);
      expect(FormFactor.fromWidth(839), FormFactor.medium);
      expect(FormFactor.fromWidth(840), FormFactor.expanded);
      expect(FormFactor.fromWidth(1199), FormFactor.expanded);
      expect(FormFactor.fromWidth(1200), FormFactor.large);
      expect(FormFactor.fromWidth(1600), FormFactor.extraLarge,
          reason: 'a gap or an overlap between bands would make a window at '
              'the boundary flicker between two layouts as it is resized');
    });

    test('the two grouping questions split the set exactly once', () {
      for (final factor in FormFactor.values) {
        if (factor == FormFactor.embedded) continue;
        expect(factor.isCompactOrMedium == factor.isExpandedOrLarger, isFalse,
            reason: '$factor must answer exactly one of the two');
      }
    });
  });

  group('AppSpacing', () {
    testWidgets('desktop keeps the baseline scale', (tester) async {
      for (final factor in [
        FormFactor.compact,
        FormFactor.medium,
        FormFactor.expanded,
        FormFactor.large,
        FormFactor.extraLarge,
      ]) {
        final scale =
            await under(tester, factor, (context) => AppSpacing.of(context));
        expect(scale.base, AppSpacing.base,
            reason: 'content breathes through layout on a big screen, not '
                'through inflated gaps — $factor must not drift');
        expect(scale.xxs, AppSpacing.xxs);
        expect(scale.xxl, AppSpacing.xxl);
      }
    });

    testWidgets('embedded enlarges every step', (tester) async {
      final scale = await under(
          tester, FormFactor.embedded, (context) => AppSpacing.of(context));

      expect(scale.base, greaterThan(AppSpacing.base));
      expect(scale.sm, greaterThan(AppSpacing.sm));
      expect(scale.xxl, greaterThan(AppSpacing.xxl),
          reason: 'an industrial panel is read at arm\'s length through a '
              'glove; the whole scale moves, not one token');
    });

    test('the static baseline is an 8-point grid', () {
      expect([AppSpacing.sm, AppSpacing.base, AppSpacing.lg, AppSpacing.xl],
          [8, 16, 24, 32]);
      expect(AppSpacing.screenPadding, const EdgeInsets.all(AppSpacing.base));
      expect(AppSpacing.cardPadding, const EdgeInsets.all(AppSpacing.md));
    });

    testWidgets('the gap helpers size in one axis only', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Column(children: [AppSpacing.vGap(24), AppSpacing.hGap(24)]),
      ));

      final boxes = tester.widgetList<SizedBox>(find.byType(SizedBox)).toList();
      expect(boxes[0].height, 24);
      expect(boxes[0].width, isNull,
          reason: 'a vertical gap that also claims width would break a Row it '
              'is dropped into');
      expect(boxes[1].width, 24);
      expect(boxes[1].height, isNull);
    });
  });

  group('AppIconSizes', () {
    testWidgets('each class gets its own scale, in the documented direction',
        (tester) async {
      final compact = await under(
          tester, FormFactor.compact, (c) => AppIconSizes.of(c));
      final medium =
          await under(tester, FormFactor.medium, (c) => AppIconSizes.of(c));
      final desktop =
          await under(tester, FormFactor.expanded, (c) => AppIconSizes.of(c));
      final embedded =
          await under(tester, FormFactor.embedded, (c) => AppIconSizes.of(c));

      expect(compact.md, AppIconSizes.md);
      expect(medium.md, lessThan(compact.md));
      expect(desktop.md, lessThan(medium.md),
          reason: 'desktop chrome tightens — an icon scaled UP with the '
              'window is the classic "everything is huge" desktop port');
      expect(embedded.md, greaterThan(compact.md));
    });

    testWidgets('large and extraLarge share the desktop scale',
        (tester) async {
      final large =
          await under(tester, FormFactor.large, (c) => AppIconSizes.of(c));
      final extraLarge = await under(
          tester, FormFactor.extraLarge, (c) => AppIconSizes.of(c));
      expect(large.md, extraLarge.md);
      expect(large.xl, extraLarge.xl);
    });

    test('the static baseline is ordered', () {
      expect(
        [AppIconSizes.sm, AppIconSizes.md, AppIconSizes.lg, AppIconSizes.xl],
        [16, 24, 32, 48],
      );
    });
  });

  group('AppTypography', () {
    testWidgets('compact reads the host theme unchanged', (tester) async {
      late AppTypographyScale scale;
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(
          textTheme: const TextTheme(bodyMedium: TextStyle(fontSize: 20)),
        ),
        home: FormFactorScope(
          formFactor: FormFactor.compact,
          child: Builder(builder: (context) {
            scale = AppTypography.of(context);
            return const SizedBox();
          }),
        ),
      ));

      expect(scale.scale, 1.0);
      expect(scale.textTheme.bodyMedium?.fontSize, 20,
          reason: 'a host that set its own type must see it back untouched on '
              'the class it designed for');
    });

    testWidgets('desktop tightens and embedded enlarges', (tester) async {
      Future<AppTypographyScale> scaleFor(FormFactor factor) async {
        late AppTypographyScale scale;
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(
            textTheme: const TextTheme(bodyMedium: TextStyle(fontSize: 20)),
          ),
          home: FormFactorScope(
            formFactor: factor,
            child: Builder(builder: (context) {
              scale = AppTypography.of(context);
              return const SizedBox();
            }),
          ),
        ));
        return scale;
      }

      final desktop = await scaleFor(FormFactor.expanded);
      final embedded = await scaleFor(FormFactor.embedded);

      expect(desktop.scale, lessThan(1.0));
      expect(desktop.textTheme.bodyMedium!.fontSize!, lessThan(20));
      expect(embedded.scale, greaterThan(1.0));
      expect(embedded.textTheme.bodyMedium!.fontSize!, greaterThan(20),
          reason: 'the scale factor and the resolved theme have to agree — a '
              'factor nobody applied is a number in a report');
    });
  });

  group('AppDensity', () {
    testWidgets('touch classes keep the standard density', (tester) async {
      for (final factor in [
        FormFactor.compact,
        FormFactor.medium,
        FormFactor.embedded,
      ]) {
        final density =
            await under(tester, factor, (c) => AppDensity.of(c));
        expect(density.visualDensity, VisualDensity.standard,
            reason: '$factor is a finger or a glove — packing controls '
                'tighter drops below the minimum hit target');
        expect(density.scrollbarAlwaysVisible, isFalse,
            reason: 'a touch surface has no hover, so a permanent scrollbar '
                'is chrome nobody needs');
      }
    });

    testWidgets('desktop classes pack tighter and keep the scrollbar visible',
        (tester) async {
      for (final factor in [
        FormFactor.expanded,
        FormFactor.large,
        FormFactor.extraLarge,
      ]) {
        final density = await under(tester, factor, (c) => AppDensity.of(c));
        expect(density.visualDensity.horizontal, lessThan(0));
        expect(density.visualDensity.vertical, lessThan(0));
        expect(density.scrollbarAlwaysVisible, isTrue,
            reason: 'a pointer has no way to discover a scrollbar that fades');
      }
    });
  });
}
