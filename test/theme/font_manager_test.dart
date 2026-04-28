import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/font_manager.dart';

void main() {
  late FontManager fontManager;

  setUp(() {
    fontManager = FontManager();
    fontManager.clear();
  });

  // ===========================================================================
  // TC-015: FontManager — loadFonts
  // ===========================================================================
  group('TC-015: FontManager — loadFonts', () {
    test('font state transitions to loaded after loadFonts', () async {
      const fonts = [
        FontConfig(family: 'TestFont', source: 'assets/test.ttf'),
      ];
      await fontManager.loadFonts(fonts);
      expect(fontManager.getFontState('TestFont'), FontState.loaded);
    });

    test('multiple font families loaded independently', () async {
      const fonts = [
        FontConfig(family: 'FontA'),
        FontConfig(family: 'FontB'),
      ];
      await fontManager.loadFonts(fonts);
      expect(fontManager.getFontState('FontA'), FontState.loaded);
      expect(fontManager.getFontState('FontB'), FontState.loaded);
    });

    test('empty font list is a no-op', () async {
      await fontManager.loadFonts([]);
      // Should not throw
    });

    test('font with single source entry loads that source', () async {
      const fonts = [
        FontConfig(family: 'SingleSource', source: 'fonts/single.ttf'),
      ];
      await fontManager.loadFonts(fonts);
      expect(fontManager.getFontState('SingleSource'), FontState.loaded);
    });

    test('already loaded font is skipped on second loadFonts call', () async {
      const fonts = [FontConfig(family: 'Dup')];
      await fontManager.loadFonts(fonts);
      // Call again - should not fail or change state
      await fontManager.loadFonts(fonts);
      expect(fontManager.getFontState('Dup'), FontState.loaded);
    });
  });

  // ===========================================================================
  // TC-016: FontManager — getFontState
  // ===========================================================================
  group('TC-016: FontManager — getFontState', () {
    test('returns loaded after successful load', () async {
      await fontManager.loadFonts([const FontConfig(family: 'Loaded')]);
      expect(fontManager.getFontState('Loaded'), FontState.loaded);
    });

    test('unknown family returns notFound', () {
      expect(fontManager.getFontState('UnknownFont'), FontState.notFound);
    });

    test('system font always returns loaded', () {
      expect(fontManager.getFontState('Roboto'), FontState.loaded);
      expect(fontManager.getFontState('Arial'), FontState.loaded);
      expect(fontManager.getFontState('sans-serif'), FontState.loaded);
    });
  });

  // ===========================================================================
  // TC-017: FontManager — isFontAvailable
  // ===========================================================================
  group('TC-017: FontManager — isFontAvailable', () {
    test('returns true for loaded custom font', () async {
      await fontManager.loadFonts([const FontConfig(family: 'CustomLoaded')]);
      expect(fontManager.isFontAvailable('CustomLoaded'), isTrue);
    });

    test('returns true for recognized system font', () {
      expect(fontManager.isFontAvailable('Roboto'), isTrue);
      expect(fontManager.isFontAvailable('Helvetica'), isTrue);
      expect(fontManager.isFontAvailable('monospace'), isTrue);
    });

    test('returns false for unknown font family', () {
      expect(fontManager.isFontAvailable('NonExistentFont'), isFalse);
    });

    test('returns false for font in error state', () {
      fontManager.markError('FailedFont');
      expect(fontManager.isFontAvailable('FailedFont'), isFalse);
    });
  });

  // ===========================================================================
  // TC-018: FontManager — resolveFallbackChain
  // ===========================================================================
  group('TC-018: FontManager — resolveFallbackChain', () {
    test('returns first available font in chain', () async {
      fontManager.markLoaded('CustomFont');
      final result =
          fontManager.resolveFallbackChain(['CustomFont', 'Roboto', 'serif']);
      expect(result, 'CustomFont');
    });

    test('if first font failed, returns second available', () {
      fontManager.markError('CustomFont');
      final result =
          fontManager.resolveFallbackChain(['CustomFont', 'Roboto', 'serif']);
      expect(result, 'Roboto');
    });

    test('only generic family available returns generic family', () {
      final result = fontManager
          .resolveFallbackChain(['Unknown1', 'Unknown2', 'sans-serif']);
      expect(result, 'sans-serif');
    });

    test('empty list returns null', () {
      final result = fontManager.resolveFallbackChain([]);
      expect(result, isNull);
    });

    test('all specific fonts unavailable falls through to generic family', () {
      final result = fontManager
          .resolveFallbackChain(['NonExist1', 'NonExist2', 'monospace']);
      expect(result, 'monospace');
    });

    test('all fonts unavailable returns null', () {
      final result =
          fontManager.resolveFallbackChain(['NonExist1', 'NonExist2']);
      expect(result, isNull);
    });
  });

  // ===========================================================================
  // TC-037: FontManager — markLoaded
  // ===========================================================================
  group('TC-037: FontManager — markLoaded', () {
    test('marks font as loaded without actual loading', () {
      fontManager.markLoaded('PreBundled');
      expect(fontManager.isFontAvailable('PreBundled'), isTrue);
      expect(fontManager.getFontState('PreBundled'), FontState.loaded);
    });

    test('mark already-loaded font is a no-op (still loaded)', () {
      fontManager.markLoaded('AlreadyLoaded');
      fontManager.markLoaded('AlreadyLoaded');
      expect(fontManager.getFontState('AlreadyLoaded'), FontState.loaded);
    });
  });
}
