// lib/features/medication_management/presentation/widgets/next_dose_card.dart
//
// NOTE: not currently placed in any screen — same as in the original
// project. `TimelineScreen` renders its own inline dose cards instead of
// using this widget. Relocated and import fixed, not wired in (that
// would be a feature change, not a decoupling one).
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../domain/entities/medication_task.dart';

class NextDoseCard extends StatelessWidget {
  final MedicationTask task;
  final VoidCallback onMarkTaken;

  const NextDoseCard({super.key, required this.task, required this.onMarkTaken});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(20),
      borderRadius: 24.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.clock, size: 16, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                'NEXT SCHEDULED DOSE',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade700, letterSpacing: 1.2),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${task.time} ${task.name}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            'Maintain cognitive function. Take 1 tablet (${task.dosage}) with or without food.',
            style: TextStyle(color: Colors.grey.shade600, height: 1.5),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: onMarkTaken,
              icon: const Icon(LucideIcons.checkCircle, color: Colors.white),
              label: const Text('Mark as Taken', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E88E5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
