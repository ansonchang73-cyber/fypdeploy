// lib/features/caregiver_dashboard/presentation/screens/caregiver_dashboard_shell.dart
import 'package:flutter/material.dart';

import '../widgets/caregiver_bottom_nav_bar.dart';
import 'caregiver_analytics_screen.dart';
import 'caregiver_home_screen.dart';
import 'caregiver_profile_screen.dart';
import 'caregiver_storage_screen.dart';

/// The caregiver equivalent of `MainDashboardScreen` — same shell
/// pattern (an IndexedStack under a bottom nav bar), different tabs:
/// Home, Storage, Adherence Analytics, and Profile. The Profile tab used
/// to just push straight into `SettingsScreen`; it's now
/// `CaregiverProfileScreen`, which shows the linked patient(s) the same
/// way `PatientProfileScreen` shows a patient their own info, with
/// account settings still reachable from its app bar.
class CaregiverDashboardShell extends StatefulWidget {
  const CaregiverDashboardShell({super.key});

  @override
  State<CaregiverDashboardShell> createState() => _CaregiverDashboardShellState();
}

class _CaregiverDashboardShellState extends State<CaregiverDashboardShell> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = [
    CaregiverHomeScreen(),
    CaregiverStorageScreen(),
    CaregiverAnalyticsScreen(),
    CaregiverProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: CaregiverBottomNavBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }
}
