import 'package:flutter/material.dart';
import 'app_theme.dart';

/// "Data Card" per the design system: Level-1 slate surface, 24px radius,
/// large metric in Space Grotesk, label + trend on top.
class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color? valueColor;
  final Color? subColor;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.sub,
    this.valueColor,
    this.subColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppFonts.label(fontSize: 11, color: AppColors.textDim),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppFonts.metric(fontSize: 22, color: valueColor ?? AppColors.text),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: AppFonts.body(fontSize: 12, color: subColor ?? AppColors.textDim),
          ),
        ],
      ),
    );
  }
}
