// lib/features/system_health/data/repositories/appointment_repository_impl.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/appointment_summary.dart';
import '../../domain/repositories/appointment_repository.dart';

class AppointmentRepositoryImpl implements AppointmentRepository {
  AppointmentRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<List<AppointmentSummary>> watchUpcomingAppointments(
    String userId, {
    required int limit,
  }) {
    return _firestore
        .collection('appointments')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final now = DateTime.now();

          final future = snapshot.docs.where((doc) {
            final data = doc.data();
            final ts = data['dateTime'] as Timestamp?;
            return ts != null && ts.toDate().isAfter(now);
          }).toList();

          // Descending sort, then take the first `limit` — matches the
          // original exactly: this returns the *furthest-out* upcoming
          // appointments, not the soonest. Preserved as-is; see the
          // module summary.
          future.sort((a, b) {
            final aTime = (a.data()['dateTime'] as Timestamp);
            final bTime = (b.data()['dateTime'] as Timestamp);
            return bTime.compareTo(aTime);
          });

          return future
              .take(limit)
              .map((doc) => _fromFirestore(doc.id, doc.data()))
              .toList();
        });
  }

  AppointmentSummary _fromFirestore(String id, Map<String, dynamic> data) {
    return AppointmentSummary(
      id: id,
      title: data['title'] ?? 'Medical Appointment',
      doctorName: data['doctorName'] ?? '',
      location: data['location'] ?? '',
      dateTime: (data['dateTime'] as Timestamp).toDate(),
    );
  }
}
