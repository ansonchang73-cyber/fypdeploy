// lib/features/caregiver_dashboard/domain/entities/routine_dose.dart

/// One entry in a patient's daily routine, as far as the caregiver
/// dashboard needs to know — a name, a time, and whether it's done.
/// Deliberately not `medication_management`'s `MedicationTask` — this
/// feature's domain layer shouldn't depend on another feature's
/// (still-Firestore-coupled) provider file. The presentation layer
/// adapts `MedicationTask` down to this, same pattern as
/// `adherence_analytics` and `system_health` already use.
class RoutineDose {
  final String name;
  final String dosage;
  final String time;
  final bool isCompleted;

  const RoutineDose({
    required this.name,
    required this.dosage,
    required this.time,
    required this.isCompleted,
  });
}
