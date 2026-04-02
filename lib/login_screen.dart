import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart'; // Added url_launcher
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
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      // Save notification token for this user
      await NotificationService.saveTokenAfterLogin();

      // Check Firestore to see if user has completed onboarding
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      // Check if document exists AND has username field (means onboarding completed)
      if (doc.exists && doc.data()?['username'] != null && doc.data()?['username'] != '') {
        // User has completed onboarding, load their data
        final data = doc.data()!;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('username', data['username'] ?? '');
        await prefs.setString('firstName', data['firstName'] ?? '');
        await prefs.setString('gender', data['gender'] ?? '');

        // ignore: use_build_context_synchronously
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const MainNavigation()));
      } else {
        // User hasn't completed onboarding yet (new user or incomplete profile)
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const OnboardingScreen()));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // Added function to launch the legal page
  Future<void> _launchLegal() async {
    final Uri url = Uri.parse('https://happy234567.github.io/levelmaxing-legal/');
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
              const Icon(Icons.face, color: Color(0xFFFFD700), size: 100),
              const SizedBox(height: 30),
              const Text('AI-Powered Face Analysis',
                  style: TextStyle(color: Colors.white, fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text('Get brutally honest ratings\nand improve your looks',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 15)),
              const Spacer(),
              _isLoading
                  ? const CircularProgressIndicator(
                      color: Color(0xFFFFD700))
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _signInWithGoogle,
                        icon: const Icon(Icons.login),
                        label: const Text('Continue with Google',
                            style: TextStyle(fontSize: 16,
                                fontWeight: FontWeight.bold)),
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
              // Updated bottom text to be clickable
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