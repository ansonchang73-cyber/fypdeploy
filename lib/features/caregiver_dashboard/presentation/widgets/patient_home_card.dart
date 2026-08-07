// lib/features/caregiver_dashboard/presentation/widgets/patient_home_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/providers/clock_ticker_provider.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../domain/entities/linked_patient_summary.dart';
import '../providers/caregiver_dashboard_providers.dart';
import '../providers/patient_routine_provider.dart';
import 'adherence_ring.dart';
import '../../../medication_management/presentation/screens/add_medication_screen.dart';
import '../../../system_health/domain/entities/scheduled_dose.dart';
import '../../../system_health/domain/usecases/classify_daily_schedule.dart';
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
  // Doses we've already popped a dialog for this session — a Set rather
  // than a single id, since a caregiver checking in later may find
  // several separate doses that have each crossed the 60-minute
  // unresolved mark, and each one deserves its own one-time alert (the
  // old single-id version got permanently stuck after the first).
  final Set<String> _alertedDoseIds = {};

  List<ScheduledDose> _toScheduledDoses(List<RoutineDose> doses) {
    return doses
        .map(
          (d) => ScheduledDose(
            id: d.id,
            name: d.name,
            dosage: d.dosage,
            time: d.time,
            isCompleted: d.isCompleted,
            isMarkedMissed: d.isMarkedMissed,
          ),
        )
        .toList();
  }

  // Same "Critical Schedule Delay" dialog the patient sees on their own
  // device (see `today_schedule_section.dart`) — reused here rather than
  // a separate caregiver-only design, just with caregiver-appropriate
  // copy and no "Remind Me Again" (there's no one left to remind; by the
  // time this fires the patient's own 15/30-minute reminder window has
  // already closed).
  void _showCaregiverAlertDialog(BuildContext context, ScheduledDose dose) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(LucideIcons.alertOctagon, color: Color(0xFFEF4444), size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Critical Schedule Delay',
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E3A8A)),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.patient.fullName}\'s scheduled window for ${dose.name} (${dose.time}) has been exceeded by more than 60 minutes with no response.',
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
    // Forces a rebuild every 30s so a dose crossing the 60-minute mark
    // gets caught even if nothing in Firestore changes in the meantime.
    ref.watch(clockTickerProvider);

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
              // Same classification the patient's own "Today's Schedule"
              // uses — one source of truth for what counts as delayed vs.
              // missed, instead of a second, separately-maintained copy
              // of the "how late is this" math living here.
              final classified = const ClassifyDailySchedule().call(_toScheduledDoses(doses), DateTime.now());

              // Notify the caregiver (this screen) only once a dose has
              // crossed the 60-minute unresolved mark — the patient's own
              // 15-minute and 30-minute reminders have already had their
              // chance by then. Only one dialog on screen at a time; the
              // next unresolved dose (if any) surfaces on the next
              // rebuild once this one is resolved.
              for (final c in classified.classifiedDoses) {
                if (!c.requiresCaregiverAlert) continue;
                if (_alertedDoseIds.contains(c.dose.id)) continue;

                _alertedDoseIds.add(c.dose.id);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  _showCaregiverAlertDialog(context, c.dose);
                });
                break;
              }

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
