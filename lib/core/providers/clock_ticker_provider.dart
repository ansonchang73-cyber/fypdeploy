// lib/core/providers/clock_ticker_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Emits the current time immediately, then every 30 seconds.
///
/// Dose lateness (15/30/60-minute reminder thresholds) is computed from
/// `DateTime.now()` at build time. Without something ticking, that
/// recomputation only happens when the underlying Firestore stream emits
/// a new snapshot (i.e. when a document actually changes) — so a dose
/// could sit fully into its "second reminder" or "notify caregiver"
/// window without anything on screen ever refreshing to notice. Widgets
/// that need to catch those minute-boundary crossings should
/// `ref.watch(clockTickerProvider)` alongside their data provider purely
/// to force a rebuild; the emitted value itself is just "now".
final clockTickerProvider = StreamProvider.autoDispose<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 30), (_) => DateTime.now());
});
