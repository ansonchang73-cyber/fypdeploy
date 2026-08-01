// lib/features/caregiver_dashboard/presentation/screens/caregiver_home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../providers/linked_patients_provider.dart';
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
            itemCount: patients.length,
            separatorBuilder: (context, index) => const SizedBox(height: 20),
            itemBuilder: (context, index) => PatientHomeCard(patient: patients[index]),
          );
        },
      ),
    );
  }
}
