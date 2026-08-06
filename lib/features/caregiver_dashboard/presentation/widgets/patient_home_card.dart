// lib/features/caregiver_dashboard/presentation/widgets/patient_home_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/widgets/glass_panel.dart';
import '../../domain/entities/linked_patient_summary.dart';
import '../providers/caregiver_dashboard_providers.dart';
import '../providers/patient_routine_provider.dart';
import 'adherence_ring.dart';
import '../../../medication_management/presentation/screens/add_medication_screen.dart';
import '../../../system_health/presentation/providers/system_health_providers.dart';
import '../../../medication_management/presentation/providers/medication_management_providers.dart';
import '../../domain/entities/routine_dose.dart';

class PatientHomeCard extends ConsumerStatefulWidget {
  const PatientHomeCard({super.key, required this.patient});

  final LinkedPatientSummary patient;

  @override
  ConsumerState<PatientHomeCard> createState() => _PatientHomeCardState();
}

class _PatientHomeCardState extends ConsumerState<PatientHomeCard> {
  String? _promptedDoseId;

  DateTime _parseTime(String timeStr) {
    try {
      final cleanTime = timeStr.toUpperCase().trim();
      final isPM = cleanTime.contains('PM');
      final isAM = cleanTime.contains('AM');
      final rawTimeStr = cleanTime.replaceAll(RegExp(r'[A-Z\s]'), '');
      final parts = rawTimeStr.split(':');
      if (parts.isNotEmpty) {
        int hour = int.parse(parts[0].trim());
        final int minute = parts.length > 1 ? int.parse(parts[1].trim()) : 0;
        if (isPM && hour < 12) hour += 12;
        if (isAM && hour == 12) hour = 0;
        final now = DateTime.now();
        return DateTime(now.year, now.month, now.day, hour, minute);
      }
    } catch (_) {}
    return DateTime.now();
  }

  void _showCaregiverPromptDialog(BuildContext context, RoutineDose dose) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(LucideIcons.alertOctagon, color: Color(0xFFF59E0B), size: 28),
              const SizedBox(width: 12),
              Text('Critical Schedule Delay', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E3A8A))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The scheduled window for ${dose.name} (${dose.time}) has been exceeded by more than 15 minutes.',
                style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade700, height: 1.4),
              ),
              const SizedBox(height: 16),
              Text('Did the patient take this late, or was it missed entirely?', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () async {
                await ref.read(medicationScheduleRepositoryProvider).markAsTaken(dose.id, widget.patient.id);
                if (context.mounted) Navigator.pop(context);
              },
              child: Text('Taken Late', style: GoogleFonts.inter(color: const Color(0xFFF59E0B), fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: () async {
                await ref.read(medicationStatusRepositoryProvider).markAsMissed(dose.id);
                if (context.mounted) Navigator.pop(context);
              },
              child: Text('Missed Entirely', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final routineAsync = ref.watch(patientRoutineProvider(widget.patient.id));

    return GlassPanel(
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 24, backgroundImage: NetworkImage(widget.patient.avatarUrl)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('LINKED PATIENT', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 1.1)),
                    Text(widget.patient.fullName, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => CreateMedicationScheduleScreen(userId: widget.patient.id),
                    ),
                  );
                },
                icon: const Icon(LucideIcons.plus, size: 16),
                label: Text('Add Med', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFEEF2FF),
                  foregroundColor: const Color(0xFF6366F1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              final now = DateTime.now();
              final List<RoutineDose> delayedDoses = [];

              for (final dose in doses) {
                if (dose.isCompleted || dose.isMarkedMissed) continue;
                final doseTime = _parseTime(dose.time);
                final minutesLate = now.difference(doseTime).inMinutes;
                
                if (minutesLate > 15) {
                  delayedDoses.add(dose);
                  if (minutesLate <= 60 && _promptedDoseId != dose.id) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      setState(() => _promptedDoseId = dose.id);
                      _showCaregiverPromptDialog(context, dose);
                    });
                  }
                }
              }

              final percentage = ref.watch(computeDailyAdherencePercentageProvider).call(doses);

              return Column(
                children: [
                  if (delayedDoses.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFCD34D)),
                      ),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.clock, color: Color(0xFFD97706), size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: delayedDoses.map((d) {
                                final delayMins = now.difference(_parseTime(d.time)).inMinutes;
                                return Text(
                                  '${d.name} is $delayMins min overdue',
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF92400E)),
                                );
                              }).toList(),
                            ),
                          ),
                          TextButton(
                            onPressed: () {}, 
                            child: Text('Check', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFD97706))),
                          ),
                        ],
                      ),
                    ),
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