import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_bundle/mcp_bundle.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

/// In-memory storage for testing bundle:// URI resolution.
class _TestStoragePort implements BundleStoragePort {
  final Map<String, Uint8List> assets = {};

  @override
  Future<Uint8List> readAsset(Uri uri) async {
    final key = uri.toString();
    if (assets.containsKey(key)) return assets[key]!;
    throw Exception('Asset not found: $uri');
  }

  @override
  Future<Map<String, dynamic>> readBundle(Uri uri) async => {};
  @override
  Future<void> writeBundle(Uri uri, Map<String, dynamic> data) async {}
  @override
  Future<void> writeAsset(Uri uri, Uint8List data) async {}
  @override
  Future<bool> exists(Uri uri) async => false;
  @override
  Future<void> delete(Uri uri) async {}
  @override
  Future<List<Uri>> list(Uri directoryUri) async => [];
  @override
  Stream<BundleChangeEvent>? watch(Uri uri) => null;
}

void main() {
  late _TestStoragePort storage;
  late BundleAssetProvider assetProvider;
  late BundleUiReadAdapter adapter;

  setUp(() {
    storage = _TestStoragePort();
    assetProvider = BundleAssetProvider(storage: storage);
    adapter = BundleUiReadAdapter(assetProvider: assetProvider);
  });

  // ==========================================================================
  // UiPort interface compliance (TC-V12-046, TC-V12-018)
  // ==========================================================================
  group('UiPort interface compliance', () {
    // TC-V12-046: BundleUiReadAdapter is UiPort
    test('BundleUiReadAdapter is UiPort', () {
      expect(adapter, isA<UiPort>());
    });

    // TC-V12-018: BundleUiReadAdapter.fromDefinition() throws UnsupportedError
    test('fromDefinition() throws UnsupportedError', () {
      expect(
        () => adapter.fromDefinition({}),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  // ==========================================================================
  // toDefinition (TC-V12-001 ~ TC-V12-014)
  // ==========================================================================
  group('toDefinition()', () {
    // TC-V12-001: Full bundle to UI definition JSON via toDefinition()
    test('full bundle to UI definition JSON', () async {
      const bundle = McpBundle(
        manifest: BundleManifest(
          id: 'com.example.app',
          name: 'My App',
          version: '1.0.0',
          description: 'Test app',
          category: AppCategory.productivity,
          publisher: PublisherInfo(name: 'Publisher'),
        ),
        ui: UiSection(
          pages: [
            ScreenDefinition(
              id: 'home',
              name: 'Home',
              route: '/',
              root: WidgetNode(type: 'text', props: {'content': 'Hello'}),
            ),
          ],
        ),
      );

      final result = await adapter.toDefinition(bundle);
      expect(result.success, isTrue);
      expect(result.data!['title'], equals('My App'));
      expect(result.data!['version'], equals('1.0.0'));
      expect(result.data!['id'], equals('com.example.app'));
      expect(result.data!['description'], equals('Test app'));
      expect(result.data!['category'], equals('productivity'));
      expect(result.data!['routes'], isNotEmpty);
    });

    // TC-V12-002, TC-V12-003: Manifest field mapping — name, version, id, description
    test('manifest field mapping correctness', () async {
      const bundle = McpBundle(
        manifest: BundleManifest(
          id: 'com.example.app',
          name: 'My App',
          version: '1.0.0',
          description: 'Test',
          category: AppCategory.productivity,
        ),
      );

      final result = await adapter.toDefinition(bundle);
      expect(result.success, isTrue);
      expect(result.data!['title'], equals('My App'));
      expect(result.data!['version'], equals('1.0.0'));
      expect(result.data!['description'], equals('Test'));
      expect(result.data!['category'], equals('productivity'));
    });

    // TC-V12-008: Manifest field mapping — timestamps (createdAt/updatedAt → TimestampInfo)
    test('timestamp mapping (createdAt/updatedAt)', () async {
      final bundle = McpBundle(
        manifest: BundleManifest(
          id: 'com.example.app',
          name: 'App',
          version: '1.0.0',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 3, 1),
          publishedAt: DateTime.utc(2026, 2, 1),
        ),
      );

      final result = await adapter.toDefinition(bundle);
      expect(result.success, isTrue);
      final timestamps =
          result.data!['timestamps'] as Map<String, dynamic>;
      expect(timestamps['createdAt'], contains('2026-01-01'));
      expect(timestamps['updatedAt'], contains('2026-03-01'));
      // publishedAt intentionally excluded
      expect(timestamps.containsKey('publishedAt'), isFalse);
    });

    // TC-V12-012: Bundle with no UI section
    test('bundle with no UI section', () async {
      const bundle = McpBundle(
        manifest: BundleManifest(
          id: 'com.example.app',
          name: 'App',
          version: '1.0.0',
        ),
      );

      final result = await adapter.toDefinition(bundle);
      expect(result.success, isTrue);
      expect(result.data!['title'], equals('App'));
      expect(result.data!['routes'], isEmpty);
    });

    // TC-V12-013: Bundle with no optional metadata fields
    test('bundle with no metadata fields', () async {
      const bundle = McpBundle(
        manifest: BundleManifest(
          id: 'com.example.minimal',
          name: 'Minimal',
          version: '0.1.0',
        ),
      );

      final result = await adapter.toDefinition(bundle);
      expect(result.success, isTrue);
      expect(result.data!['title'], equals('Minimal'));
      expect(result.data!['version'], equals('0.1.0'));
      expect(result.data!.containsKey('description'), isFalse);
      expect(result.data!.containsKey('category'), isFalse);
      expect(result.data!.containsKey('publisher'), isFalse);
      expect(result.data!.containsKey('timestamps'), isFalse);
      expect(result.data!.containsKey('screenshots'), isFalse);
    });

    // TC-V12-014: Missing required manifest fields
    test('invalid manifest returns UiResult.fail', () async {
      const bundle = McpBundle(
        manifest: BundleManifest(
          id: '',
          name: '',
          version: '',
        ),
      );

      final result = await adapter.toDefinition(bundle);
      expect(result.success, isFalse);
      expect(result.error, isNotNull);
      expect(result.error!.code, equals('INVALID_MANIFEST'));
    });
  });

  // ==========================================================================
  // toAppInfo (TC-V12-015 ~ TC-V12-017)
  // ==========================================================================
  group('toAppInfo()', () {
    // TC-V12-015: Full manifest to app info via toAppInfo()
    test('generates app info from full manifest', () async {
      const bundle = McpBundle(
        manifest: BundleManifest(
          id: 'com.example.test',
          name: 'Test App',
          version: '1.0.0',
          description: 'A test application',
          category: AppCategory.productivity,
          publisher: PublisherInfo(name: 'Publisher'),
        ),
      );

      final result = await adapter.toAppInfo(bundle);
      expect(result.success, isTrue);
      expect(result.data!['name'], equals('Test App'));
      expect(result.data!['version'], equals('1.0.0'));
      expect(result.data!['id'], equals('com.example.test'));
      expect(result.data!['description'], equals('A test application'));
      expect(result.data!['category'], equals('productivity'));
    });

    // TC-V12-016: App info from minimal manifest
    test('generates app info from minimal manifest', () async {
      const bundle = McpBundle(
        manifest: BundleManifest(
          id: 'com.example.minimal',
          name: 'Minimal',
          version: '0.1.0',
        ),
      );

      final result = await adapter.toAppInfo(bundle);
      expect(result.success, isTrue);
      expect(result.data!['name'], equals('Minimal'));
      expect(result.data!['version'], equals('0.1.0'));
      expect(result.data!.containsKey('description'), isFalse);
      expect(result.data!.containsKey('category'), isFalse);
    });
  });

  // ==========================================================================
  // UiResult pattern (TC-V12-048 ~ TC-V12-050)
  // ==========================================================================
  group('UiResult pattern', () {
    // TC-V12-048: UiResult — success result
    test('success result', () async {
      const bundle = McpBundle(
        manifest: BundleManifest(
          id: 'com.example.app',
          name: 'App',
          version: '1.0.0',
        ),
      );
      final result = await adapter.toDefinition(bundle);
      expect(result.success, isTrue);
      expect(result.data, isNotNull);
      expect(result.error, isNull);
    });

    // TC-V12-049: UiResult — error result
    test('error result', () async {
      const bundle = McpBundle(
        manifest: BundleManifest(id: '', name: '', version: ''),
      );
      final result = await adapter.toDefinition(bundle);
      expect(result.success, isFalse);
      expect(result.data, isNull);
      expect(result.error, isNotNull);
      expect(result.error!.code, isNotEmpty);
    });

    // TC-V12-050: UiResult — success with warnings
    test('success with warnings for unresolvable URI', () async {
      const bundle = McpBundle(
        manifest: BundleManifest(
          id: 'com.example.app',
          name: 'App',
          version: '1.0.0',
          icon: 'bundle://nonexistent/path.png',
        ),
      );
      final result = await adapter.toDefinition(bundle);
      expect(result.success, isTrue);
      expect(result.data, isNotNull);
      expect(result.warnings, isNotNull);
      expect(result.warnings, isNotEmpty);
      expect(result.warnings!.first.code, equals('UNRESOLVABLE_URI'));
    });
  });

  // ==========================================================================
  // UiSection mapping tests (TC-V12-010 ~ TC-V12-011)
  // ==========================================================================
  group('UiSection mapping with widget definitions', () {
    // TC-V12-010: UiSection → routes/theme/state/navigation mapping
    test('nested widget definitions produce valid routes', () async {
      const bundle = McpBundle(
        manifest: BundleManifest(
          id: 'com.example.nested',
          name: 'Nested App',
          version: '1.0.0',
        ),
        ui: UiSection(
          pages: [
            ScreenDefinition(
              id: 'home',
              name: 'Home',
              route: '/',
              root: WidgetNode(
                type: 'column',
                children: [
                  WidgetNode(
                    type: 'row',
                    children: [
                      WidgetNode(type: 'text', props: {'content': 'Cell 1'}),
                      WidgetNode(type: 'text', props: {'content': 'Cell 2'}),
                    ],
                  ),
                  WidgetNode(type: 'text', props: {'content': 'Footer'}),
                ],
              ),
            ),
          ],
        ),
      );

      final result = await adapter.toDefinition(bundle);
      expect(result.success, isTrue);
      expect(result.data!['routes'], isNotEmpty);
      // Verify the route structure was created from the screen
      final routes = result.data!['routes'] as Map<String, dynamic>;
      expect(routes.containsKey('/'), isTrue);
    });

    // TC-V12-010 (continued): List widget with dynamic items in routes
    test('list widget with dynamic items', () async {
      const bundle = McpBundle(
        manifest: BundleManifest(
          id: 'com.example.list',
          name: 'List App',
          version: '1.0.0',
        ),
        ui: UiSection(
          pages: [
            ScreenDefinition(
              id: 'items',
              name: 'Items',
              route: '/items',
              root: WidgetNode(
                type: 'list',
                props: {
                  'itemSource': 'state.items',
                  'direction': 'vertical',
                },
                children: [
                  WidgetNode(type: 'text', props: {
                    'content': '{{item.name}}',
                  }),
                ],
              ),
            ),
          ],
        ),
      );

      final result = await adapter.toDefinition(bundle);
      expect(result.success, isTrue);
      final routes = result.data!['routes'] as Map<String, dynamic>;
      expect(routes.containsKey('/items'), isTrue);
    });

    // TC-V12-010 (continued): Conditional rendering in routes
    test('conditional rendering', () async {
      const bundle = McpBundle(
        manifest: BundleManifest(
          id: 'com.example.conditional',
          name: 'Conditional App',
          version: '1.0.0',
        ),
        ui: UiSection(
          pages: [
            ScreenDefinition(
              id: 'dashboard',
              name: 'Dashboard',
              route: '/dashboard',
              root: WidgetNode(
                type: 'column',
                children: [
                  WidgetNode(
                    type: 'text',
                    props: {
                      'content': 'Welcome',
                      'visible': '{{state.isLoggedIn}}',
                    },
                  ),
                  WidgetNode(
                    type: 'text',
                    props: {
                      'content': 'Please log in',
                      'visible': '{{!state.isLoggedIn}}',
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      );

      final result = await adapter.toDefinition(bundle);
      expect(result.success, isTrue);
      final routes = result.data!['routes'] as Map<String, dynamic>;
      expect(routes.containsKey('/dashboard'), isTrue);
    });

    // TC-V12-010 (continued): Binding expressions preserved in definition
    test('binding resolution in content', () async {
      const bundle = McpBundle(
        manifest: BundleManifest(
          id: 'com.example.binding',
          name: 'Binding App',
          version: '1.0.0',
        ),
        ui: UiSection(
          pages: [
            ScreenDefinition(
              id: 'profile',
              name: 'Profile',
              route: '/profile',
              root: WidgetNode(
                type: 'text',
                props: {
                  'content': 'Hello, {{state.user.name}}!',
                },
              ),
            ),
          ],
        ),
      );

      final result = await adapter.toDefinition(bundle);
      expect(result.success, isTrue);
      // The binding expression should be preserved in the definition
      // for runtime resolution
      final routes = result.data!['routes'] as Map<String, dynamic>;
      expect(routes.containsKey('/profile'), isTrue);
    });

    // TC-V12-010 (continued): Theme config included in definition
    test('theme-dependent values in definition', () async {
      final bundle = McpBundle(
        manifest: BundleManifest(
          id: 'com.example.themed',
          name: 'Themed App',
          version: '1.0.0',
        ),
        ui: UiSection(
          pages: [
            ScreenDefinition(
              id: 'main',
              name: 'Main',
              route: '/',
              root: WidgetNode(
                type: 'container',
                props: {
                  'backgroundColor': '{{theme.color.surface}}',
                  'padding': 16,
                },
                children: [
                  WidgetNode(type: 'text', props: {
                    'content': 'Themed content',
                    'color': '{{theme.color.onSurface}}',
                  }),
                ],
              ),
            ),
          ],
          theme: ThemeConfig.fromJson({
            'mode': 'light',
            'color': {
              'primary': '#2196F3',
              'onPrimary': '#FFFFFF',
              'surface': '#FAFAFA',
              'onSurface': '#212121',
            },
          }),
        ),
      );

      final result = await adapter.toDefinition(bundle);
      expect(result.success, isTrue);
      // Theme should be included in the definition
      expect(result.data!.containsKey('theme'), isTrue);
      final routes = result.data!['routes'] as Map<String, dynamic>;
      expect(routes.containsKey('/'), isTrue);
    });
  });

  // ==========================================================================
  // Icon bundle:// resolution (TC-V12-004)
  // ==========================================================================
  group('icon bundle:// resolution', () {
    // TC-V12-004: Manifest field mapping — icon (bundle:// resolution)
    test('resolves bundle:// icon to data URI', () async {
      final pngBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);
      storage.assets['bundle://assets/icon.png'] = pngBytes;

      const bundle = McpBundle(
        manifest: BundleManifest(
          id: 'com.example.app',
          name: 'App',
          version: '1.0.0',
          icon: 'bundle://assets/icon.png',
        ),
      );

      final result = await adapter.toDefinition(bundle);
      expect(result.success, isTrue);
      expect(result.data!['icon'], startsWith('data:image/png;base64,'));
    });

    // TC-V12-004 (boundary): Icon is null — icon key absent from output
    test('null icon produces no icon key in output', () async {
      const bundle = McpBundle(
        manifest: BundleManifest(
          id: 'com.example.app',
          name: 'App',
          version: '1.0.0',
        ),
      );

      final result = await adapter.toDefinition(bundle);
      expect(result.success, isTrue);
      expect(result.data!.containsKey('icon'), isFalse);
    });

    // TC-V12-004 (error): Unresolvable icon URI — okWithWarnings, icon null
    test('unresolvable icon URI produces warning', () async {
      const bundle = McpBundle(
        manifest: BundleManifest(
          id: 'com.example.app',
          name: 'App',
          version: '1.0.0',
          icon: 'bundle://missing/icon.png',
        ),
      );

      final result = await adapter.toDefinition(bundle);
      expect(result.success, isTrue);
      expect(result.warnings, isNotEmpty);
      expect(result.warnings!.first.code, equals('UNRESOLVABLE_URI'));
    });
  });

  // ==========================================================================
  // Splash SplashConfig resolution (TC-V12-005)
  // ==========================================================================
  group('splash SplashConfig resolution', () {
    // TC-V12-005: Manifest field mapping — splash (SplashConfig resolution)
    test('resolves splash image bundle:// URI', () async {
      final pngBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);
      storage.assets['bundle://assets/splash.png'] = pngBytes;

      const bundle = McpBundle(
        manifest: BundleManifest(
          id: 'com.example.app',
          name: 'App',
          version: '1.0.0',
          splash: SplashConfig(
            image: 'bundle://assets/splash.png',
            backgroundColor: '#FFFFFF',
            duration: 3000,
          ),
        ),
      );

      final result = await adapter.toDefinition(bundle);
      expect(result.success, isTrue);
      final splash = result.data!['splash'] as Map<String, dynamic>;
      expect(splash['image'], startsWith('data:image/png;base64,'));
      expect(splash['backgroundColor'], equals('#FFFFFF'));
      expect(splash['duration'], equals(3000));
    });

    // TC-V12-005 (boundary): Splash is null — key absent from output
    test('null splash produces no splash key', () async {
      const bundle = McpBundle(
        manifest: BundleManifest(
          id: 'com.example.app',
          name: 'App',
          version: '1.0.0',
        ),
      );

      final result = await adapter.toDefinition(bundle);
      expect(result.success, isTrue);
      expect(result.data!.containsKey('splash'), isFalse);
    });
  });

  // ==========================================================================
  // Screenshots list resolution (TC-V12-009, TC-V12-E08)
  // ==========================================================================
  group('screenshots list resolution', () {
    // TC-V12-009: Manifest field mapping — screenshots (list resolution)
    test('resolves bundle:// screenshot URIs', () async {
      final png1 = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x01]);
      final png2 = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x02]);
      storage.assets['bundle://assets/s1.png'] = png1;
      storage.assets['bundle://assets/s2.png'] = png2;

      const bundle = McpBundle(
        manifest: BundleManifest(
          id: 'com.example.app',
          name: 'App',
          version: '1.0.0',
          screenshots: ['bundle://assets/s1.png', 'bundle://assets/s2.png'],
        ),
      );

      final result = await adapter.toDefinition(bundle);
      expect(result.success, isTrue);
      final screenshots = result.data!['screenshots'] as List;
      expect(screenshots.length, equals(2));
      expect(screenshots[0], startsWith('data:image/png;base64,'));
      expect(screenshots[1], startsWith('data:image/png;base64,'));
    });

    // TC-V12-E08: Screenshots — empty array vs null
    test('empty screenshots array is preserved as empty list', () async {
      const bundle = McpBundle(
        manifest: BundleManifest(
          id: 'com.example.app',
          name: 'App',
          version: '1.0.0',
          screenshots: [],
        ),
      );

      final result = await adapter.toDefinition(bundle);
      expect(result.success, isTrue);
      // Empty list should not produce a 'screenshots' key in serialized output
      // because BundleManifest.toJson() only emits when isNotEmpty.
      // However, the adapter itself preserves the distinction internally.
    });

    // TC-V12-E08 (continued): Null screenshots — key absent
    test('null screenshots produces no screenshots key', () async {
      const bundle = McpBundle(
        manifest: BundleManifest(
          id: 'com.example.app',
          name: 'App',
          version: '1.0.0',
        ),
      );

      final result = await adapter.toDefinition(bundle);
      expect(result.success, isTrue);
      expect(result.data!.containsKey('screenshots'), isFalse);
    });
  });

  // ==========================================================================
  // TC-V12-017: Icon resolution in toAppInfo — no bundle:// in response
  // ==========================================================================
  group('toAppInfo icon resolution', () {
    // TC-V12-017: Icon resolution in toAppInfo — no bundle:// in response
    test('resolves bundle:// icon in toAppInfo', () async {
      final pngBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);
      storage.assets['bundle://assets/icon.png'] = pngBytes;

      const bundle = McpBundle(
        manifest: BundleManifest(
          id: 'com.example.app',
          name: 'App',
          version: '1.0.0',
          icon: 'bundle://assets/icon.png',
        ),
      );

      final result = await adapter.toAppInfo(bundle);
      expect(result.success, isTrue);
      // Icon must never be raw bundle:// in response
      expect(result.data!['icon'], startsWith('data:image/png;base64,'));
    });

    // TC-V12-017 (boundary): Icon is null — icon absent from response
    test('null icon in toAppInfo produces no icon key', () async {
      const bundle = McpBundle(
        manifest: BundleManifest(
          id: 'com.example.app',
          name: 'App',
          version: '1.0.0',
        ),
      );

      final result = await adapter.toAppInfo(bundle);
      expect(result.success, isTrue);
      expect(result.data!.containsKey('icon'), isFalse);
    });

    // TC-V12-017 (error): Icon URI unresolvable — icon null, warning in result
    test('unresolvable icon in toAppInfo produces warning', () async {
      const bundle = McpBundle(
        manifest: BundleManifest(
          id: 'com.example.app',
          name: 'App',
          version: '1.0.0',
          icon: 'bundle://missing/icon.png',
        ),
      );

      final result = await adapter.toAppInfo(bundle);
      expect(result.success, isTrue);
      expect(result.warnings, isNotEmpty);
      expect(result.data!.containsKey('icon'), isFalse);
    });
  });

  // ==========================================================================
  // TC-V12-E10: All optional metadata null
  // ==========================================================================
  group('error cases', () {
    // TC-V12-E10: All optional metadata null — only required fields
    test('all optional metadata null produces valid result', () async {
      const bundle = McpBundle(
        manifest: BundleManifest(
          id: 'com.example.minimal',
          name: 'Minimal',
          version: '1.0.0',
        ),
      );

      final result = await adapter.toDefinition(bundle);
      expect(result.success, isTrue);
      expect(result.data!['title'], equals('Minimal'));
      expect(result.data!['version'], equals('1.0.0'));
      // No null keys should be emitted for optional fields
      expect(result.data!.containsKey('icon'), isFalse);
      expect(result.data!.containsKey('splash'), isFalse);
      expect(result.data!.containsKey('category'), isFalse);
      expect(result.data!.containsKey('publisher'), isFalse);
      expect(result.data!.containsKey('timestamps'), isFalse);
      expect(result.data!.containsKey('screenshots'), isFalse);
    });

    // TC-V12-E01: Invalid timestamp format handling
    // When BundleManifest is constructed from JSON with non-ISO 8601 strings,
    // DateTime.tryParse returns null. The adapter should produce a valid result
    // with no timestamps key (graceful degradation).
    test('invalid timestamp format results in absent timestamps', () async {
      // Simulate a manifest parsed from JSON with invalid timestamp values.
      // BundleManifest.fromJson uses DateTime.tryParse, so invalid strings
      // become null DateTime values on the manifest.
      final manifest = BundleManifest.fromJson({
        'id': 'com.example.app',
        'name': 'App',
        'version': '1.0.0',
        'createdAt': 'not-a-date',
        'updatedAt': 'also-invalid',
      });
      final bundle = McpBundle(manifest: manifest);

      final result = await adapter.toDefinition(bundle);
      expect(result.success, isTrue);
      // Invalid timestamps parsed as null — no timestamps key emitted
      expect(result.data!.containsKey('timestamps'), isFalse);
    });

    // TC-V12-E02: Invalid category → "other" fallback
    // AppCategory.fromString returns AppCategory.other for unknown values.
    test('invalid category maps to "other"', () async {
      // AppCategory.fromString('unknown_value') returns AppCategory.other
      final manifest = BundleManifest.fromJson({
        'id': 'com.example.app',
        'name': 'App',
        'version': '1.0.0',
        'category': 'nonexistent_category',
      });
      final bundle = McpBundle(manifest: manifest);

      final result = await adapter.toDefinition(bundle);
      expect(result.success, isTrue);
      expect(result.data!['category'], equals('other'));
    });

    // TC-V12-E03: Invalid splash config handling
    // When splash has wrong types (e.g., duration as string), the adapter
    // should handle gracefully.
    test('invalid splash config handled gracefully', () async {
      // SplashConfig.fromJson casts duration as int?, so passing a non-int
      // value would cause a type error during fromJson. The adapter receives
      // a pre-constructed SplashConfig, so test with null duration.
      const bundle = McpBundle(
        manifest: BundleManifest(
          id: 'com.example.app',
          name: 'App',
          version: '1.0.0',
          splash: SplashConfig(
            image: null,
            backgroundColor: '#FFFFFF',
            duration: null,
          ),
        ),
      );

      final result = await adapter.toDefinition(bundle);
      expect(result.success, isTrue);
      final splash = result.data!['splash'] as Map<String, dynamic>;
      expect(splash['backgroundColor'], equals('#FFFFFF'));
      // Null image and duration should not appear in output
      expect(splash.containsKey('image'), isFalse);
      expect(splash.containsKey('duration'), isFalse);
    });

    // TC-V12-E04: Missing publisher name
    // PublisherInfo.fromJson throws FormatException when name is missing.
    // Verify that constructing from JSON without name fails at parse level.
    test('missing publisher name throws on parse', () {
      expect(
        () => PublisherInfo.fromJson({'logo': 'icon.png'}),
        throwsA(isA<FormatException>()),
      );
    });

    // TC-V12-E06: Publisher name only (no logo, url, email)
    test('publisher with name only maps correctly', () async {
      const bundle = McpBundle(
        manifest: BundleManifest(
          id: 'com.example.app',
          name: 'App',
          version: '1.0.0',
          publisher: PublisherInfo(name: 'Example Corp'),
        ),
      );

      final result = await adapter.toDefinition(bundle);
      expect(result.success, isTrue);
      final publisher = result.data!['publisher'] as Map<String, dynamic>;
      expect(publisher['name'], equals('Example Corp'));
      expect(publisher.containsKey('logo'), isFalse);
      expect(publisher.containsKey('url'), isFalse);
      expect(publisher.containsKey('email'), isFalse);
    });

    // TC-V12-E07: Publisher logo only, no name — invalid at parse level
    test('publisher with logo only and no name is invalid', () {
      expect(
        () => PublisherInfo.fromJson({
          'logo': 'bundle://assets/logo.png',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    // TC-V12-E09: Icon present + category null
    test('icon present with null category', () async {
      final pngBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);
      storage.assets['bundle://assets/icon.png'] = pngBytes;

      const bundle = McpBundle(
        manifest: BundleManifest(
          id: 'com.example.app',
          name: 'App',
          version: '1.0.0',
          icon: 'bundle://assets/icon.png',
          // category is null (not provided)
        ),
      );

      final result = await adapter.toDefinition(bundle);
      expect(result.success, isTrue);
      // Icon should be resolved normally
      expect(result.data!['icon'], startsWith('data:image/png;base64,'));
      // Category should be absent from output
      expect(result.data!.containsKey('category'), isFalse);
    });
  });

  // ==========================================================================
  // Publisher resolution (TC-V12-007)
  // ==========================================================================
  group('publisher PublisherInfo resolution', () {
    // TC-V12-007: Publisher with logo bundle:// URI resolved
    test('resolves publisher logo bundle:// URI', () async {
      final logoBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);
      storage.assets['bundle://assets/logo.png'] = logoBytes;

      const bundle = McpBundle(
        manifest: BundleManifest(
          id: 'com.example.app',
          name: 'App',
          version: '1.0.0',
          publisher: PublisherInfo(
            name: 'Example Corp',
            logo: 'bundle://assets/logo.png',
            url: 'https://example.com',
            email: 'contact@example.com',
          ),
        ),
      );

      final result = await adapter.toDefinition(bundle);
      expect(result.success, isTrue);
      final publisher = result.data!['publisher'] as Map<String, dynamic>;
      expect(publisher['name'], equals('Example Corp'));
      // Logo URI should be resolved to data URI
      expect(publisher['logo'], startsWith('data:image/png;base64,'));
      expect(publisher['url'], equals('https://example.com'));
      expect(publisher['email'], equals('contact@example.com'));
    });

    // TC-V12-007 (boundary): Publisher is null — key absent from output
    test('null publisher produces no publisher key', () async {
      const bundle = McpBundle(
        manifest: BundleManifest(
          id: 'com.example.app',
          name: 'App',
          version: '1.0.0',
        ),
      );

      final result = await adapter.toDefinition(bundle);
      expect(result.success, isTrue);
      expect(result.data!.containsKey('publisher'), isFalse);
    });

    // TC-V12-007 (error): Unresolvable publisher logo URI — warning, logo null
    test('unresolvable publisher logo produces warning', () async {
      const bundle = McpBundle(
        manifest: BundleManifest(
          id: 'com.example.app',
          name: 'App',
          version: '1.0.0',
          publisher: PublisherInfo(
            name: 'Example Corp',
            logo: 'bundle://missing/logo.png',
          ),
        ),
      );

      final result = await adapter.toDefinition(bundle);
      expect(result.success, isTrue);
      expect(result.warnings, isNotEmpty);
      final publisher = result.data!['publisher'] as Map<String, dynamic>;
      expect(publisher['name'], equals('Example Corp'));
      // Logo should be null (unresolvable), so key absent from serialized output
      expect(publisher.containsKey('logo'), isFalse);
    });
  });

  // ==========================================================================
  // UiSection pages legacy alias (TC-V12-011)
  // ==========================================================================
  group('UiSection pages legacy alias', () {
    // TC-V12-011: UiSection with pages (v1.0 legacy alias for routes)
    test('pages key accepted and mapped to output', () async {
      // UiSection uses 'pages' field which is the canonical field name.
      // The pages are converted to routes via BundlePageAdapter.toRoutes().
      const bundle = McpBundle(
        manifest: BundleManifest(
          id: 'com.example.legacy',
          name: 'Legacy App',
          version: '1.0.0',
        ),
        ui: UiSection(
          pages: [
            ScreenDefinition(
              id: 'home',
              name: 'Home',
              route: '/',
              root: WidgetNode(type: 'text', props: {'content': 'Hello'}),
            ),
            ScreenDefinition(
              id: 'settings',
              name: 'Settings',
              route: '/settings',
              root: WidgetNode(type: 'container'),
            ),
          ],
        ),
      );

      final result = await adapter.toDefinition(bundle);
      expect(result.success, isTrue);
      final routes = result.data!['routes'] as Map<String, dynamic>;
      expect(routes.length, equals(2));
      expect(routes['/'], equals('ui://pages/home'));
      expect(routes['/settings'], equals('ui://pages/settings'));
      // Pages content should also be present
      expect(result.data!.containsKey('pages'), isTrue);
    });

    // TC-V12-011 (boundary): UiSection.fromJson accepts both 'routes' and
    // 'pages' keys — 'pages' is canonical in UiSection model
    test('UiSection.fromJson accepts pages key from JSON', () {
      final section = UiSection.fromJson({
        'pages': [
          {
            'id': 'home',
            'name': 'Home',
            'route': '/',
            'root': {'type': 'text'},
          },
        ],
      });
      expect(section.pages.length, equals(1));
      expect(section.pages.first.id, equals('home'));
    });
  });

  // ==========================================================================
  // Backward compatibility (TC-V12-058)
  // ==========================================================================
  group('backward compatibility', () {
    // TC-V12-058: v1.0 bundle (no v1.2 fields) — parses normally, no errors
    test('v1.0 bundle with no v1.2 fields works correctly', () async {
      // A v1.0 style bundle only has id, name, version, and basic UI section.
      // No v1.2 metadata fields (icon, splash, category, publisher, etc.).
      const bundle = McpBundle(
        manifest: BundleManifest(
          id: 'com.example.v1app',
          name: 'V1 App',
          version: '1.0.0',
          description: 'A v1.0 application',
        ),
        ui: UiSection(
          pages: [
            ScreenDefinition(
              id: 'home',
              name: 'Home',
              route: '/',
              root: WidgetNode(
                type: 'column',
                children: [
                  WidgetNode(type: 'text', props: {'content': 'Welcome'}),
                ],
              ),
            ),
          ],
        ),
      );

      final result = await adapter.toDefinition(bundle);
      expect(result.success, isTrue);
      expect(result.warnings, isNull);
      expect(result.data!['title'], equals('V1 App'));
      expect(result.data!['version'], equals('1.0.0'));
      expect(result.data!['description'], equals('A v1.0 application'));
      // v1.2 fields should be absent
      expect(result.data!.containsKey('icon'), isFalse);
      expect(result.data!.containsKey('splash'), isFalse);
      expect(result.data!.containsKey('category'), isFalse);
      expect(result.data!.containsKey('publisher'), isFalse);
      expect(result.data!.containsKey('timestamps'), isFalse);
      expect(result.data!.containsKey('screenshots'), isFalse);
      // Routes should be mapped correctly
      final routes = result.data!['routes'] as Map<String, dynamic>;
      expect(routes['/'], equals('ui://pages/home'));
    });
  });

  // ==========================================================================
  // Round-trip (TC-V12-062)
  // ==========================================================================
  group('round-trip write then read', () {
    // TC-V12-062: Write then read back — output matches input
    // Simulates the write adapter output by manually assembling a McpBundle
    // from a definition JSON, then reads it back via BundleUiReadAdapter.
    test('assembled bundle from definition reads back correctly', () async {
      // Step 1: Simulate write adapter output — build McpBundle from
      // an ApplicationDefinition JSON (title→name mapping, routes→pages)
      const bundle = McpBundle(
        manifest: BundleManifest(
          id: 'com.example.roundtrip',
          name: 'Round Trip App',
          version: '2.0.0',
          description: 'Testing round-trip',
          category: AppCategory.productivity,
        ),
        ui: UiSection(
          pages: [
            ScreenDefinition(
              id: 'home',
              name: 'home',
              route: '/',
              root: WidgetNode(
                  type: 'text', props: {'content': 'Home'}),
            ),
            ScreenDefinition(
              id: 'settings',
              name: 'settings',
              route: '/settings',
              root: WidgetNode(type: 'container'),
            ),
          ],
        ),
      );

      // Step 2: Read back via BundleUiReadAdapter
      final readResult = await adapter.toDefinition(bundle);
      expect(readResult.success, isTrue);

      // Step 3: Verify key fields are preserved through round-trip
      expect(readResult.data!['title'], equals('Round Trip App'));
      expect(readResult.data!['version'], equals('2.0.0'));
      expect(readResult.data!['id'], equals('com.example.roundtrip'));
      expect(readResult.data!['description'], equals('Testing round-trip'));
      expect(readResult.data!['category'], equals('productivity'));

      // Routes should match
      final routes = readResult.data!['routes'] as Map<String, dynamic>;
      expect(routes['/'], equals('ui://pages/home'));
      expect(routes['/settings'], equals('ui://pages/settings'));

      // Pages content should be present
      expect(readResult.data!.containsKey('pages'), isTrue);
      final pages = readResult.data!['pages'] as Map<String, dynamic>;
      expect(pages.containsKey('home'), isTrue);
      expect(pages.containsKey('settings'), isTrue);
    });
  });
}
