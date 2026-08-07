// lib/core/providers/hardware_listener_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

      // 🛡️ SECURE GATE 1: Listen directly to the ESP32's hardware_trigger
      FirebaseFirestore.instance
          .collection('users')
          .doc(targetHardwareUid)
          .snapshots()
          .listen((snapshot) async {
        if (!snapshot.exists) return;
        
        final data = snapshot.data();
        if (data == null) return;

        final int trigger = data['hardware_trigger'] ?? 0;
        final String activeTaskId = data['active_task_id'] ?? '';

        // If the ESP32 button was pressed (trigger == 1) and there's a valid task...
        if (trigger == 1 && activeTaskId.isNotEmpty && activeTaskId != 'EMPTY') {
          
          // 1. Mark the active medication as taken in the app's timeline!
          await ref.read(timelineProvider.notifier).markAsTaken(activeTaskId);

          // 2. Acknowledge receipt by resetting the trigger back to 0 
          //    and clearing the active task so the ESP32 screen clears.
          await FirebaseFirestore.instance
              .collection('users')
              .doc(targetHardwareUid)
              .update({
            'hardware_trigger': 0,
            'active_task_id': 'EMPTY',
          });
          
          // 3. Run a sync to ensure the next dose is calculated immediately
          hardwareSync.checkAndSyncHardware(targetHardwareUid);
        }
      });

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