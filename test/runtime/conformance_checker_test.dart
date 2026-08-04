// `ConformanceChecker` reports which DSL profile a runtime can serve, and had
// 0 of 63 lines covered. A host that under-reports refuses documents it could
// draw; one that over-reports accepts documents it cannot.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/conformance_checker.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/widgets/widget_factory.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';

class _StubFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) =>
      const SizedBox.shrink();
}

WidgetRegistry _registryWith(List<String> types) {
  final registry = WidgetRegistry();
  for (final t in types) {
    registry.register(t, _StubFactory());
  }
  return registry;
}

void main() {
  test('an empty registry supports no level, and still reports core', () {
    final checker = ConformanceChecker(_registryWith(const []));

    expect(checker.supportsLevel(ConformanceLevel.core), isFalse);
    expect(checker.supportsLevel(ConformanceLevel.standard), isFalse);
    expect(checker.supportsLevel(ConformanceLevel.advanced), isFalse);
    // Documented behaviour: below core there is no lower level to name.
    expect(checker.getConformanceLevel(), ConformanceLevel.core);
    expect(checker.getMissingWidgets(ConformanceLevel.core),
        ConformanceChecker.coreWidgets);
  });

  test('core widgets alone report core and list what standard still needs',
      () {
    final checker =
        ConformanceChecker(_registryWith(ConformanceChecker.coreWidgets));

    expect(checker.supportsLevel(ConformanceLevel.core), isTrue);
    expect(checker.supportsLevel(ConformanceLevel.standard), isFalse);
    expect(checker.getConformanceLevel(), ConformanceLevel.core);
    expect(checker.getMissingWidgets(ConformanceLevel.core), isEmpty);

    final missing = checker.getMissingWidgets(ConformanceLevel.standard);
    expect(missing, isNotEmpty);
    expect(missing.any(ConformanceChecker.coreWidgets.contains), isFalse,
        reason: 'a widget that is present must never be listed as missing');
  });

  test('standard widgets report standard, not advanced', () {
    final checker =
        ConformanceChecker(_registryWith(ConformanceChecker.standardWidgets));

    expect(checker.supportsLevel(ConformanceLevel.standard), isTrue);
    expect(checker.supportsLevel(ConformanceLevel.advanced), isFalse);
    expect(checker.getConformanceLevel(), ConformanceLevel.standard);
  });

  test('the full advanced set reports advanced', () {
    final checker =
        ConformanceChecker(_registryWith(ConformanceChecker.advancedWidgets));

    expect(checker.getConformanceLevel(), ConformanceLevel.advanced);
    expect(checker.getMissingWidgets(ConformanceLevel.advanced), isEmpty);
  });

  test('one missing core widget drops the level', () {
    final all = List<String>.from(ConformanceChecker.advancedWidgets)
      ..remove(ConformanceChecker.coreWidgets.first);
    final checker = ConformanceChecker(_registryWith(all));

    expect(checker.supportsLevel(ConformanceLevel.core), isFalse,
        reason: 'core is a floor, not a majority vote');
    expect(checker.getMissingWidgets(ConformanceLevel.core),
        <String>[ConformanceChecker.coreWidgets.first]);
  });

  group('getConformanceReport', () {
    test('counts each tier by its own additions, not cumulatively', () {
      final checker =
          ConformanceChecker(_registryWith(ConformanceChecker.coreWidgets));
      final report = checker.getConformanceReport();

      expect(report['conformanceLevel'], 'core');
      expect((report['core'] as Map)['percentage'], 100);
      expect((report['standard'] as Map)['percentage'], 0,
          reason: 'standard is reported on its own additions; counting core '
              'again would show partial support for a tier with nothing in it');
      expect((report['advanced'] as Map)['percentage'], 0);
    });

    test('a full registry reports 100 at every tier', () {
      final checker =
          ConformanceChecker(_registryWith(ConformanceChecker.advancedWidgets));
      final report = checker.getConformanceReport();

      expect(report['conformanceLevel'], 'advanced');
      for (final tier in const ['core', 'standard', 'advanced']) {
        expect((report[tier] as Map)['percentage'], 100, reason: tier);
        expect((report[tier] as Map)['missing'], isEmpty, reason: tier);
      }
    });
  });
}
