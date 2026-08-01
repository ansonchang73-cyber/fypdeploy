// lib/features/system_health/presentation/providers/today_ui_state_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Purely ephemeral UI state — not business logic, so these stay as
/// simple `StateProvider`s rather than moving into the domain/data
/// layers. Relocated from the top of the old `system_health_screen.dart`
/// unchanged.
final todayExpandedProvider = StateProvider.autoDispose<bool>((ref) => false);

final activePromptTaskIdProvider = StateProvider.autoDispose<String?>((ref) => null);
