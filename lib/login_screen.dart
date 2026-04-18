// ignore_for_file: deprecated_member_use

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
import 'deleted_users_service.dart';
import 'scan_cooldown_service.dart';
import 'billing_service.dart';
import 'ad_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  /// Trigger app open ad after a fresh login for free users.
  /// Called after navigating to MainNavigation so the ad appears on the main screen.
  void _triggerPostLoginAd() {
    Future.delayed(const Duration(seconds: 2), () async {
      try {
        final billing = BillingService();
        if (!billing.isPremium) {
          await AdService().showAppOpenAdIfReady();
        }
      } catch (_) {}
    });
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    
    // Add fallback timeout (5s) to prevent infinite loading
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    });

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

      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      if (!mounted) return;

      final user = userCredential.user;
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // ── CHECK DELETED USER COOLDOWN ──────────────────────────────────
      // This runs server-side against Firestore, so clearing app data
      // or reinstalling won't bypass the check.
      final cooldownResult = await DeletedUsersService.checkCooldown(user.uid);
      if (cooldownResult.blocked) {
        // Sign out immediately — they cannot use the app yet
        await FirebaseAuth.instance.signOut();
        await GoogleSignIn().signOut();
        if (!mounted) return;

        // Show a prominent dialog instead of a dismissible snackbar
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(children: [
              Icon(Icons.timer_outlined, color: Color(0xFFFFD700), size: 24),
              SizedBox(width: 10),
              Text('Account Cooldown', style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
            ]),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.hourglass_top_rounded, color: Colors.white24, size: 48),
              const SizedBox(height: 16),
              Text(
                cooldownResult.message ?? 'Please wait before creating a new account.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
              const SizedBox(height: 12),
              Text(
                'Your account was recently deleted. For security, you must wait ${cooldownResult.daysRemaining} day${cooldownResult.daysRemaining == 1 ? '' : 's'} before signing in again.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ]),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );

        if (mounted) setState(() => _isLoading = false);
        return;
      }
      // ── END COOLDOWN CHECK ───────────────────────────────────────────

      // ── CLEAR PREVIOUS USER STATE ────────────────────────────────────
      // Wipe all local caches from any previous account to prevent
      // cross-account leakage (cooldown, ads, premium).
      try {
        await ScanCooldownService.clearLocalCache();
      } catch (e) {
        debugPrint('[Login] clearLocalCache failed: $e');
      }

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

      // Sync scan cooldown from Firestore (survives sign-out/data clear)
      try {
        await ScanCooldownService.syncFromFirestore();
      } catch (e) {
        debugPrint('Scan cooldown sync failed: $e');
      }
      if (!mounted) return;

      // Bind premium state to THIS user (clears any previous account's state)
      try {
        await BillingService().resetForUser(user.uid);
      } catch (e) {
        debugPrint('[Login] BillingService resetForUser failed: $e');
      }
      if (!mounted) return;

      // Reset ad state for THIS user
      try {
        AdService().resetForUser(user.uid);
      } catch (e) {
        debugPrint('[Login] AdService resetForUser failed: $e');
      }
      if (!mounted) return;

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
        // Also check the document is not marked as deleted
        if (doc.exists &&
            doc.data()?['deleted'] != true &&
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
            // Trigger app open ad for free users after fresh login
            _triggerPostLoginAd();
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
    var withOpacity = const Color(0xFFFFD700).withOpacity(0.08);
    return Scaffold(
      backgroundColor: Colors.black, // Makes mask seamless with a dark SVG background
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(flex: 1),
                
                // Top Section: Titles
                const Text(
                  'LEVEL MAX',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Unlock Your True Potential',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                
                const Spacer(flex: 1),
                
                // Middle Section: Focused Image with Subtle Glow
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: withOpacity,
                        blurRadius: 80,
                        spreadRadius: 20,
                      ),
                    ],
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      'assets/images/logo.svg',
                      width: 250,
                      height: 250,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                
                const Spacer(flex: 1),
                
                // Bottom Section: Features & Actions
                const Text(
                  'AI-Powered Face Analysis',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Get brutally honest ratings\nand improve your looks.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                
                const Spacer(flex: 2),
                
                // Premium Button
                SizedBox(
                  height: 60, // Fixed height to maintain UI consistency and prevent layout shift
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withOpacity(0.25),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _signInWithGoogle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD700),
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: const Color(0xFFFFD700).withOpacity(0.8),
                        disabledForegroundColor: Colors.black45,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 0, // Shadow handled by Container
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.black,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.login, size: 24),
                                SizedBox(width: 12),
                                Text(
                                  'Continue with Google',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Terms & Privacy
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
                
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}