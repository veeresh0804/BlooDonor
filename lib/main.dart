import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/theme/app_theme.dart';
import 'config/constants/app_constants.dart';
import 'core/services/navigation_service.dart';
import 'features/auth/logic/auth_provider.dart';
import 'features/hospital/logic/hospital_provider.dart';
import 'features/donor/logic/donor_provider.dart';
import 'features/matching/logic/matching_provider.dart';
import 'features/notifications/logic/notification_provider.dart';
import 'features/donor_journey/logic/donor_journey_provider.dart';
import 'features/auth/logic/demo_provider.dart';
import 'features/auth/presentation/auth_gate.dart';

// Uncomment if you have firebase_options.dart
// import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env (non-fatal if missing)
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    debugPrint('Warning: .env file not found or invalid');
  }

  // Initialize Firebase (skip on web/Windows where it may not be configured)
  if (!kIsWeb && defaultTargetPlatform != TargetPlatform.windows) {
    try {
      // Uncomment when firebase_options.dart is generated:
      // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      await Firebase.initializeApp(); // Assuming google-services.json is setup
    } catch (e) {
      debugPrint('Firebase init skipped: $e');
    }
  }

  // Initialize Supabase (skip if placeholder keys)
  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final supabaseKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  if (supabaseUrl.isNotEmpty &&
      !supabaseUrl.contains('placeholder') &&
      supabaseKey.isNotEmpty &&
      !supabaseKey.contains('placeholder')) {
    try {
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
    } catch (e) {
      debugPrint('Supabase init failed: $e');
    }
  } else {
    debugPrint('Supabase not configured — running in demo mode');
  }

  runApp(const BlooDonorApp());
}

class BlooDonorApp extends StatelessWidget {
  const BlooDonorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => HospitalProvider()),
        ChangeNotifierProvider(create: (_) => DonorProvider()),
        ChangeNotifierProvider(create: (_) => MatchingProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => DonorJourneyProvider()),
        ChangeNotifierProvider(create: (_) => DemoProvider()),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        navigatorKey: NavigationService.navigatorKey,
        home: const AuthGate(),
      ),
    );
  }
}
