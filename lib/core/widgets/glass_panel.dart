import 'dart:ui';
import 'package:flutter/material.dart';

class GlassPanel extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding; 
  final double magnification; 

  const GlassPanel({
    super.key, 
    required this.child, 
    this.borderRadius = 20.0, 
    this.padding,
    this.magnification = 1.00, 
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none, 
      children: [
        // Layer 1: THE DEEP OUTSIDE SHADOW
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                  blurRadius: 28,
                  spreadRadius: -2, 
                  offset: const Offset(0, 14), 
                ),
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                  blurRadius: 14,
                  spreadRadius: -4,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
          ),
        ),

        // Layer 2: ✅ YOUR BRILLIANT FIX - THE SOLID SHIELD LAYER
        // This acts as a physical wall that stops the deep shadows from bleeding inside!
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FE), // Matches your SettingsScreen background color exactly
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
        ),

        // Layer 3: THE MAGNIFIED CRYSTAL FROSTED GLASS SHEET
        ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: padding, 
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.28),
                    Colors.white.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.65), 
                  width: 1.4,
                ),
              ),
              child: Transform.scale(
                scale: magnification,
                alignment: Alignment.center, 
                child: child,
              ),
            ),
          ),
        ),
      ],
    );
  }
}