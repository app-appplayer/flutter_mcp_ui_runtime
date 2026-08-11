// `AssetResolver.vectorWidgetFor` — the vector half of the asset contract.
//
// Vectors take a picture widget rather than an `ImageProvider`, so this is a
// second dispatch over the same schemes, with the same rule: `null` means the
// slot falls back (§6.12.4), and a slot waiting for bytes shows its loading
// state rather than its fallback (§6.12.5). A scheme that returns null when
// it could have drawn is a logo that never appears.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/assets/asset_ref.dart';
import 'package:flutter_mcp_ui_runtime/src/assets/asset_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

/// The smallest well-formed SVG a renderer will accept.
const _svg =
    '<svg xmlns="http://www.w3.org/2000/svg" width="8" height="8">'
    '<rect width="8" height="8" fill="#FF0000"/></svg>';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AssetRef refFor(String uri) => AssetRef.parse(uri)!;
  final svgBytes = Uint8List.fromList(utf8.encode(_svg));

  group('the synchronous schemes', () {
    test('a network vector is drawn directly', () {
      expect(
          AssetResolver().vectorWidgetFor(refFor('https://example.com/a.svg')),
          isNotNull);
    });

    test('a flutter asset vector is drawn directly', () {
      expect(AssetResolver().vectorWidgetFor(refFor('assets/logo.svg')),
          isNotNull);
    });

    test('a data: vector is decoded inline', () {
      final uri = 'data:image/svg+xml;base64,${base64Encode(svgBytes)}';

      expect(AssetResolver().vectorWidgetFor(refFor(uri)), isNotNull);
    });

    test('a data: URI that will not decode falls back', () {
      expect(
          AssetResolver()
              .vectorWidgetFor(refFor('data:image/svg+xml;base64,!!!')),
          isNull,
          reason: 'null is how this says use the slot fallback; a broken '
              'payload must not become an empty box that looks deliberate');
    });

    test('a reference in no known form is refused', () {
      final unknown = AssetRef.parse('nonsense://thing');

      expect(unknown == null || AssetResolver().vectorWidgetFor(unknown) == null,
          isTrue);
    });
  });

  group('the asynchronous schemes', () {
    testWidgets('a bundle vector waits, then draws', (tester) async {
      final resolver = AssetResolver(bundleReader: (path) async => svgBytes);

      await tester.pumpWidget(MaterialApp(
        home: Center(
          child: resolver.vectorWidgetFor(
            refFor('bundle://logo.svg'),
            width: 8,
            height: 8,
            loadingBuilder: () => const Text('loading'),
          ),
        ),
      ));

      expect(find.text('loading'), findsOneWidget,
          reason: '§6.12.5 — a slot awaiting bytes shows its loading state, '
              'not its fallback; showing the fallback would flash the wrong '
              'image every time');

      await tester.pumpAndSettle();
      expect(find.text('loading'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('with no loading builder it holds the declared size',
        (tester) async {
      final resolver = AssetResolver(bundleReader: (path) async => svgBytes);

      await tester.pumpWidget(MaterialApp(
        home: Center(
          child: resolver.vectorWidgetFor(
            refFor('bundle://logo.svg'),
            width: 24,
            height: 24,
          ),
        ),
      ));

      expect(
          tester.widget<SizedBox>(find.byType(SizedBox).first).width, 24,
          reason: 'reserving the space stops the layout jumping when the '
              'bytes arrive');

      await tester.pumpAndSettle();
    });

    testWidgets('bytes that never arrive leave nothing rather than an error',
        (tester) async {
      final resolver = AssetResolver(bundleReader: (path) async => null);

      await tester.pumpWidget(MaterialApp(
        home: Center(
          child: resolver.vectorWidgetFor(refFor('bundle://logo.svg')),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    test('a scheme this runtime cannot reach falls back', () {
      expect(AssetResolver().vectorWidgetFor(refFor('bundle://logo.svg')),
          isNull,
          reason: 'with no reader wired the runtime cannot reach the bytes, '
              'and the slot has to be told so');
      expect(AssetResolver().vectorWidgetFor(refFor('client://file/a.svg')),
          isNull);
    });

    testWidgets('a client vector reads through the client reader',
        (tester) async {
      final resolver = AssetResolver(clientReader: (uri) async => svgBytes);

      await tester.pumpWidget(MaterialApp(
        home: Center(
          child: resolver.vectorWidgetFor(refFor('client://file/logo.svg')),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
