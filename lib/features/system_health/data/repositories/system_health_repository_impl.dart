// lib/features/system_health/data/repositories/system_health_repository_impl.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/system_health_state.dart';
import '../../domain/repositories/system_health_repository.dart';

/// ⚠️ `devices` is still a hardcoded pair (carried over exactly from the
/// original `systemHealthProvider`) — there's no real device-pairing
/// collection in this project yet. `activeAlerts` is likewise always
/// empty; the original left a comment noting it could later read from an
/// `alerts` subcollection, which it never did. Both preserved as-is —
/// this pass only relocates the Firestore call out of the widget layer,
/// it doesn't add the missing features.
class SystemHealthRepositoryImpl implements SystemHealthRepository {
  SystemHealthRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<SystemHealthState> watchSystemHealth(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().asyncMap((
      snapshot,
    ) async {
      final data = snapshot.data();

      // Look up the actual linked caregiver from the shared_access
      // subcollection (populated by the invitation-code linking flow),
      // instead of relying on the manually-entered 'primaryDoctor' field.
      String? caregiverName;
      try {
        final trustedUsersSnap = await _firestore
            .collection('shared_access')
            .doc(userId)
            .collection('trusted_users')
            .limit(1)
            .get();

        if (trustedUsersSnap.docs.isNotEmpty) {
          final caregiverId = trustedUsersSnap.docs.first.id;
          final caregiverDoc = await _firestore
              .collection('users')
              .doc(caregiverId)
              .get();
          final caregiverData = caregiverDoc.data();
          caregiverName = caregiverData?['fullName'] ??
              caregiverData?['name'] ??
              'Linked Caregiver';
        }
      } catch (_) {
        // If the lookup fails, fall through to the fallback below.
      }

      // Fall back to the manually-entered primaryDoctor field if no
      // linked caregiver was found via the invitation-code system.
      caregiverName ??= data?['primaryDoctor'];

      return SystemHealthState(
        isSyncing: false,
        eventsLoggedToday: data?['eventsLoggedToday'] ?? 0,
        caregiverName: caregiverName,
        activeAlerts: const [],
        devices: const [
          ConnectedDevice(name: 'Smart Watch', status: '92%'),
          ConnectedDevice(name: 'Bed Sensor', status: 'Online'),
        ],
      );
    });
  }
}

