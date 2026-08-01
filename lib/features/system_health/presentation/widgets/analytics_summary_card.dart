// lib/features/system_health/presentation/widgets/analytics_summary_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/widgets/glass_panel.dart';
import '../providers/daily_schedule_provider.dart';

class AnalyticsSummaryCard extends ConsumerWidget {
  const AnalyticsSummaryCard({super.key, required this.systemEventsCount});

  final int systemEventsCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dailyScheduleProvider);

    return summaryAsync.when(
      loading: () => const SizedBox(height: 140, child: Center(child: CircularProgressIndicator())),
      error: (_, __) => const SizedBox.shrink(),
      data: (summary) {
        final totalTasks = summary.classifiedDoses.length;
        final completedCount = summary.completedCount;
        final delayedCount = summary.delayedCount;
        final missedCount = summary.missedCount;
        final upcomingCount = summary.upcomingCount;
        final complianceRatio = summary.complianceRatio;

        return GlassPanel(
          padding: const EdgeInsets.all(22),
          borderRadius: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "TODAY'S ANALYTICS SUMMARY",
                style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1),
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 95,
                    height: 95,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const SizedBox(
                          width: 95,
                          height: 95,
                          child: CircularProgressIndicator(
                            value: 1.0,
                            strokeWidth: 9,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0058BC)),
                          ),
                        ),
                        if (totalTasks > 0 && (missedCount + delayedCount) > 0)
                          SizedBox(
                            width: 95,
                            height: 95,
                            child: CircularProgressIndicator(
                              value: (completedCount + missedCount + delayedCount) / totalTasks,
                              strokeWidth: 9,
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFEF4444)),
                            ),
                          ),
                        if (totalTasks > 0 && delayedCount > 0)
                          SizedBox(
                            width: 95,
                            height: 95,
                            child: CircularProgressIndicator(
                              value: (completedCount + delayedCount) / totalTasks,
                              strokeWidth: 9,
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                            ),
                          ),
                        if (totalTasks > 0 && completedCount > 0)
                          SizedBox(
                            width: 95,
                            height: 95,
                            child: CircularProgressIndicator(
                              value: completedCount / totalTasks,
                              strokeWidth: 9,
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                            ),
                          ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${(complianceRatio * 100).toInt()}%',
                              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF1E3A8A)),
                            ),
                            Text('Adherence', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Dose Allocation Distribution", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            height: 22,
                            color: Colors.black.withValues(alpha: 0.03),
                            child: totalTasks == 0
                                ? Center(child: Text('No active logs', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)))
                                : Row(
                                    children: [
                                      if (completedCount > 0) Expanded(flex: completedCount, child: Container(color: const Color(0xFF10B981), child: const Center(child: Icon(LucideIcons.check, size: 12, color: Colors.white)))),
                                      if (delayedCount > 0) Expanded(flex: delayedCount, child: Container(color: const Color(0xFFF59E0B), child: const Center(child: Icon(LucideIcons.clock, size: 12, color: Colors.white)))),
                                      if (missedCount > 0) Expanded(flex: missedCount, child: Container(color: const Color(0xFFEF4444), child: const Center(child: Icon(LucideIcons.alertCircle, size: 12, color: Colors.white)))),
                                      if (upcomingCount > 0) Expanded(flex: upcomingCount, child: Container(color: const Color(0xFF0058BC))),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text("Visual scale of active data stream metrics.", style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(height: 1, thickness: 1, color: Colors.black12),
              const SizedBox(height: 16),
              Table(
                columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1)},
                children: [
                  _buildMetricTableRow('Doses Taken Successfully', '$completedCount', const Color(0xFF10B981)),
                  _buildMetricTableRow('Doses Inside Delayed Window', '$delayedCount', const Color(0xFFF59E0B)),
                  _buildMetricTableRow('Critical Delay / Missed', '$missedCount', const Color(0xFFEF4444)),
                  _buildMetricTableRow('Remaining Active Trackers', '$upcomingCount', const Color(0xFF0058BC)),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, thickness: 1, color: Colors.black12),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Text('$systemEventsCount', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF0058BC))),
                  ),
                  const SizedBox(width: 12),
                  Text('Telemetry Logs Active Today', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  TableRow _buildMetricTableRow(String label, String value, Color statusColor) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(label, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87), textAlign: TextAlign.end),
        ),
      ],
    );
  }
}
