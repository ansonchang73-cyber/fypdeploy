// lib/features/caregiver_dashboard/presentation/widgets/caregiver_patient_profile_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/widgets/glass_panel.dart';
import '../providers/patient_profile_view_providers.dart';

/// A read-only mirror of what `PatientProfileScreen` shows the patient
/// themselves — header, emergency contact, for one
/// linked patient. No edit forms here (editing is the patient's own
/// action).
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
          ],
        );
      },
    );
  }
}