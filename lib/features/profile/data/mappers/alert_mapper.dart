// lib/features/profile/data/mappers/alert_mapper.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/alert.dart';

/// Converts between raw Firestore `alerts/{id}` documents and the pure
/// [Alert] domain entity (replaces the old `AlertTypeX` extension that
/// used to live directly on the domain enum).
class AlertMapper {
  const AlertMapper._();

  static Alert fromFirestore(String docId, Map<String, dynamic> data) {
    return Alert(
      id: docId,
      elderlyUserId: data['elderlyUserId'] as String,
      type: _typeFromFirestore(data['type'] as String),
      title: data['title'] as String,
      message: data['message'] as String,
      amount: (data['amount'] ?? 0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      trustedUserIds: List<String>.from(data['trustedUserIds'] ?? const []),
      isRead: data['isRead'] ?? false,
    );
  }

  static Map<String, dynamic> toFirestore(Alert alert) {
    return {
      'elderlyUserId': alert.elderlyUserId,
      'type': _typeToFirestore(alert.type),
      'title': alert.title,
      'message': alert.message,
      'amount': alert.amount,
      'trustedUserIds': alert.trustedUserIds,
      'createdAt': Timestamp.fromDate(alert.createdAt),
      'isRead': alert.isRead,
    };
  }

  static AlertType _typeFromFirestore(String raw) {
    switch (raw) {
      case 'sos':
        return AlertType.sos;
      case 'suspicious':
        return AlertType.suspicious;
      case 'spending_limit':
        return AlertType.spendingLimit;
      default:
        return AlertType.sos;
    }
  }

  static String _typeToFirestore(AlertType type) {
    switch (type) {
      case AlertType.sos:
        return 'sos';
      case AlertType.suspicious:
        return 'suspicious';
      case AlertType.spendingLimit:
        return 'spending_limit';
    }
  }
}