// lib/features/system_health/data/repositories/medication_status_repository_impl.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/repositories/medication_status_repository.dart';

class MedicationStatusRepositoryImpl implements MedicationStatusRepository {
  MedicationStatusRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<void> markAsMissed(String taskId) async {
    final taskRef = _firestore.collection('medication_schedules').doc(taskId);

    // 1. Update the daily schedule for the UI (unchanged).
    await taskRef.update({'status': 'missed'});

    // 2. Create a permanent history receipt — mirrors
    // `MedicationScheduleRepositoryImpl.markAsTaken`'s pattern, which was
    // previously the ONLY place `medication_logs` ever got written to.
    // Without this, a missed dose was never recorded anywhere permanent:
    // `resetDailyAdherenceIfNeeded` wipes `medication_schedules` back to
    // 'upcoming' every day, so a historical adherence report could never
    // show any missed doses at all — every report's "Missed" count was
    // structurally guaranteed to read 0, regardless of what actually
    // happened.
    final taskSnapshot = await taskRef.get();
    final taskData = taskSnapshot.data();
    if (taskData != null) {
      await _firestore.collection('medication_logs').add({
        'userId': taskData['userId'],
        'medicationName': taskData['medicationName'] ?? 'Unknown',
        'dosage': taskData['dosage'] ?? '',
        'time': taskData['reminderTime'] ?? '',
        'status': 'missed',
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }
}
