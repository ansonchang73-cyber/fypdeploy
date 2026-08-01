// lib/features/caregiver_dashboard/presentation/widgets/adherence_ring.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class AdherenceRing extends StatelessWidget {
  final double percentage; // e.g., 88.0 for 88%

  const AdherenceRing({
    super.key,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      width: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The Circular Chart
          PieChart(
            PieChartData(
              startDegreeOffset: 270, // Starts at the top
              sectionsSpace: 0,
              centerSpaceRadius: 70, // Creates the hollow center
              sections: [
                // Completed Section (Blue)
                PieChartSectionData(
                  value: percentage,
                  color: const Color(0xFF1E88E5), // Primary Blue
                  radius: 20,
                  showTitle: false,
                ),
                // Remaining Section (Light Grey)
                PieChartSectionData(
                  value: 100 - percentage,
                  color: Colors.grey.shade200,
                  radius: 20,
                  showTitle: false,
                ),
              ],
            ),
            swapAnimationDuration: const Duration(milliseconds: 800),
            swapAnimationCurve: Curves.easeInOut,
          ),

          // The Inner Text
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${percentage.toInt()}%',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E88E5),
                ),
              ),
              Text(
                'Completion',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
