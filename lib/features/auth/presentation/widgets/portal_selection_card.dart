// lib/features/auth/presentation/widgets/portal_selection_card.dart
import 'package:flutter/material.dart';

class PortalSelectionCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color themeColor;
  final String buttonText;
  final bool isSelected;
  final VoidCallback onTap;

  const PortalSelectionCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.themeColor,
    required this.buttonText,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? themeColor : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: themeColor.withValues(alpha: 0.15),
                blurRadius: 15,
                offset: const Offset(0, 5),
              )
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: themeColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: themeColor, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSelected ? themeColor : Colors.white,
                  foregroundColor: isSelected ? Colors.white : themeColor,
                  elevation: 0,
                  side: BorderSide(color: themeColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(buttonText),
              ),
            )
          ],
        ),
      ),
    );
  }
}