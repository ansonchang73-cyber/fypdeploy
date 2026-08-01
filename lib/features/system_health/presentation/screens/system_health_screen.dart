// lib/features/system_health/presentation/screens/system_health_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/widgets/glass_panel.dart';
import '../providers/system_health_providers.dart';
import '../widgets/analytics_summary_card.dart';
import '../widgets/appointments_section.dart';
import '../widgets/caregiver_status_card.dart';
import '../widgets/critical_alert_card.dart';
import '../widgets/today_schedule_section.dart';

class SystemHealthScreen extends ConsumerWidget {
  const SystemHealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthStateAsync = ref.watch(systemHealthProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'SYSTEM HEALTH',
          style: GoogleFonts.inter(
            color: Colors.grey.shade600,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: false,
      ),
      body: healthStateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading health data: $err')),
        data: (healthState) {
          final filteredAlerts = healthState.activeAlerts.where((alert) {
            return !alert.description.toLowerCase().contains('missed medication');
          }).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GlassPanel(
                  padding: const EdgeInsets.all(20),
                  borderRadius: 20.0,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0058BC).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.monitor_heart, color: Color(0xFF0058BC), size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Smart Alerts Center',
                              style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1E3A8A)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Real-time health monitoring & notifications',
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                CaregiverStatusCard(rawCaregiverName: healthState.caregiverName),
                const SizedBox(height: 24),

                const AppointmentsSection(),
                const SizedBox(height: 24),

                AnalyticsSummaryCard(systemEventsCount: healthState.eventsLoggedToday),
                const SizedBox(height: 24),

                const TodayScheduleSection(),
                const SizedBox(height: 24),

                if (filteredAlerts.isNotEmpty) ...[
                  ...filteredAlerts.map((alert) => CriticalAlertCard(alert: alert)),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
