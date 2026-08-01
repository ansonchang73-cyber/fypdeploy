// lib/features/caregiver_dashboard/presentation/widgets/caregiver_patient_profile_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/glass_panel.dart';
import '../../../profile/domain/entities/appointment.dart';
import '../../../profile/domain/usecases/merge_live_overdue_doses.dart';
import '../../../profile/presentation/providers/report_export_controller.dart';
import '../providers/patient_profile_view_providers.dart';

/// A read-only mirror of what `PatientProfileScreen` shows the patient
/// themselves — header, emergency contact, and appointments — for one
/// linked patient. No edit forms here (editing is the patient's own
/// action), but past appointments ARE downloadable — same PDF the patient
/// gets from their own profile, appointment details plus that month's
/// medication adherence report, since that's exactly what a caregiver
/// pulling up a "storage" of records needs.
class CaregiverPatientProfileCard extends ConsumerWidget {
  const CaregiverPatientProfileCard({super.key, required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(patientProfileForCaregiverProvider(patientId));

    return profileAsync.when(
      loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 30), child: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Failed to load profile: $err', style: GoogleFonts.inter(color: Colors.red.shade700, fontSize: 12)),
      ),
      data: (patient) {
        final bool hasPhone = patient.phone.isNotEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlassPanel(
              padding: const EdgeInsets.all(20),
              borderRadius: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Labeled explicitly so this card is never mistaken for
                  // the caregiver's own info while browsing linked patients.
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0058BC).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.user, size: 11, color: Color(0xFF0058BC)),
                        const SizedBox(width: 5),
                        Text(
                          'PATIENT',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0058BC),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(radius: 32, backgroundImage: NetworkImage(patient.avatarUrl)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(patient.fullName, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E3A8A))),
                            const SizedBox(height: 4),
                            Text(
                              '${patient.gender}, ${patient.age} yrs • Blood Type: ${patient.bloodType}',
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            GlassPanel(
              padding: const EdgeInsets.all(16),
              borderRadius: 20,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (hasPhone ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      hasPhone ? LucideIcons.phoneCall : LucideIcons.alertTriangle,
                      color: hasPhone ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PATIENT CONTACT', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 1.0)),
                        Text(
                          hasPhone ? '${patient.fullName} • ${patient.phone}' : 'No phone number set',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Text('Upcoming Appointments', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 10),
            _AppointmentsList(
              provider: patientUpcomingAppointmentsForCaregiverProvider(patientId),
              emptyLabel: 'No upcoming appointments.',
              isPast: false,
              patientId: patientId,
              patientName: patient.fullName,
            ),

            const SizedBox(height: 20),
            Text('Past Appointments', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
            const SizedBox(height: 10),
            _AppointmentsList(
              provider: patientPastAppointmentsForCaregiverProvider(patientId),
              emptyLabel: 'No past appointments.',
              isPast: true,
              patientId: patientId,
              patientName: patient.fullName,
            ),
          ],
        );
      },
    );
  }
}

/// Named identically to what `PatientProfileScreen`'s "Medication
/// Adherence Logs" section calls the same month's report (e.g. "July
/// 2026 Adherence Report (Up to Jul 29)", sanitized) via the shared
/// `adherenceReportLabelForMonth`, rather than a separate naming scheme
/// that could drift from it.
String _appointmentRecordFileName(DateTime appointmentDate) {
  final monthStart = DateTime(appointmentDate.year, appointmentDate.month, 1);
  final label = adherenceReportLabelForMonth(monthStart);
  return '${label.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.pdf';
}

class _AppointmentsList extends ConsumerStatefulWidget {
  const _AppointmentsList({
    required this.provider,
    required this.emptyLabel,
    required this.patientId,
    required this.patientName,
    this.isPast = false,
  });

  final ProviderListenable<AsyncValue<List<Appointment>>> provider;
  final String emptyLabel;
  final String patientId;
  final String patientName;
  final bool isPast;

  @override
  ConsumerState<_AppointmentsList> createState() => _AppointmentsListState();
}

class _AppointmentsListState extends ConsumerState<_AppointmentsList> {
  // Tracks which specific appointment (by id) is currently generating a
  // PDF, so only that row shows a spinner rather than the whole list.
  String? _downloadingAppointmentId;

  Future<void> _download(Appointment appointment) async {
    final fileName = _appointmentRecordFileName(appointment.dateTime);
    setState(() => _downloadingAppointmentId = appointment.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Generating $fileName...', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
            ),
          ],
        ),
        backgroundColor: Colors.grey.shade800,
      ),
    );

    try {
      final path = await ref.read(reportExportControllerProvider).exportAppointmentRecord(
            appointment,
            fileName,
            patientId: widget.patientId,
            patientName: widget.patientName,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Saved to: $path', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _downloadingAppointmentId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appointmentsAsync = ref.watch(widget.provider);

    return appointmentsAsync.when(
      loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      error: (err, stack) => Text('Failed to load: $err', style: GoogleFonts.inter(color: Colors.red.shade700, fontSize: 12)),
      data: (appointments) {
        if (appointments.isEmpty) {
          return Text(widget.emptyLabel, style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 13));
        }

        return Column(
          children: appointments.map((appointment) {
            final bool isDownloading = _downloadingAppointmentId == appointment.id;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GlassPanel(
                padding: const EdgeInsets.all(12),
                borderRadius: 14,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.isPast 
                            ? Colors.grey.shade200 
                            : const Color(0xFF8E24AA).withValues(alpha: 0.1), 
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        widget.isPast ? LucideIcons.checkCircle : LucideIcons.stethoscope, 
                        size: 16, 
                        color: widget.isPast ? Colors.grey.shade400 : const Color(0xFF8E24AA),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(appointment.title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: widget.isPast ? Colors.grey.shade500 : Colors.black87)),
                          Text('Dr. ${appointment.doctorName} • ${appointment.location}', style: GoogleFonts.inter(fontSize: 11, color: widget.isPast ? Colors.grey.shade400 : Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    Text(
                      DateFormat('MMM d, h:mm a').format(appointment.dateTime),
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: widget.isPast ? Colors.grey.shade400 : const Color(0xFF8E24AA)),
                    ),
                    if (widget.isPast) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: isDownloading ? null : () => _download(appointment),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0058BC).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: isDownloading
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0058BC)),
                                )
                              : const Icon(LucideIcons.download, size: 14, color: Color(0xFF0058BC)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
