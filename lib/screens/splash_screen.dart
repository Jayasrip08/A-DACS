import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../main.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), _checkFirstSeen);
  }

  Future<void> _checkFirstSeen() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool seenOnboarding = (prefs.getBool('seenOnboarding') ?? false);

    if (mounted) {
      if (seenOnboarding) {
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const AuthWrapper()));
      } else {
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const OnboardingScreen()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Pure white background
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // DISPLAY LOGO IMAGE HERE
            Image.asset(
              'assets/app_logo.png', // Ensure this path matches your file exactly
              width: 180,        // Adjust width as needed
              height: 180,       // Adjust height as needed
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                // Fallback if the image fails to load
                return const Icon(Icons.school_rounded, size: 100, color: Colors.indigo);
              },
            ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack).fadeIn(),
            const SizedBox(height: 30),
            const Text(
              "A-DACS",
              style: TextStyle(
                color: Color.fromARGB(255, 198, 55, 45), // SET: App name color to red
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
              ),
            ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.3, end: 0, curve: Curves.easeOut),
            const SizedBox(height: 8),
            const Text(
              "Streamlined Clearance System",
              style: TextStyle(
                color: Colors.black54,
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.3, end: 0, curve: Curves.easeOut),
          ],
        ),
      ),
    );
  }
}