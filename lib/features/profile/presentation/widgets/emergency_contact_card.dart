// lib/features/profile/presentation/widgets/emergency_contact_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../providers/patient_profile_controller.dart';

/// NOTE: this widget is not currently placed in any screen — the same is
/// true in the original project. `PatientProfileScreen` draws its own
/// inline "EMERGENCY ROUTER" panel instead of using this widget. Kept and
/// cleaned up as-is; not wired in as part of this pass, since that would
/// be a UI/feature change rather than a decoupling one.
///
/// Previously this widget read `FirebaseAuth.instance` and
/// `FirebaseFirestore.instance` directly to build its own copy of "watch
/// the current user's profile". It now reuses [patientProfileProvider],
/// the same stream every other profile screen watches, instead of
/// maintaining a second one.
class EmergencyContactCard extends ConsumerWidget {
  const EmergencyContactCard({super.key});

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(patientProfileProvider);

    return profileAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => const SizedBox.shrink(),
      data: (patient) {
        final String contactName = patient.emergencyContactName;
        final String contactPhone = patient.emergencyContactPhone;
        final bool hasCaregiver = contactPhone.isNotEmpty && contactName.isNotEmpty;

        return GlassPanel(
          padding: const EdgeInsets.all(18),
          borderRadius: 24,
          child: Row(
            children: [
              // State-Driven Status Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: hasCaregiver
                      ? const Color(0xFFEF4444).withOpacity(0.1)
                      : const Color(0xFFF59E0B).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasCaregiver ? LucideIcons.phoneCall : LucideIcons.alertTriangle,
                  color: hasCaregiver ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),

              // Contact Description Block
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'EMERGENCY CONTACT',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: hasCaregiver ? const Color(0xFFEF4444) : Colors.grey.shade500,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasCaregiver ? contactName : 'No Linked Caregiver',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    if (hasCaregiver)
                      Text(
                        contactPhone,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),

              // Interactive Action Gate
              if (hasCaregiver)
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.all(10),
                  ),
                  icon: const Icon(LucideIcons.phone, color: Colors.white, size: 18),
                  onPressed: () => _makePhoneCall(contactPhone),
                )
              else
                Tooltip(
                  message: 'Please link a caregiver in Settings to enable emergency syncing.',
                  triggerMode: TooltipTriggerMode.tap,
                  preferBelow: false,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      LucideIcons.helpCircle,
                      color: Color(0xFFF59E0B),
                      size: 18,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}