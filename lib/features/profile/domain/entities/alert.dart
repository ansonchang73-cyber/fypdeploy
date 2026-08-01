// lib/features/profile/domain/entities/alert.dart
//
// Domain entity representing an alert sent from an elderly user to their
// trusted (caregiver) users. No Firestore types here — string<->enum and
// Timestamp<->DateTime conversion live in `data/mappers/alert_mapper.dart`.
class Alert {
  /// Firestore document ID
  final String id;

  /// Elderly (owner) who triggered the alert
  final String elderlyUserId;

  /// Alert type
  final AlertType type;

  /// Short title shown in alert list
  final String title;

  /// Full message shown to trusted users
  final String message;

  /// Optional amount involved (0 for SOS)
  final double amount;

  /// When the alert was created
  final DateTime createdAt;

  /// Which trusted users can see this alert
  final List<String> trustedUserIds;

  /// Whether THIS trusted user has read it
  final bool isRead;

  const Alert({
    required this.id,
    required this.elderlyUserId,
    required this.type,
    required this.title,
    required this.message,
    required this.amount,
    required this.createdAt,
    required this.trustedUserIds,
    required this.isRead,
  });

  /// Copy helper (mark-as-read, etc.)
  Alert copyWith({bool? isRead}) {
    return Alert(
      id: id,
      elderlyUserId: elderlyUserId,
      type: type,
      title: title,
      message: message,
      amount: amount,
      createdAt: createdAt,
      trustedUserIds: trustedUserIds,
      isRead: isRead ?? this.isRead,
    );
  }
}

enum AlertType { sos, suspicious, spendingLimit }