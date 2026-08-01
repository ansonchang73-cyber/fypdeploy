// lib/features/profile/data/repositories/patient_repository_impl.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/appointment.dart';
import '../../domain/entities/patient_profile.dart';
import '../../domain/repositories/patient_repository.dart';
import '../mappers/appointment_mapper.dart';
import '../mappers/patient_profile_mapper.dart';

/// Firestore-backed implementation of [PatientRepository].
///
/// This consolidates two things that used to be separate, slightly
/// different implementations of the same read: the old
/// `repositories/profile_repository.dart` (`ProfileRepository`, which was
/// never actually wired up) and the direct `FirebaseFirestore.instance`
/// calls that used to live inside `PatientNotifier` in
/// `providers/patient_provider.dart`. Having two copies of "read the
/// users/{uid} doc" is what caused them to drift apart.
class PatientRepositoryImpl implements PatientRepository {
  PatientRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<PatientProfile> watchPatientProfile(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((
      snapshot,
    ) {
      if (!snapshot.exists || snapshot.data() == null) {
        throw Exception('Patient profile data not found');
      }
      return PatientProfileMapper.fromFirestore(userId, snapshot.data()!);
    });
  }

  @override
  Future<void> updateProfile(String userId, Map<String, dynamic> updates) async {
    await _firestore.collection('users').doc(userId).update(updates);
  }

  @override
  Future<void> updateAvatar(String userId, String avatarDataUrl) async {
    await _firestore.collection('users').doc(userId).update({
      'avatarUrl': avatarDataUrl,
    });
  }

  @override
  Stream<List<Appointment>> watchAppointments(
    String userId, {
    required bool isUpcoming,
  }) {
    return _firestore
        .collection('appointments')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final now = DateTime.now();
          final all = snapshot.docs
              .map((doc) => AppointmentMapper.fromFirestore(doc.id, doc.data()))
              .toList();

          final filtered = isUpcoming
              ? all.where((a) => a.dateTime.isAfter(now)).toList()
              : all.where((a) => a.dateTime.isBefore(now)).toList();

          filtered.sort((a, b) => a.dateTime.compareTo(b.dateTime));
          return filtered;
        });
  }
}