// lib/features/system_health/domain/entities/system_health_state.dart
//
// Moved from the old `providers/system_health_provider.dart` — these were
// already plain Dart classes, just living in a file that also had the
// Firestore stream mixed in. No behavior change, only location.
enum AlertSeverity { critical, warning, info }

class SystemAlert {
  final String id;
  final String title;
  final String description;
  final AlertSeverity severity;

  const SystemAlert({
    required this.id,
    required this.title,
    required this.description,
    required this.severity,
  });
}

class ConnectedDevice {
  final String name;
  final String status;
  final bool isHealthy;

  const ConnectedDevice({
    required this.name,
    required this.status,
    this.isHealthy = true,
  });
}

class SystemHealthState {
  final bool isSyncing;
  final List<SystemAlert> activeAlerts;
  final List<ConnectedDevice> devices;
  final int eventsLoggedToday;
  final String? caregiverName;

  const SystemHealthState({
    required this.isSyncing,
    required this.activeAlerts,
    required this.devices,
    required this.eventsLoggedToday,
    this.caregiverName,
  });
}
