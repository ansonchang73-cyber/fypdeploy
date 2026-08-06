// lib/features/caregiver_dashboard/presentation/screens/caregiver_home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../domain/entities/linked_patient_summary.dart';
import '../providers/linked_patients_provider.dart';
import '../providers/patient_routine_provider.dart';
import '../widgets/link_patient_dialog.dart';
import '../widgets/link_patient_empty_state.dart';
import '../widgets/patient_home_card.dart';

class CaregiverHomeScreen extends ConsumerWidget {
  const CaregiverHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientsAsync = ref.watch(linkedPatientsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Caregiver Home', style: GoogleFonts.inter(color: const Color(0xFF1E3A8A), fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.userPlus, color: Color(0xFF0058BC)),
            tooltip: 'Link a patient',
            onPressed: () => showLinkPatientDialog(context),
          ),
          const SizedBox(width: 8),
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
            padding: const EdgeInsets.all(20),
            itemCount: patients.length + 1,
            separatorBuilder: (context, index) => const SizedBox(height: 20),
            itemBuilder: (context, index) {
              if (index == 0) return _GlobalDelayedAlerts(patients: patients);
              return PatientHomeCard(patient: patients[index - 1]);
            },
          );
        },
      ),
    );
  }
}

class _GlobalDelayedAlerts extends ConsumerWidget {
  final List<LinkedPatientSummary> patients;
  const _GlobalDelayedAlerts({required this.patients});

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    List<Widget> delayedAlerts = [];

    for (final patient in patients) {
      final routine = ref.watch(patientRoutineProvider(patient.id)).valueOrNull ?? [];
      final delayedCount = routine.where((d) {
        if (d.isCompleted || d.isMarkedMissed) return false;
        final doseTime = _parseTime(d.time);
        return now.difference(doseTime).inMinutes > 15;
      }).length;

      if (delayedCount > 0) {
        delayedAlerts.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                const Icon(LucideIcons.alertTriangle, color: Color(0xFFD97706), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${patient.fullName} has $delayedCount delayed dose(s)',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF92400E)),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    if (delayedAlerts.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        border: Border.all(color: const Color(0xFFF59E0B)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.bellRing, color: Color(0xFFD97706), size: 20),
              const SizedBox(width: 8),
              Text('Action Required', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF92400E), fontSize: 14)),
            ],
          ),
          const SizedBox(height: 10),
          ...delayedAlerts,
        ],
      ),
    );
  }
}