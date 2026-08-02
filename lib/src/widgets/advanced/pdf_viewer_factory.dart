import 'package:flutter/material.dart';

import '../../assets/asset_ref.dart';
import '../../renderer/render_context.dart';
import '../widget_factory.dart';
import 'platform/pdf_view.dart';

/// Factory for `pdfViewer` (spec §10.25).
///
/// `src` is an `AssetRef`, so the same document works from a bundle, a URL, a
/// picked file (`fileInput` writes a `data:` URI), or a server resource.
///
/// Where the platform has no PDF renderer, this reports rather than rendering
/// a blank box — the §6.12.4 rule applied to a widget: a host that cannot
/// serve a form says so, and `onError` fires so the document can respond.
class PdfViewerFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);

    final raw = context.resolve<dynamic>(properties['src']);
    final ref = AssetRef.parse(raw);
    final height = context.resolve<num?>(properties['height'])?.toDouble();
    final onError = properties['onError'] as Map<String, dynamic>?;

    void reportError(String message) {
      if (onError == null) return;
      context.actionHandler.execute(
        onError,
        context.createChildContext(
          variables: {
            'event': {'type': 'error', 'message': message},
          },
        ),
      );
    }

    if (ref == null) {
      return _Unavailable(
        height: height,
        message: 'No document',
        onBuilt: () => reportError('pdfViewer: no src'),
      );
    }

    if (!pdfViewSupported) {
      return _Unavailable(
        height: height,
        message: 'PDF viewing is not available on this platform',
        onBuilt: () => reportError(
            'pdfViewer: this runtime has no PDF renderer on this platform'),
      );
    }

    // The browser fetches the document itself, so it needs a URL it can
    // resolve: a network URL or an inline data: URI. Bundle- and origin-served
    // documents are read by the host and handed over as data:.
    final source = switch (ref.form) {
      AssetForm.network || AssetForm.data => ref.uri,
      _ => null,
    };

    if (source == null) {
      return _Unavailable(
        height: height,
        message: 'This document source cannot be displayed here',
        onBuilt: () => reportError(
            'pdfViewer: ${ref.form.name} sources need the host to supply bytes'),
      );
    }

    return buildPdfView(source: source, height: height ?? 480);
  }
}

class _Unavailable extends StatefulWidget {
  const _Unavailable({
    required this.message,
    required this.onBuilt,
    this.height,
  });

  final String message;
  final VoidCallback onBuilt;
  final double? height;

  @override
  State<_Unavailable> createState() => _UnavailableState();
}

class _UnavailableState extends State<_Unavailable> {
  @override
  void initState() {
    super.initState();
    // Reported once, after the frame, so the document hears about it rather
    // than only the user seeing an empty area.
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onBuilt());
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: widget.height ?? 240,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(widget.message, textAlign: TextAlign.center),
          ),
        ),
      );
}
