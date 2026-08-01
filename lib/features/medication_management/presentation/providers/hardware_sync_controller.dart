// lib/features/medication_management/presentation/providers/hardware_sync_controller.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'medication_management_providers.dart';

/// Replaces the old `MedicationSyncService` static class. Same two
/// operations, same shared debounce behavior (now living on
/// `HardwareSyncRepositoryImpl` instead of a static class field — see
/// that file), just callable through a provider instead of a bare static
/// class so it can be swapped/tested like everything else here.
class HardwareSyncController {
  HardwareSyncController(this._ref);
  final Ref _ref;

  void listenToHardwareTrigger(String userId) {
    _ref.read(hardwareSyncRepositoryProvider).listenAndProcessHardwareTriggers(userId);
  }

  Future<void> checkAndSyncHardware(String userId) async {
    final repository = _ref.read(hardwareSyncRepositoryProvider);
    if (repository.isProcessingTrigger) return;

    try {
      final candidates = await repository.fetchUpcomingDoses(userId);

      if (candidates.isEmpty) {
        await repository.setActiveTaskId(userId, "");
        return;
      }

      final eligibleTaskId = _ref
          .read(computeHardwareEligibleTaskProvider)
          .call(candidates, DateTime.now());

      await repository.setActiveTaskId(userId, eligibleTaskId ?? "");
    } catch (e) {
      debugPrint("Error during hardware synchronization loop: $e");
    }
  }
}

final hardwareSyncControllerProvider = Provider<HardwareSyncController>((ref) {
  return HardwareSyncController(ref);
});
