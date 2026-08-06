// lib/features/caregiver_dashboard/presentation/screens/caregiver_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/glass_panel.dart';
import '../../domain/entities/linked_patient_summary.dart';
import '../providers/linked_patients_provider.dart';
import '../widgets/link_patient_empty_state.dart';
import '../widgets/caregiver_patient_profile_card.dart';
import '../../../profile/domain/entities/appointment.dart';
import '../../../profile/presentation/providers/appointments_providers.dart';
import '../../../profile/presentation/providers/report_export_controller.dart';
import '../../../profile/domain/usecases/build_adherence_report.dart';
import 'caregiver_settings_screen.dart';

class CaregiverProfileScreen extends ConsumerWidget {
  const CaregiverProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientsAsync = ref.watch(linkedPatientsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Patients Overview', style: GoogleFonts.inter(color: const Color(0xFF1E3A8A), fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.settings, color: Colors.black87),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const CaregiverSettingsScreen())),
          ),
        ],
      ),
      body: patientsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (patients) {
          if (patients.isEmpty) {
            return const LinkPatientEmptyState();
          }

          return ListView.separated(
            // 1. Force the list to always allow scrolling gestures
            physics: const AlwaysScrollableScrollPhysics(),
            // 2. Add 100px of bottom padding so the last patient clears the LuminousBottomNavBar
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            itemCount: patients.length,
            separatorBuilder: (context, index) => const SizedBox(height: 32),
            itemBuilder: (context, index) {
              return _PatientProfileSection(patient: patients[index]);
            },
          );
        },
      ),
    );
  }
}

class _PatientProfileSection extends ConsumerWidget {
  const _PatientProfileSection({required this.patient});

  final LinkedPatientSummary patient;

  String _appointmentRecordFileName(DateTime appointmentDate, BuildContext context, WidgetRef ref) {
    final monthStart = DateTime(appointmentDate.year, appointmentDate.month, 1);
    
    // We can use the BuildAdherenceReport UseCase to get the formatted label string
    final now = DateTime.now();
    final monthLabel = DateFormat('MMMM yyyy').format(monthStart);
    String label = '$monthLabel Adherence Report';
    
    if (monthStart.year == now.year && monthStart.month == now.month) {
      final lastDayOfMonth = DateTime(now.year, now.month + 1, 0).day;
      if (now.day < lastDayOfMonth) {
        label = '$monthLabel Adherence Report (up to ${_ordinal(now.day)})';
      }
    }

    return '${label.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.pdf';
  }

  String _ordinal(int day) {
    if (day >= 11 && day <= 13) return '${day}th';
    switch (day % 10) {
      case 1: return '${day}st';
      case 2: return '${day}nd';
      case 3: return '${day}rd';
      default: return '${day}th';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pastAppointmentsAsync = ref.watch(pastAppointmentsProvider(patient.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Basic Profile Info Card. Pass patientId, not the whole patient object.
        CaregiverPatientProfileCard(patientId: patient.id),
        const SizedBox(height: 24),

        // Past Appointments Title
        Row(
          children: [
            const Icon(LucideIcons.history, color: Color(0xFF8E24AA), size: 20),
            const SizedBox(width: 8),
            Text('Past Scheduled Appointments', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
          ],
        ),
        const SizedBox(height: 12),

        // Past Appointments List
        pastAppointmentsAsync.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
          error: (err, stack) => Text('Failed to load appointments: $err'),
          data: (pastAppointments) {
            if (pastAppointments.isEmpty) {
              return GlassPanel(
                padding: const EdgeInsets.all(20), borderRadius: 16,
                child: Row(
                  children: [
                    Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle), child: Icon(LucideIcons.history, color: Colors.grey.shade500, size: 20)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('No Past Appointments', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 14)), const SizedBox(height: 2),
                          Text('Clinical visit history will appear here.', style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            final visibleAppointments = pastAppointments.length > 3 ? pastAppointments.sublist(0, 3) : pastAppointments;
            
            return ListView.separated(
              shrinkWrap: true, 
              physics: const NeverScrollableScrollPhysics(), 
              padding: EdgeInsets.zero, 
              itemCount: visibleAppointments.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final Appointment appointment = visibleAppointments[index];
                final String fileName = _appointmentRecordFileName(appointment.dateTime, context, ref);
                
                return GlassPanel(
                  padding: const EdgeInsets.all(16),
                  borderRadius: 16,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                        child: Icon(LucideIcons.checkCircle, color: Colors.grey.shade400, size: 22)
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              appointment.title,
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.grey.shade700)
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Dr. ${appointment.doctorName} • ${appointment.location}',
                              style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(LucideIcons.clock, size: 14, color: Colors.grey.shade500),
                                  const SizedBox(width: 6),
                                  Text(DateFormat('EEE, MMM d, yyyy • h:mm a').format(appointment.dateTime), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () async {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)), const SizedBox(width: 12), Expanded(child: Text('Generating PDF...', style: GoogleFonts.inter(fontWeight: FontWeight.w500)))]), backgroundColor: Colors.grey.shade800));
                                try {
                                  final path = await ref.read(reportExportControllerProvider).exportAppointmentRecord(appointment, fileName, patientId: patient.id, patientName: patient.fullName);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Saved to: $path', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)), backgroundColor: const Color(0xFF10B981), duration: const Duration(seconds: 6)));
                                } catch (e) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red));
                                }
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(LucideIcons.fileText, size: 16, color: Colors.grey.shade600),
                                    const SizedBox(width: 8),
                                    Flexible(child: Text(fileName, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600), overflow: TextOverflow.ellipsis)),
                                    const SizedBox(width: 8),
                                    Icon(LucideIcons.downloadCloud, size: 16, color: Colors.grey.shade600)
                                  ]
                                ),
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
}