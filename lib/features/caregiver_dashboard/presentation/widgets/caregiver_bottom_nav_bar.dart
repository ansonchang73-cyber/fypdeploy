// lib/features/caregiver_dashboard/presentation/widgets/caregiver_bottom_nav_bar.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/widgets/glass_panel.dart';

/// Same visual language as `LuminousBottomNavBar` (the patient shell's
/// nav bar), but with the caregiver's four tabs and no floating "add
/// medication" button — a caregiver isn't adding doses for themselves.
class CaregiverBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CaregiverBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
      child: GlassPanel(
        child: Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, LucideIcons.home, 'HOME'),
              _buildNavItem(1, LucideIcons.folderOpen, 'STORAGE'),
              _buildNavItem(2, LucideIcons.trendingUp, 'ANALYTICS'),
              _buildNavItem(3, LucideIcons.user, 'PROFILE'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData iconData, String label) {
    final bool isActive = currentIndex == index;

    return InkWell(
      onTap: () => onTap(index),
      borderRadius: BorderRadius.circular(9999),
      splashColor: const Color(0xFF0058bc).withValues(alpha: 0.1),
      highlightColor: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFd8e2ff) : Colors.transparent,
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              iconData,
              color: isActive ? const Color(0xFF004493) : const Color(0xFF414755),
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? const Color(0xFF004493) : const Color(0xFF414755),
                letterSpacing: 0.02,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
