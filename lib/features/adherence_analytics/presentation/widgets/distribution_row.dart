// lib/features/adherence_analytics/presentation/widgets/distribution_row.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DistributionRow extends StatelessWidget {
  const DistributionRow({
    super.key,
    required this.timeSlot,
    required this.factor,
    required this.percentageLabel,
    required this.indicatorColor,
  });

  final String timeSlot;
  final double factor;
  final String percentageLabel;
  final Color indicatorColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(timeSlot, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87)),
            Text(percentageLabel, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: indicatorColor)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: factor,
            minHeight: 6,
            backgroundColor: Colors.black.withAlpha(12),
            valueColor: AlwaysStoppedAnimation<Color>(indicatorColor),
          ),
        ),
      ],
    );
  }
}
