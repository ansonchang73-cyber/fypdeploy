// lib/features/medication_management/data/repositories/appointment_repository_impl.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/appointment_request.dart';
import '../../domain/repositories/appointment_repository.dart';

class AppointmentRepositoryImpl implements AppointmentRepository {
  AppointmentRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<void> createAppointment(String userId, AppointmentRequest request) async {
    await _firestore.collection('appointments').add({
      'userId': userId,
      'title': request.title,
      'doctorName': request.doctorName,
      'location': request.location,
      'dateTime': Timestamp.fromDate(request.dateTime),
    });
  }

  @override
  Future<AppointmentSuggestions> fetchSuggestions(String userId) async {
    final snapshot = await _firestore
        .collection('appointments')
        .where('userId', isEqualTo: userId)
        .get();

    final Set<String> doctors = {};
    final Set<String> locations = {};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data['doctorName'] != null && data['doctorName'].toString().trim().isNotEmpty) {
        doctors.add(data['doctorName']);
      }
      if (data['location'] != null && data['location'].toString().trim().isNotEmpty) {
        locations.add(data['location']);
      }
    }

    return AppointmentSuggestions(
      doctorNames: doctors.toList(),
      locations: locations.toList(),
    );
  }
}
