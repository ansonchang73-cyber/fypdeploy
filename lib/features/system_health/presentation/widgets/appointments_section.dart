// lib/features/system_health/presentation/widgets/appointments_section.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/widgets/glass_panel.dart';
import '../../domain/entities/appointment_summary.dart';
import '../providers/system_health_providers.dart';

class AppointmentsSection extends ConsumerWidget {
  const AppointmentsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    final appointmentsAsync = ref.watch(
      _upcomingAppointmentsProvider(user.uid),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.calendarDays, color: Color(0xFF8E24AA), size: 20),
            const SizedBox(width: 8),
            Text(
              'Scheduled Appointments',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
            ),
          ],
        ),
        const SizedBox(height: 12),
        appointmentsAsync.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
          error: (err, stack) => _buildEmptyAppointmentsCard(),
          data: (appointments) {
            if (appointments.isEmpty) return _buildEmptyAppointmentsCard();

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: appointments.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final AppointmentSummary appointment = appointments[index];

                return GlassPanel(
                  padding: const EdgeInsets.all(16),
                  borderRadius: 16,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8E24AA).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(LucideIcons.stethoscope, color: Color(0xFF8E24AA), size: 22),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              appointment.title,
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Dr. ${appointment.doctorName} • ${appointment.location}',
                              style: GoogleFonts.inter(color: Colors.grey.shade700, fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8E24AA).withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF8E24AA).withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(LucideIcons.clock, size: 14, color: Color(0xFF8E24AA)),
                                  const SizedBox(width: 6),
                                  Text(
                                    DateFormat('EEE, MMM d, yyyy • h:mm a').format(appointment.dateTime),
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF8E24AA)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildEmptyAppointmentsCard() {
    return GlassPanel(
      padding: const EdgeInsets.all(20),
      borderRadius: 16,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle),
            child: Icon(LucideIcons.calendarX, color: Colors.grey.shade500, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No Upcoming Appointments', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 14)),
                const SizedBox(height: 2),
                Text('Future clinical visits will appear here.', style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Top 2, descending — matches the original screen's exact query shape.
final _upcomingAppointmentsProvider = StreamProvider.family
    .autoDispose<List<AppointmentSummary>, String>((ref, userId) {
      return ref
          .watch(appointmentRepositoryProvider)
          .watchUpcomingAppointments(userId, limit: 2);
    });
