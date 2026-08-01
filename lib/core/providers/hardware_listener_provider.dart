import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../features/medication_management/presentation/providers/timeline_provider.dart';
import '../../features/medication_management/presentation/providers/hardware_sync_controller.dart';

class HardwareListener extends Notifier<void> {
  static const String targetHardwareUid = "zoHqSaXjCwSXiIJBgkDhBF4SNUE3";

  @override
  void build() {
    _initializeSecureHardwareBridge();
  }

  void _initializeSecureHardwareBridge() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user == null) return;

      final hardwareSync = ref.read(hardwareSyncControllerProvider);

      // 🛡️ SECURE GATE 1: Route the hardware switch listener exclusively through the transaction engine
      hardwareSync.listenToHardwareTrigger(targetHardwareUid);

      // Run an initial strict time check when the database first connects
      final timelineAsync = ref.read(timelineProvider);
      timelineAsync.whenData((tasks) {
        hardwareSync.checkAndSyncHardware(targetHardwareUid);
      });

      // 🛡️ SECURE GATE 2: Whenever the app schedule timeline updates or repaints,
      // hand over evaluation strictly to the proximity sync service instead of guessing!
      ref.listen(timelineProvider, (previous, next) {
        next.whenData((tasks) {
          hardwareSync.checkAndSyncHardware(targetHardwareUid);
        });
      });
    });
  }
}

final hardwareListenerProvider = NotifierProvider<HardwareListener, void>(() {
  return HardwareListener();
});