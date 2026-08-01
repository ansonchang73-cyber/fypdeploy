import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'glass_panel.dart'; // Your custom glass panel wrapper
import '../../features/medication_management/presentation/screens/add_medication_screen.dart';

class LuminousBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final String userId; // ✅ ADD THIS PROPERTY

  const LuminousBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.userId, // ✅ REQUIRE IT IN THE CONSTRUCTOR
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomRight,
      clipBehavior: Clip.none,
      children: [
        // 1. The Glass Navigation Bar Panel
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
          child: GlassPanel(
            child: Container(
              height: 80,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(0, LucideIcons.home, 'HOME'),
                  _buildNavItem(1, LucideIcons.calendar, 'SCHEDULE'),
                  _buildNavItem(2, LucideIcons.trendingUp, 'ANALYTICS'),
                  _buildNavItem(3, LucideIcons.user, 'PROFILE'),
                ],
              ),
            ),
          ),
        ),

        // 2. The Floating Action Button overlapping the edge
        Positioned(
          top: -15,
          right: 36,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFF0058bc),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(
                  LucideIcons.plus,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: () {
                  // ✅ FIXED: Properly closed the Navigator lambda parentheses block
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      // ✅ PASS THE USER ID TO YOUR SPECIFIC CREATION SCREEN HERE:
                      builder: (context) => CreateMedicationScheduleScreen(userId: userId),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
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
              color: isActive
                  ? const Color(0xFF004493)
                  : const Color(0xFF414755),
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive
                    ? const Color(0xFF004493)
                    : const Color(0xFF414755),
                letterSpacing: 0.02,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
