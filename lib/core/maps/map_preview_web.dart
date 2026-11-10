import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'map_link.dart';

/// Web implementation: a keyless Google Maps embed inside an iframe.
///
/// `maps.google.com/maps?...&output=embed` needs no API key, so it works with
/// the existing `KALLALAI_MAPS_CONFIGURED=false` build. The iframe is sandboxed
/// to navigation + scripts and never receives credentials.
Widget buildMapPreview({
  required String link,
  required double? latitude,
  required double? longitude,
  required String area,
}) => _WebMapPreview(
  link: link,
  latitude: latitude,
  longitude: longitude,
  area: area,
);

class _WebMapPreview extends StatefulWidget {
  const _WebMapPreview({
    required this.link,
    required this.latitude,
    required this.longitude,
    required this.area,
  });

  final String link;
  final double? latitude;
  final double? longitude;
  final String area;

  @override
  State<_WebMapPreview> createState() => _WebMapPreviewState();
}

class _WebMapPreviewState extends State<_WebMapPreview> {
  static int _counter = 0;

  late final String _viewType;
  late final web.HTMLIFrameElement _iframe;

  String get _embedUrl => MapLink.embedUrl(
    link: widget.link,
    latitude: widget.latitude,
    longitude: widget.longitude,
    area: widget.area,
  );

  @override
  void initState() {
    super.initState();
    _viewType = 'kalla-lai-map-${_counter++}';
    _iframe = web.document.createElement('iframe') as web.HTMLIFrameElement;
    _iframe
      ..src = _embedUrl
      ..setAttribute('title', 'Work location on Google Maps')
      ..setAttribute('loading', 'lazy')
      ..setAttribute('referrerpolicy', 'no-referrer-when-downgrade')
      ..setAttribute('sandbox', 'allow-scripts allow-same-origin allow-popups')
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%';
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _iframe,
    );
  }

  @override
  void didUpdateWidget(covariant _WebMapPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_embedUrl != MapLink.embedUrl(
      link: oldWidget.link,
      latitude: oldWidget.latitude,
      longitude: oldWidget.longitude,
      area: oldWidget.area,
    )) {
      _iframe.src = _embedUrl;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(14),
        ),
        child: HtmlElementView(viewType: _viewType),
      ),
    );
  }
}
