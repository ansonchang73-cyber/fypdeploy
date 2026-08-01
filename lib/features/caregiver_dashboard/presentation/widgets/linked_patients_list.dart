// lib/features/caregiver_dashboard/presentation/widgets/linked_patients_list.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/widgets/glass_panel.dart';
import '../../domain/entities/linked_patient_summary.dart';
import '../providers/linked_patients_provider.dart';
import 'link_patient_empty_state.dart';

/// Shared list of linked-patient cards — used by both the Storage tab
/// (tap opens a reports dialog) and the Analytics tab (tap navigates to
/// that patient's analytics page). What happens on tap is entirely up to
/// [onPatientTap]; this widget only knows how to fetch and display the
/// list.
class LinkedPatientsList extends ConsumerWidget {
  const LinkedPatientsList({super.key, required this.onPatientTap});

  final ValueChanged<LinkedPatientSummary> onPatientTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientsAsync = ref.watch(linkedPatientsProvider);

    return patientsAsync.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
      error: (err, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Text('Failed to load patients: $err', style: GoogleFonts.inter(color: Colors.grey.shade600)),
        ),
      ),
      data: (patients) {
        if (patients.isEmpty) {
          return const LinkPatientEmptyState();
        }

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: patients.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final patient = patients[index];
            return InkWell(
              onTap: () => onPatientTap(patient),
              borderRadius: BorderRadius.circular(20),
              child: GlassPanel(
                padding: const EdgeInsets.all(16),
                borderRadius: 20,
                child: Row(
                  children: [
                    CircleAvatar(radius: 26, backgroundImage: NetworkImage(patient.avatarUrl)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        patient.fullName,
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ),
                    Icon(LucideIcons.chevronRight, color: Colors.grey.shade400, size: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
