import 'package:flutter/material.dart';

import 'map_link.dart';

/// Native fallback: no embedded map, but the pin and the directions target are
/// still visible so the hirer can verify what will be shared with workers.
Widget buildMapPreview({
  required String link,
  required double? latitude,
  required double? longitude,
  required String area,
}) {
  final pin = MapLink.pinLabel(latitude, longitude);
  return Builder(
    builder: (context) {
      final theme = Theme.of(context);
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.map_outlined, color: theme.colorScheme.primary, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Location preview',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    pin.isEmpty
                        ? (area.trim().isEmpty ? 'No pin yet' : area.trim())
                        : 'Pin: $pin',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Open directions to see the route on the map.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
