// lib/features/caregiver_dashboard/presentation/screens/caregiver_analytics_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../adherence_analytics/presentation/screens/adherence_analytics_screen.dart';
import '../widgets/link_patient_dialog.dart';
import '../widgets/linked_patients_list.dart';

class CaregiverAnalyticsScreen extends StatelessWidget {
  const CaregiverAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Adherence Analytics', style: GoogleFonts.inter(color: const Color(0xFF1E3A8A), fontSize: 18, fontWeight: FontWeight.bold)),
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
      body: LinkedPatientsList(
        onPatientTap: (patient) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AdherenceAnalyticsScreen(
                patientId: patient.id,
                patientName: patient.fullName,
              ),
            ),
          );
        },
      ),
    );
  }
}
