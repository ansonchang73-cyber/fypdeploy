// lib/features/caregiver_dashboard/presentation/widgets/patient_home_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/widgets/glass_panel.dart';
import '../../domain/entities/linked_patient_summary.dart';
import '../providers/caregiver_dashboard_providers.dart';
import '../providers/patient_routine_provider.dart';
import 'adherence_ring.dart';

/// One linked patient's section on the Home tab: who they are, their
/// pie-chart adherence for today, and their routine list underneath —
/// exactly the three things asked for, stacked per patient so this still
/// makes sense whether a caregiver has one linked patient or several.
class PatientHomeCard extends ConsumerWidget {
  const PatientHomeCard({super.key, required this.patient});

  final LinkedPatientSummary patient;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routineAsync = ref.watch(patientRoutineProvider(patient.id));

    return GlassPanel(
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 24, backgroundImage: NetworkImage(patient.avatarUrl)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('LINKED PATIENT', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 1.1)),
                    Text(patient.fullName, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          routineAsync.when(
            loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator())),
            error: (err, stack) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text('Failed to load routine: $err', style: GoogleFonts.inter(color: Colors.red.shade700, fontSize: 12)),
            ),
            data: (doses) {
              final percentage = ref.watch(computeDailyAdherencePercentageProvider).call(doses);

              return Column(
                children: [
                  Center(child: AdherenceRing(percentage: percentage)),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Today's Routine", style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ),
                  const SizedBox(height: 10),
                  if (doses.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text('No doses scheduled for today.', style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 13)),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: doses.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final dose = doses[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FE),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                dose.isCompleted ? LucideIcons.checkCircle2 : LucideIcons.circle,
                                size: 18,
                                color: dose.isCompleted ? const Color(0xFF10B981) : Colors.grey.shade400,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(dose.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                                    Text(dose.dosage, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500)),
                                  ],
                                ),
                              ),
                              Text(
                                dose.time,
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: dose.isCompleted ? const Color(0xFF10B981) : Colors.black54),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
