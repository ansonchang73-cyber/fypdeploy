// lib/features/medication_management/data/repositories/medication_schedule_repository_impl.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/medication_schedule_plan.dart';
import '../../domain/entities/medication_task.dart';
import '../../domain/repositories/medication_schedule_repository.dart';
import '../mappers/medication_task_mapper.dart';

class MedicationScheduleRepositoryImpl implements MedicationScheduleRepository {
  MedicationScheduleRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<List<MedicationTask>> watchSchedule(String userId) {
    return _firestore
        .collection('medication_schedules')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MedicationTaskMapper.fromFirestore(doc))
              .toList(),
        );
  }

  @override
  Future<void> resetDailyAdherenceIfNeeded(String userId) async {
    final String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final userMetaRef = _firestore.collection('users').doc(userId);

    final metaSnapshot = await userMetaRef.get();
    if (metaSnapshot.exists && metaSnapshot.data()?['lastResetDate'] == todayStr) {
      return;
    }

    final WriteBatch batch = _firestore.batch();

    // Anything still sitting at 'upcoming' from before today was never
    // confirmed taken OR missed by the patient — they just never
    // responded to the reminder. Silence isn't compliance: without this,
    // those slots got wiped below with zero historical trace, so
    // `medication_logs` (what every adherence report reads) only ever
    // saw doses the patient actively engaged with, which could inflate
    // the reported percentage — e.g. 2 explicitly-confirmed doses out of
    // 2 logged showing 100%, even if a dozen other reminders were simply
    // ignored. Give each of those a permanent "missed" receipt (mirrors
    // `markAsTaken`'s pattern) before the slot rolls over for the new day.
    final staleUpcomingQuery = await _firestore
        .collection('medication_schedules')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'upcoming')
        .get();

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterday = todayStart.subtract(const Duration(days: 1));

    for (final doc in staleUpcomingQuery.docs) {
      final data = doc.data();
      // Guard against the one case where this would be wrong: a
      // medication added earlier *today*, on a day this reset hasn't
      // run yet. Its slots are legitimately 'upcoming' for today and
      // haven't had a fair chance to be taken — only slots that have
      // been sitting unconfirmed since *before* today represent a day
      // that has actually fully elapsed.
      final Timestamp? createdAt = data['createdAt'] as Timestamp?;
      if (createdAt != null && !createdAt.toDate().isBefore(todayStart)) {
        continue;
      }

      final String reminderTime = data['reminderTime'] ?? '';
      final logRef = _firestore.collection('medication_logs').doc();
      batch.set(logRef, {
        'userId': userId,
        'medicationName': data['medicationName'] ?? 'Unknown',
        'dosage': data['dosage'] ?? '',
        'time': reminderTime,
        'status': 'missed',
        // Deliberately NOT FieldValue.serverTimestamp() — that would
        // record "the moment this reset happened to run" (today, or
        // even later if the patient skipped a few days), not the day
        // the dose was actually missed. A per-day adherence table reads
        // this timestamp to decide which day's row a missed dose counts
        // against, so it needs to land on the day it's actually for.
        'timestamp': Timestamp.fromDate(_timestampFor(yesterday, reminderTime)),
      });
    }

    final completedSchedulesQuery = await _firestore
        .collection('medication_schedules')
        .where('userId', isEqualTo: userId)
        .where('status', whereIn: ['completed', 'missed'])
        .get();

    for (var doc in completedSchedulesQuery.docs) {
      batch.update(doc.reference, {
        'status': 'upcoming',
        'takenAt': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    batch.set(userMetaRef, {'lastResetDate': todayStr}, SetOptions(merge: true));
    await batch.commit();
  }

  /// Best-effort parse of a "8:00 AM" / "08:00" reminder-time string,
  /// combined with [date] — falls back to noon on that date if the
  /// string doesn't parse, so an implicitly-missed dose still lands on
  /// the right *day* even when the exact time can't be determined.
  /// Mirrors the same tolerant parsing used in `build_adherence_report.dart`
  /// and `merge_live_overdue_doses.dart`.
  DateTime _timestampFor(DateTime date, String timeStr) {
    try {
      final cleanTime = timeStr.toUpperCase().trim();
      final isPM = cleanTime.contains('PM');
      final isAM = cleanTime.contains('AM');
      final rawTimeStr = cleanTime.replaceAll(RegExp(r'[A-Z\s]'), '');
      final parts = rawTimeStr.split(':');
      if (parts.isNotEmpty) {
        int hour = int.parse(parts[0].trim());
        final int minute = parts.length > 1 ? int.parse(parts[1].trim()) : 0;
        if (isPM && hour < 12) hour += 12;
        if (isAM && hour == 12) hour = 0;
        return DateTime(date.year, date.month, date.day, hour, minute);
      }
    } catch (_) {
      // Fall through to the default below.
    }
    return DateTime(date.year, date.month, date.day, 12);
  }

  @override
  Future<void> markAsTaken(String taskId, String userId) async {
    // 1. Update the daily schedule for the UI
    await _firestore.collection('medication_schedules').doc(taskId).update({
      'status': 'completed',
      'takenAt': FieldValue.serverTimestamp(),
    });

    // 2. Fetch the task details
    final taskSnapshot = await _firestore
        .collection('medication_schedules')
        .doc(taskId)
        .get();
    final taskData = taskSnapshot.data();

    // 3. Create a permanent history receipt
    if (taskData != null) {
      await _firestore.collection('medication_logs').add({
        'userId': userId,
        'medicationName': taskData['medicationName'] ?? 'Unknown',
        'dosage': taskData['dosage'] ?? '',
        'time': taskData['reminderTime'] ?? '',
        'status': 'completed',
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Future<int> createScheduleSlots({
    required String userId,
    required String medicationName,
    required MedicationSchedulePlan plan,
    required String instructions,
  }) async {
    if (plan.slotTimes.isEmpty) return 0;

    final batch = _firestore.batch();
    final collectionRef = _firestore.collection('medication_schedules');

    for (final slot in plan.slotTimes) {
      final docRef = collectionRef.doc();
      batch.set(docRef, {
        'userId': userId,
        'medicationName': medicationName,
        'dosage': plan.dosage,
        'frequency': plan.frequencyLabel,
        'reminderTime': slot.formatted,
        'instructions': instructions,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'upcoming',
      });
    }

    await batch.commit();
    return plan.slotTimes.length;
  }
}
