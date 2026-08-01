// lib/features/medication_management/data/mappers/medication_task_mapper.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/medication_task.dart';

class MedicationTaskMapper {
  const MedicationTaskMapper._();

  static MedicationTask fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final Timestamp? takenAtTimestamp = data['takenAt'] as Timestamp?;

    return MedicationTask(
      id: doc.id,
      name: data['medicationName'] ?? '',
      time: data['reminderTime'] ?? '',
      dosage: data['dosage'] ?? '',
      status: _statusFromString(data['status'] ?? ''),
      instructions: data['instructions'] ?? 'No special instructions provided.',
      frequency: data['frequency'] ?? '',
      takenAt: takenAtTimestamp?.toDate(),
    );
  }

  static TaskStatus _statusFromString(String raw) {
    switch (raw.toLowerCase()) {
      case 'completed':
        return TaskStatus.completed;
      case 'missed':
        return TaskStatus.missed;
      default:
        return TaskStatus.upcoming;
    }
  }
}
