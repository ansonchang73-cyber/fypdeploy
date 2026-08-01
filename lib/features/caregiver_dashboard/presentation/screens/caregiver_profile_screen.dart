// lib/features/caregiver_dashboard/presentation/screens/caregiver_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'caregiver_settings_screen.dart';
import '../providers/linked_patients_provider.dart';
import '../widgets/caregiver_patient_profile_card.dart';
import '../widgets/link_patient_dialog.dart';
import '../widgets/link_patient_empty_state.dart';

/// Replaces the old "Profile tab just opens Settings" behavior. Mirrors
/// `PatientProfileScreen`'s structure — but shows the linked patient(s),
/// not the caregiver's own medical info, since that's what a caregiver
/// actually wants from this tab. The caregiver's own account settings are
/// still one tap away via the gear icon, same pattern
/// `PatientProfileScreen` itself uses.
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
        title: Text('Profile', style: GoogleFonts.inter(color: const Color(0xFF1E3A8A), fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.userPlus, color: Color(0xFF0058BC)),
            tooltip: 'Link a patient',
            onPressed: () => showLinkPatientDialog(context),
          ),
          IconButton(
            icon: const Icon(LucideIcons.settings, color: Color(0xFF1E3A8A)),
            tooltip: 'Your account settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const CaregiverSettingsScreen()),
            ),
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
            separatorBuilder: (context, index) => const SizedBox(height: 24),
            itemBuilder: (context, index) => CaregiverPatientProfileCard(patientId: patients[index].id),
          );
        },
      ),
    );
  }
}
