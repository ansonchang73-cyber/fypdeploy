// lib/features/system_health/presentation/widgets/today_schedule_section.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/widgets/glass_panel.dart';
import '../../../medication_management/presentation/providers/timeline_provider.dart';
import '../../domain/entities/scheduled_dose.dart';
import '../providers/daily_schedule_provider.dart';
import '../providers/system_health_providers.dart';
import '../providers/today_ui_state_providers.dart';

class TodayScheduleSection extends ConsumerWidget {
  const TodayScheduleSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dailyScheduleProvider);

    return summaryAsync.when(
      loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
      error: (err, stack) => GlassPanel(
        padding: const EdgeInsets.all(16),
        borderRadius: 20,
        child: Text(
          "❌ Schedule Stream Connection Failure:\n$err",
          style: GoogleFonts.inter(color: Colors.red.shade700, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
      data: (summary) {
        final isTodayExpanded = ref.watch(todayExpandedProvider);
        final allDoses = summary.classifiedDoses;
        final visibleDoses = isTodayExpanded ? allDoses : allDoses.take(3).toList();

        // The one dose (if any) that just slipped into the delayed window
        // gets a one-time caregiver prompt — same trigger point as the
        // original (a post-frame callback fired during build), just
        // driven by the domain-computed `requiresCaregiverPrompt` flag
        // instead of an inline `task == activeEligibleTask` check.
        for (final classified in allDoses) {
          if (!classified.requiresCaregiverPrompt) continue;
          final currentPromptedId = ref.watch(activePromptTaskIdProvider);
          if (currentPromptedId == classified.dose.id) continue;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(activePromptTaskIdProvider.notifier).state = classified.dose.id;
            _showCaregiverPromptDialog(context, ref, classified.dose);
          });
          break;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "TODAY'S SCHEDULE",
              style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
            const SizedBox(height: 10),
            if (allDoses.isEmpty)
              GlassPanel(
                padding: const EdgeInsets.all(16),
                borderRadius: 20,
                child: Center(
                  child: Text('No logged doses for today.', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600)),
                ),
              )
            else ...[
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: visibleDoses.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final classified = visibleDoses[index];
                  return _InteractiveMedicationItem(
                    classified: classified,
                    onTakeMedication: () {
                      ref.read(timelineProvider.notifier).markAsTaken(classified.dose.id);
                    },
                  );
                },
              ),
              if (allDoses.length > 3)
                _DropdownButton(
                  isExpanded: isTodayExpanded,
                  onTap: () => ref.read(todayExpandedProvider.notifier).state = !isTodayExpanded,
                  hiddenCount: allDoses.length - 3,
                ),
            ],
          ],
        );
      },
    );
  }

  void _showCaregiverPromptDialog(BuildContext context, WidgetRef ref, ScheduledDose dose) {
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
                'The scheduled window for ${dose.name} (${dose.time}) has been exceeded by more than 60 minutes.',
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
                await ref.read(timelineProvider.notifier).markAsTaken(dose.id);
                ref.read(activePromptTaskIdProvider.notifier).state = null;
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
                // Now goes through the repository instead of a raw
                // Firestore call inline in the dialog.
                await ref.read(medicationStatusRepositoryProvider).markAsMissed(dose.id);
                ref.read(activePromptTaskIdProvider.notifier).state = null;
                if (context.mounted) Navigator.pop(context);
              },
              child: Text('Missed Entirely', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}

class _InteractiveMedicationItem extends StatelessWidget {
  const _InteractiveMedicationItem({required this.classified, required this.onTakeMedication});

  final ClassifiedDose classified;
  final VoidCallback onTakeMedication;

  @override
  Widget build(BuildContext context) {
    final visual = _visualFor(classified);
    final dose = classified.dose;

    return IgnorePointer(
      ignoring: classified.isMissed || (!classified.isActionable && classified.tier != DoseStatusTier.compliant),
      child: Opacity(
        opacity: classified.isMissed ? 0.6 : 1.0,
        child: InkWell(
          onTap: classified.isActionable ? onTakeMedication : null,
          borderRadius: BorderRadius.circular(20),
          child: GlassPanel(
            padding: const EdgeInsets.all(16),
            borderRadius: 20,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: visual.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                  child: Icon(visual.icon, color: visual.color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(visual.label, style: GoogleFonts.inter(fontSize: 11, color: visual.color, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      const SizedBox(height: 2),
                      Text(dose.name, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                      Text(dose.dosage, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (classified.isActionable)
                      const Icon(LucideIcons.playCircle, size: 20, color: Color(0xFF0058BC))
                    else
                      Icon(LucideIcons.alarmClock, size: 16, color: visual.color.withValues(alpha: 0.6)),
                    const SizedBox(height: 4),
                    Text(
                      dose.time,
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: classified.isMissed ? const Color(0xFFB91C1C) : visual.color),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _DoseVisual _visualFor(ClassifiedDose classified) {
    switch (classified.tier) {
      case DoseStatusTier.compliant:
        return _DoseVisual(const Color(0xFF10B981), LucideIcons.checkCircle, 'COMPLIANT / ON-TIME');
      case DoseStatusTier.readyEarly:
        return _DoseVisual(const Color(0xFF0058BC), LucideIcons.pill, 'READY (TAKE EARLY)');
      case DoseStatusTier.upcoming:
        return _DoseVisual(const Color(0xFF0058BC), LucideIcons.pill, 'UPCOMING');
      case DoseStatusTier.readyOnTime:
        return _DoseVisual(const Color(0xFF0058BC), LucideIcons.pill, 'READY (ON-TIME)');
      case DoseStatusTier.delayed:
        return _DoseVisual(const Color(0xFFF59E0B), LucideIcons.clock, 'DELAYED (${classified.minutesLate} Mins Late)');
      case DoseStatusTier.missed:
        return _DoseVisual(const Color(0xFFEF4444), LucideIcons.alertTriangle, 'MISSED (LOCKED OUT)');
    }
  }
}

class _DoseVisual {
  final Color color;
  final IconData icon;
  final String label;
  const _DoseVisual(this.color, this.icon, this.label);
}

class _DropdownButton extends StatelessWidget {
  const _DropdownButton({required this.isExpanded, required this.onTap, required this.hiddenCount});

  final bool isExpanded;
  final VoidCallback onTap;
  final int hiddenCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: [
              Text(
                isExpanded ? "Show Less" : "Show More (+$hiddenCount items)",
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF0058BC), fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 4),
              Icon(isExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown, size: 16, color: const Color(0xFF0058BC)),
            ],
          ),
        ),
      ),
    );
  }
}
