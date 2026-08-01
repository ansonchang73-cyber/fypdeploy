// lib/features/medication_management/data/repositories/hardware_sync_repository_impl.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../domain/entities/upcoming_dose_candidate.dart';
import '../../domain/repositories/hardware_sync_repository.dart';

/// Same debounce behavior as the original `MedicationSyncService`: while
/// a hardware-triggered completion transaction is in flight,
/// `checkAndSyncHardware` calls are skipped rather than queued. The
/// original used a `static bool`, shared process-wide across every call
/// site; this uses instance state instead, which has the same effect
/// since this class is wired as a single Riverpod-managed instance (see
/// `medication_management_providers.dart`) — there's still exactly one
/// flag, not one per caller.
class HardwareSyncRepositoryImpl implements HardwareSyncRepository {
  HardwareSyncRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;
  bool _isProcessingTrigger = false;

  @override
  bool get isProcessingTrigger => _isProcessingTrigger;

  @override
  void listenAndProcessHardwareTriggers(String userId) {
    _firestore.collection('users').doc(userId).snapshots().listen((
      userSnapshot,
    ) async {
      if (!userSnapshot.exists) return;
      if (_isProcessingTrigger) return;

      final userData = userSnapshot.data();
      final String hardwareTrigger =
          userData?['hardware_trigger']?.toString() ?? "0";
      final String activeTaskId = userData?['active_task_id'] ?? "";

      if (hardwareTrigger == "1" && activeTaskId.isNotEmpty) {
        _isProcessingTrigger = true;
        debugPrint("SynchroM Lock: Active hardware event processing engaged.");

        try {
          await _firestore.runTransaction((transaction) async {
            DocumentReference scheduleRef = _firestore
                .collection('medication_schedules')
                .doc(activeTaskId);

            DocumentReference userRef = _firestore.collection('users').doc(userId);

            DocumentSnapshot scheduleSnap = await transaction.get(scheduleRef);

            if (scheduleSnap.exists) {
              final String currentStatus = scheduleSnap['status'] ?? 'upcoming';

              if (currentStatus == 'upcoming') {
                transaction.update(scheduleRef, {'status': 'completed'});
                transaction.update(userRef, {
                  'active_task_id': "",
                  'hardware_trigger': 0,
                });

                DocumentReference logRef = _firestore
                    .collection('medication_logs')
                    .doc();
                transaction.set(logRef, {
                  'userId': userId,
                  'medicationName': scheduleSnap['medicationName'] ?? 'Unknown',
                  'dosage': scheduleSnap['dosage'] ?? '',
                  'time': scheduleSnap['reminderTime'] ?? '',
                  'status': 'completed',
                  'timestamp': FieldValue.serverTimestamp(),
                });
                debugPrint("SynchroM Lock: Core transaction finalized successfully.");
              }
            }
          });
        } catch (e) {
          debugPrint("Error executing atomic schedule update: $e");
        } finally {
          await Future.delayed(const Duration(milliseconds: 2000));
          _isProcessingTrigger = false;
          debugPrint("SynchroM Lock: Processing gate released.");
        }
      }
    });
  }

  @override
  Future<List<UpcomingDoseCandidate>> fetchUpcomingDoses(String userId) async {
    final querySnapshot = await _firestore
        .collection('medication_schedules')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'upcoming')
        .get();

    return querySnapshot.docs
        .map(
          (doc) => UpcomingDoseCandidate(
            id: doc.id,
            reminderTime: doc['reminderTime'] ?? "00:00",
          ),
        )
        .toList();
  }

  @override
  Future<void> setActiveTaskId(String userId, String taskId) async {
    await _firestore.collection('users').doc(userId).update({
      'active_task_id': taskId,
    });
  }
}
