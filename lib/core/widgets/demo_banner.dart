import 'package:flutter/material.dart';
import 'package:kalla_lai/core/config/app_config.dart';
import 'package:kalla_lai/core/localization/app_strings.dart';
import 'package:kalla_lai/core/theme/kalla_lai_theme.dart';

class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final text = AppStrings.of(
      context,
    ).text(AppConfig.liveApiEnabled ? 'live_banner' : 'demo_banner');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      color: const Color(0xFFFFF3D6),
      child: Row(
        children: [
          const Icon(
            Icons.science_outlined,
            size: 18,
            color: KallaLaiColors.slate,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: KallaLaiColors.slate,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
