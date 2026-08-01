// lib/features/caregiver_dashboard/presentation/widgets/link_patient_empty_state.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/widgets/glass_panel.dart';
import 'link_patient_dialog.dart';

/// Shown on Home, Storage, Analytics, and Profile whenever the signed-in
/// caregiver has no linked patients yet — the only entry point into the
/// invitation-code redeem flow before this, there wasn't one anywhere.
class LinkPatientEmptyState extends StatelessWidget {
  const LinkPatientEmptyState({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: GlassPanel(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          borderRadius: 24.0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.userX, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                message ?? 'No patients linked to your account yet.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => showLinkPatientDialog(context),
                icon: const Icon(LucideIcons.link, size: 16),
                label: Text('Link a Patient', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0058BC),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
