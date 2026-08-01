// lib/features/profile/data/repositories/shared_access_repository_impl.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../domain/entities/alert.dart';
import '../../domain/entities/invitation_code.dart';
import '../../domain/repositories/shared_access_repository.dart';
import '../mappers/alert_mapper.dart';

class SharedAccessRepositoryImpl implements SharedAccessRepository {
  SharedAccessRepositoryImpl({required FirebaseFirestore firestore})
    : _firestore = firestore;

  final FirebaseFirestore _firestore;

  // =============================
  // ALERT ID GENERATION
  // =============================
  @override
  String generateAlertId() {
    return _firestore.collection('alerts').doc().id;
  }

  // =============================
  // INVITATION CODE
  // =============================
  @override
  Future<InvitationCode> createInvitationCode({
    required String elderlyUserId,
  }) async {
    final existing = await getActiveInvitationCode(elderlyUserId);
    if (existing != null) return existing;

    final ref = _firestore.collection("invitation_codes").doc();
    final code = ref.id.substring(0, 6);
    final expiresAt = DateTime.now().add(const Duration(minutes: 10));

    await _firestore.collection("invitation_codes").doc(code).set({
      "elderlyUserId": elderlyUserId,
      "expiresAt": Timestamp.fromDate(expiresAt),
      "used": false,
    });

    return InvitationCode(code: code, expiresAt: expiresAt);
  }

  @override
  Future<InvitationCode?> getActiveInvitationCode(String elderlyUserId) async {
    final now = Timestamp.now();

    final snap = await _firestore
        .collection("invitation_codes")
        .where("elderlyUserId", isEqualTo: elderlyUserId)
        .where("used", isEqualTo: false)
        .where("expiresAt", isGreaterThan: now)
        .orderBy("expiresAt")
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;

    final doc = snap.docs.first;
    final data = doc.data();

    return InvitationCode(
      code: doc.id,
      expiresAt: (data["expiresAt"] as Timestamp).toDate(),
    );
  }

  @override
  Future<String> validateAndConsumeInvitationCode(String code) async {
    final ref = _firestore.collection("invitation_codes").doc(code);
    final snap = await ref.get();

    if (!snap.exists) throw Exception("INVALID_CODE");

    final data = snap.data()!;
    final expiry = (data["expiresAt"] as Timestamp).toDate();
    final used = data["used"] as bool;

    if (used) throw Exception("CODE_USED");
    if (DateTime.now().isAfter(expiry)) throw Exception("CODE_EXPIRED");

    await ref.update({"used": true});

    return data["elderlyUserId"] as String;
  }

  // =============================
  // TRUSTED USER LINKING
  // =============================
  @override
  Future<void> linkTrustedUser({
    required String elderlyUserId,
    required String trustedUserId,
  }) async {
    final batch = _firestore.batch();

    final elderlyRef = _firestore
        .collection("shared_access")
        .doc(elderlyUserId)
        .collection("trusted_users")
        .doc(trustedUserId);

    final trustedRef = _firestore
        .collection("trusted_access")
        .doc(trustedUserId)
        .collection("elderly_users")
        .doc(elderlyUserId);

    final trustedUserDoc = _firestore.collection("users").doc(trustedUserId);

    batch.set(elderlyRef, {
      "trustedUserId": trustedUserId,
      "linkedAt": Timestamp.now(),
    });

    batch.set(trustedRef, {
      "elderlyUserId": elderlyUserId,
      "linkedAt": Timestamp.now(),
    });

    batch.set(trustedUserDoc, {"isTrustedUser": true}, SetOptions(merge: true));

    await batch.commit();
  }

  // =============================
  // TRUSTED USER LOOKUPS
  // =============================
  @override
  Future<List<String>> getLinkedElderlyUsers(String trustedUserId) async {
    final snap = await _firestore
        .collection("trusted_access")
        .doc(trustedUserId)
        .collection("elderly_users")
        .get();

    return snap.docs.map((d) => d.id).toList();
  }

  @override
  Future<List<String>> getTrustedUsers(String elderlyUserId) async {
    final snap = await _firestore
        .collection("shared_access")
        .doc(elderlyUserId)
        .collection("trusted_users")
        .get();

    return snap.docs.map((d) => d.id).toList();
  }

  @override
  Future<void> removeTrustedUser({
    required String elderlyUserId,
    required String trustedUserId,
  }) async {
    final batch = _firestore.batch();

    batch.delete(
      _firestore
          .collection("shared_access")
          .doc(elderlyUserId)
          .collection("trusted_users")
          .doc(trustedUserId),
    );

    batch.delete(
      _firestore
          .collection("trusted_access")
          .doc(trustedUserId)
          .collection("elderly_users")
          .doc(elderlyUserId),
    );

    await batch.commit();
  }

  // =============================
  // 🔔 ALERTS
  // =============================
  @override
  Future<void> createAlert(Alert alert) async {
    debugPrint("📝 createAlert() writing to Firestore");

    await _firestore
        .collection('alerts')
        .doc(alert.id)
        .set(AlertMapper.toFirestore(alert));

    debugPrint("📝 Firestore write DONE");
  }

  @override
  Future<int> countSpendingLimitAlertsForToday({
    required String elderlyUserId,
    required DateTime since,
  }) async {
    final snap = await _firestore
        .collection('alerts')
        .where('elderlyUserId', isEqualTo: elderlyUserId)
        .where('type', isEqualTo: 'spending_limit')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .get();

    return snap.docs.length;
  }

  @override
  Future<int> countAlerts({
    required String elderlyUserId,
    required DateTime since,
  }) async {
    final snap = await _firestore
        .collection("alerts")
        .where("elderlyUserId", isEqualTo: elderlyUserId)
        .where("createdAt", isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .get();

    return snap.docs.length;
  }

  @override
  Future<List<Alert>> getAlertsForTrustedUser({
    required String trustedUserId,
  }) async {
    final snap = await _firestore
        .collection("alerts")
        .where("trustedUserIds", arrayContains: trustedUserId)
        .orderBy("createdAt", descending: true)
        .get();

    return snap.docs
        .map((doc) => AlertMapper.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  // =============================
  // USER INFO
  // =============================
  @override
  Future<String> getElderlyName(String elderlyUserId) async {
    final doc = await _firestore.collection("users").doc(elderlyUserId).get();
    return (doc.data()?["fullName"] ?? doc.data()?["name"] ?? "Unknown")
        .toString();
  }

  @override
  Future<Map<String, dynamic>> getUserData(String userId) async {
    final doc = await _firestore.collection("users").doc(userId).get();
    return doc.data() ?? {};
  }
}