// lib/features/system_health/presentation/widgets/caregiver_status_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/widgets/glass_panel.dart';
import '../../../profile/presentation/providers/linked_caregivers_provider.dart';
import '../providers/system_health_providers.dart';

class CaregiverStatusCard extends ConsumerWidget {
  const CaregiverStatusCard({super.key, required this.rawCaregiverName});

  final String? rawCaregiverName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(resolveCaregiverLinkProvider).call(rawCaregiverName);

    // Same linked-caregiver record the patient's own Settings screen reads
    // to show "Care Circle" avatars — reused here so the caregiver's
    // profile photo (set from their Settings screen) shows up live on the
    // patient's home screen too, not just a generic placeholder icon.
    final linkedCaregiversAsync = ref.watch(linkedCaregiversProvider);
    final String? caregiverAvatarUrl = linkedCaregiversAsync.maybeWhen(
      data: (caregivers) =>
          caregivers.isNotEmpty ? caregivers.first.avatarUrl : null,
      orElse: () => null,
    );
    final bool hasCaregiverAvatar =
        caregiverAvatarUrl != null && caregiverAvatarUrl.isNotEmpty;

    if (status.isLinked) {
      return GlassPanel(
        padding: const EdgeInsets.all(16),
        borderRadius: 20,
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFF0058BC).withValues(alpha: 0.1),
              backgroundImage:
                  hasCaregiverAvatar ? NetworkImage(caregiverAvatarUrl!) : null,
              child: hasCaregiverAvatar
                  ? null
                  : const Icon(LucideIcons.userCheck, color: Color(0xFF0058BC), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Linked Caregiver', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                  Text(status.name, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Active Secure Link', style: GoogleFonts.inter(color: const Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    return GlassPanel(
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.userX, color: Colors.orange, size: 22),
              const SizedBox(width: 8),
              Text('No Caregiver Linked', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
            ],
          ),
          const SizedBox(height: 12),
          Text('Link SynchroM to a supervisor or family member to sync alerts instantly.', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600, height: 1.4)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                _buildFlowStep('1', 'Navigate to your Profile menu.'),
                const SizedBox(height: 10),
                _buildFlowStep('2', 'Open Settings & configuration panels.'),
                const SizedBox(height: 10),
                _buildFlowStep('3', 'Scroll down & tap Caregiver Link generation.'),
                const SizedBox(height: 10),
                _buildFlowStep('4', 'Send the dispatch invitation token straight to them!'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowStep(String stepNumber, String instructionText) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 9,
          backgroundColor: const Color(0xFF0058BC),
          child: Text(
            stepNumber,
            style: GoogleFonts.inter(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            instructionText,
            style: GoogleFonts.inter(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
