import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'package:firebase_core/firebase_core.dart'; 
import 'firebase_options.dart'; 
import 'core/providers/hardware_listener_provider.dart'; // ✅ IMPORT YOUR NEW LISTENER
//import 'package:google_fonts/google_fonts.dart'; // ✅ Add this import statement
// import 'features/system_health/screens/system_health_screen.dart';
// import 'features/auth/screens/login_screen.dart';
// import 'package:firebase_auth/firebase_auth.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, 
  );
  runApp(const ProviderScope(child: SynchroMApp()));
}

class SynchroMApp extends ConsumerWidget {
  const SynchroMApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ 1. Keep the background hardware bridge listening instantly at boot
    ref.watch(hardwareListenerProvider);

    // ✅ 2. Read your project's official centralized routing configuration
    final router = ref.watch(routerProvider);

    // ✅ 3. Restore the proper MaterialApp.router wrapper tree
    return MaterialApp.router(
      title: 'SynchroM',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF8F9FE),
      ),
      routerConfig: router, // 🚀 This passes control back to GoRouter!
    );
  }
}