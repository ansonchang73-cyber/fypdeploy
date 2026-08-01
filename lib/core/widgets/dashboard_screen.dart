import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'luminous_bottom_nav_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Import all your newly uploaded screen files here:
import '../../features/medication_management/presentation/screens/timeline_screen.dart';
import '../../features/system_health/presentation/screens/system_health_screen.dart';
import '../../features/profile/presentation/screens/patient_profile_screen.dart';
import '../../features/adherence_analytics/presentation/screens/adherence_analytics_screen.dart';

// StateProvider to track the active bottom navigation tab.
// `.autoDispose` matters here: without it, this is a plain global provider
// that lives for the entire app session regardless of navigation — so its
// value (e.g. 3, for the Profile tab) survives a full logout and gets read
// again on the next login, landing the user on the wrong tab. With
// `.autoDispose`, it resets back to its default (0, Home) once
// `MainDashboardScreen` is fully disposed and nothing is watching it.
final currentTabProvider = StateProvider.autoDispose<int>(
  (ref) => 0,
); // Default index 0 (Home)

class MainDashboardScreen extends ConsumerWidget {
  const MainDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(currentTabProvider);

    // ACTIVATE: Replace the text placeholders with your actual screens
    final List<Widget> screens = [
      const SystemHealthScreen(), // Index 0: Home / Smart Alerts Center
      const TimelineScreen(), // Index 1: Schedule / Today's Medication Tracker
      const AdherenceAnalyticsScreen(), // Index 2: Analytics Dashboard
      const PatientProfileScreen(), // Index 3: Profile / Alexander Henderson
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFfaf9fe), // Design system surface color
      // IndexedStack preserves the scrolling state of your forms and lists
      body: IndexedStack(index: currentIndex, children: screens),

      // Your floating glass navbar sits safely pinned right here
      bottomNavigationBar: SafeArea(
        child: LuminousBottomNavBar(
          currentIndex: currentIndex,
          onTap: (index) {
            // Switches the view dynamically when a user taps an icon
            ref.read(currentTabProvider.notifier).state = index;
          },
          userId: FirebaseAuth.instance.currentUser?.uid ?? 'fallback_guest_id',
        ),
      ),
    );
  }
}
