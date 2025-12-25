import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:myadds/screen/splash_screen.dart';
import 'package:myadds/screen/welcome_screen.dart';
import 'package:myadds/screen/auth/login_screen.dart';
import 'package:myadds/screen/auth/registration_screen.dart';
import 'package:myadds/screen/auth/verify_email_screen.dart';
import 'package:myadds/screen/home_screen.dart';
import 'package:myadds/screen/search_screen.dart';
import 'package:myadds/screen/business_management_screen.dart';
import 'package:myadds/screen/weather_screen.dart';
import 'package:myadds/screen/chalet_details_booking_screen.dart';
import 'package:myadds/screen/checkout_screen.dart';
import 'package:myadds/features/owner_reports/owner_reports_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'إعلاناتي',
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.grey[50],
      ),
      home: const SplashScreen(),
      routes: {
        '/welcome': (_) => const WelcomeScreen(),
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegistrationScreen(),
        '/verify': (_) => const VerifyEmailScreen(),
        '/home': (_) => const HomeScreen(),
        '/splash': (_) => const SplashScreen(),
        '/search': (_) => const SearchScreen(),
        '/weather': (_) => const WeatherScreen(),
        '/owner/manage': (_) => const BusinessManagementScreen(),
        '/chalet-details': (_) => const ChaletDetailsBookingScreen(),
        '/checkout': (_) => const CheckoutScreen(),
        '/owner/reports': (_) => const OwnerReportsScreen(),
      },
    );
  }
}
