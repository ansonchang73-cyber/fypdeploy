// lib/features/profile/data/repositories/adherence_reports_repository_impl.dart
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../domain/repositories/adherence_reports_repository.dart';

class AdherenceReportsRepositoryImpl implements AdherenceReportsRepository {
  AdherenceReportsRepositoryImpl(this._firestore, this._storage);

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  @override
  Future<void> publishReport({
    required String patientId,
    required String reportLabel,
    required String fileName,
    required Uint8List pdfBytes,
  }) async {
    final storageRef = _storage.ref().child(
      'adherence_reports/$patientId/${DateTime.now().millisecondsSinceEpoch}_$fileName',
    );

    final uploadTask = await storageRef.putData(
      pdfBytes,
      SettableMetadata(contentType: 'application/pdf'),
    );

    final downloadUrl = await uploadTask.ref.getDownloadURL();

    await _firestore.collection('adherence_reports').add({
      'patientId': patientId,
      'reportLabel': reportLabel,
      'storagePath': storageRef.fullPath,
      'downloadUrl': downloadUrl,
      'generatedAt': FieldValue.serverTimestamp(),
    });
  }
}
