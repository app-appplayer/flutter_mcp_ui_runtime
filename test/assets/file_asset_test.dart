// `file:` is what a host produces when it resolves `bundle://` before the
// runtime sees the document (§6.12.7 placement 1: "a data: URI or a local
// path"). A runtime with a filesystem draws it; one without takes the
// declared fallback. Found through an installed bundle whose every image fell
// back while the sound beside it played — the sound player took the path, the
// image resolver filed it under unknown.

import 'dart:async' show Completer;
import 'dart:convert' show base64Decode;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

// A 2×2 PNG.
const _pngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAD0lEQVQIHWP8z8DwHwAFAAH/'
    'ec5T0QAAAABJRU5ErkJggg==';

void main() {
  late Directory dir;
  late File png;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('file-asset-');
    png = File('${dir.path}/pixel.png');
    await png.writeAsBytes(base64Decode(_pngBase64));
  });

  tearDownAll(() => dir.delete(recursive: true));

  test('a file: URI is its own form, not unknown', () {
    expect(AssetRef.parse('file:///tmp/a.png')!.form, AssetForm.file);
    expect(AssetRef.parse(Uri.file('/tmp/a b.png').toString())!.form,
        AssetForm.file);
  });

  test('a build with a filesystem declares and serves the form', () {
    const resolver = AssetResolver.builtin;
    expect(resolver.supportedForms, contains(AssetForm.file));
    final provider =
        resolver.imageProviderFor(AssetRef.parse(png.uri.toString())!);
    expect(provider, isA<FileImage>());
    expect((provider! as FileImage).file.path, png.path);
  });

  testWidgets('an image whose src is a file: URI draws, not the fallback',
      (tester) async {
    final runtime = MCPUIRuntime();
    await runtime.initialize({
      'type': 'page',
      'content': {
        'type': 'image',
        'src': png.uri.toString(),
        'width': 20,
        'height': 20,
        'fallback': {'type': 'text', 'value': 'FELL BACK'},
      },
    });
    await tester
        .pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
    await tester.pump();

    expect(find.text('FELL BACK'), findsNothing);
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<FileImage>());
    await runtime.destroy();
  });

  testWidgets('a file that is not there fails the provider, not the runtime',
      (tester) async {
    // A missing file is reported through the image stream — the path
    // `Image.errorBuilder` (and so the declared fallback) hangs on — rather
    // than thrown into the build. Driven at the provider so the assertion is
    // on the runtime's handover, not on Flutter's frame timing.
    final provider = AssetResolver.builtin
        .imageProviderFor(AssetRef.parse('file://${dir.path}/absent.png')!)!;
    Object? reported;
    await tester.runAsync(() async {
      final done = Completer<void>();
      provider.resolve(ImageConfiguration.empty).addListener(
            ImageStreamListener(
              (image, sync) => done.complete(),
              onError: (error, stack) {
                reported = error;
                done.complete();
              },
            ),
          );
      await done.future.timeout(const Duration(seconds: 5));
    });

    expect(reported, isA<FileSystemException>());
  });
}
