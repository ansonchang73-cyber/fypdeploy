// lib/features/adherence_analytics/presentation/screens/adherence_analytics_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/entities/adherence_summary.dart';
import '../providers/adherence_summary_provider.dart';
import '../widgets/distribution_row.dart';
import '../widgets/metric_card.dart';
import '../../../../core/widgets/glass_panel.dart';

class AdherenceAnalyticsScreen extends ConsumerWidget {
  /// When null (the default), shows the signed-in user's own analytics —
  /// unchanged from before. When set (by the caregiver dashboard), shows
  /// [patientId]'s analytics instead, with [patientName] reflected in the
  /// copy so it's clear whose data is on screen.
  const AdherenceAnalyticsScreen({super.key, this.patientId, this.patientName});

  final String? patientId;
  final String? patientName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isViewingOtherPatient = patientId != null;
    final summaryAsync = isViewingOtherPatient
        ? ref.watch(adherenceSummaryForPatientProvider(patientId!))
        : ref.watch(adherenceSummaryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          isViewingOtherPatient ? "${patientName ?? 'Patient'}'s Adherence" : 'Adherence Insights',
          style: GoogleFonts.inter(color: const Color(0xFF1E3A8A), fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
      ),
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (summary) {
          final feedback = _feedbackFor(summary.tier);
          final String possessive = isViewingOtherPatient ? 'their' : 'your';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Real-time compliance analytics and tracking patterns for SynchroM.',
                  style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 20),

                GlassPanel(
                  padding: const EdgeInsets.all(20),
                  borderRadius: 24,
                  child: Row(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 75,
                            height: 75,
                            child: CircularProgressIndicator(
                              value: summary.overallAdherencePercent / 100,
                              strokeWidth: 8,
                              backgroundColor: Colors.black.withAlpha(15),
                              valueColor: AlwaysStoppedAnimation<Color>(feedback.color),
                            ),
                          ),
                          Text(
                            '${summary.overallAdherencePercent}%',
                            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ],
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              feedback.title,
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Calculated across $possessive active scheduled timeline entries.',
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: MetricCard(
                        icon: LucideIcons.calendar,
                        iconColor: Colors.blue,
                        title: 'Current Tracked',
                        value: '${summary.totalDoses} Doses',
                        subtitle: 'Total daily items',
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: MetricCard(
                        icon: LucideIcons.checkCircle2,
                        iconColor: Colors.green,
                        title: 'Completed',
                        value: '${summary.completedDoses} Taken',
                        subtitle: 'Successful administration',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Text(
                  'Compliance Distributions',
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF1E3A8A)),
                ),
                const SizedBox(height: 12),

                GlassPanel(
                  padding: const EdgeInsets.all(20),
                  borderRadius: 24,
                  child: Column(
                    children: [
                      DistributionRow(
                        timeSlot: 'Morning Distribution (5 AM - 12 PM)',
                        factor: summary.morningAdherence,
                        percentageLabel: '${(summary.morningAdherence * 100).round()}%',
                        indicatorColor: _bucketColor(summary.morningAdherence),
                      ),
                      const Divider(height: 24, thickness: 1, color: Colors.black12),
                      DistributionRow(
                        timeSlot: 'Afternoon Distribution (12 PM - 6 PM)',
                        factor: summary.afternoonAdherence,
                        percentageLabel: '${(summary.afternoonAdherence * 100).round()}%',
                        indicatorColor: _bucketColor(summary.afternoonAdherence),
                      ),
                      const Divider(height: 24, thickness: 1, color: Colors.black12),
                      DistributionRow(
                        timeSlot: 'Evening Distribution (6 PM - 5 AM)',
                        factor: summary.eveningAdherence,
                        percentageLabel: '${(summary.eveningAdherence * 100).round()}%',
                        indicatorColor: _bucketColor(summary.eveningAdherence),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Per-bucket progress-bar color: a display-only threshold (unlike the
  /// overall [AdherenceTier], this one was never surfaced as text/copy in
  /// the original screen, just a green/amber progress bar), so it stays
  /// here rather than in the domain layer.
  Color _bucketColor(double factor) {
    return factor >= 0.80 ? const Color(0xFF10B981) : Colors.amber;
  }

  _Feedback _feedbackFor(AdherenceTier tier) {
    switch (tier) {
      case AdherenceTier.excellent:
        return _Feedback('Excellent Adherence', const Color(0xFF10B981));
      case AdherenceTier.good:
        return _Feedback('Good Progress', Colors.amber);
      case AdherenceTier.needsAttention:
        return _Feedback('Needs Attention', Colors.orange);
    }
  }
}

class _Feedback {
  final String title;
  final Color color;
  const _Feedback(this.title, this.color);
}
