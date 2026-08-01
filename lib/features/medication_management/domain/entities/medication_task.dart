// lib/features/medication_management/domain/entities/medication_task.dart
//
// Pure domain entity — moved out of the old `providers/timeline_provider.dart`,
// which mixed this in with the Firestore mapping and the StateNotifier.
// Consumed across features (adherence_analytics, system_health), so its
// shape and field names are unchanged from the original.
enum TaskStatus { completed, upcoming, missed }

class MedicationTask {
  final String id;
  final String name;
  final String dosage;
  final String time;
  final TaskStatus status;
  final String instructions;
  final String frequency;
  final DateTime? takenAt;

  const MedicationTask({
    required this.id,
    required this.name,
    required this.dosage,
    required this.time,
    required this.instructions,
    required this.frequency,
    this.status = TaskStatus.upcoming,
    this.takenAt,
  });

  MedicationTask copyWith({
    TaskStatus? status,
    String? instructions,
    String? frequency,
    DateTime? takenAt,
  }) {
    return MedicationTask(
      id: id,
      name: name,
      dosage: dosage,
      time: time,
      status: status ?? this.status,
      instructions: instructions ?? this.instructions,
      frequency: frequency ?? this.frequency,
      takenAt: takenAt ?? this.takenAt,
    );
  }
}
