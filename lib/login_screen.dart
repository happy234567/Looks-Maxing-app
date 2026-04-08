import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'onboarding_screen.dart';
import 'main.dart';
import 'notification_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
      if (!mounted) return;

      // Save notification token for this user (with timeout)
      try {
        await NotificationService.saveTokenAfterLogin().timeout(
          const Duration(seconds: 3),
          onTimeout: () =>
              debugPrint("Notification token save timed out - offline?"),
        );
      } catch (e) {
        debugPrint("Notification save failed (offline?): $e");
      }
      if (!mounted) return;

      // Check Firestore to see if user has completed onboarding
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      try {
        // Add timeout to prevent hanging when offline
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get()
            .timeout(
              const Duration(seconds: 5),
              onTimeout: () {
                debugPrint(
                    "Firestore timeout during login - checking local cache");
                throw Exception('Firestore timeout');
              },
            );

        if (!mounted) return;

        // Check if document exists AND has username field (means onboarding completed)
        if (doc.exists &&
            doc.data()?['username'] != null &&
            doc.data()?['username'] != '') {
          final data = doc.data()!;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('username', data['username'] ?? '');
          await prefs.setString('firstName', data['firstName'] ?? '');
          await prefs.setString('gender', data['gender'] ?? '');
          if (data['age'] != null) await prefs.setInt('age', data['age'] as int);
          if (data['weight'] != null) await prefs.setDouble('weight', (data['weight'] as num).toDouble());
          if (data['weightUnit'] != null) await prefs.setString('weightUnit', data['weightUnit'] as String);
          if (data['height'] != null) await prefs.setDouble('height', (data['height'] as num).toDouble());
          if (data['heightUnit'] != null) await prefs.setString('heightUnit', data['heightUnit'] as String);

          if (!mounted) return;
          // If user hasn't completed new onboarding (no age), send to onboarding
          if (data['age'] == null) {
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => const OnboardingScreen()));
          } else {
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => const MainNavigation()));
          }
        } else {
          if (!mounted) return;
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (_) => const OnboardingScreen()));
        }
      } catch (e) {
        debugPrint("Firestore check failed: $e");

        if (!mounted) return;

        final prefs = await SharedPreferences.getInstance();
        final hasUsername = prefs.getString('username') != null &&
            prefs.getString('username') != '';

        if (!mounted) return;

        if (hasUsername) {
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (_) => const MainNavigation()));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'No internet connection. Please connect and try again.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
          setState(() => _isLoading = false);
          await FirebaseAuth.instance.signOut();
          await GoogleSignIn().signOut();
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _launchLegal() async {
    final Uri url =
        Uri.parse('https://happy234567.github.io/levelmax-legal/');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the legal page')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              const Text('LEVEL MAX',
                  style: TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4)),
              const SizedBox(height: 12),
              const Text('Unlock Your True Potential',
                  style: TextStyle(color: Colors.white54, fontSize: 16)),
              const Spacer(),
              SvgPicture.asset(
                'assets/images/logo.svg',
                width: 130,
                height: 130,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 30),
              const Text('AI-Powered Face Analysis',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text('Get brutally honest ratings\nand improve your looks',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 15)),
              const Spacer(),
              _isLoading
                  ? const CircularProgressIndicator(color: Color(0xFFFFD700))
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _signInWithGoogle,
                        icon: const Icon(Icons.login),
                        label: const Text('Continue with Google',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFD700),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                        ),
                      ),
                    ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _launchLegal,
                child: const Text(
                  'By continuing you agree to our Terms of Service & Privacy Policy',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white54,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}