import 'package:flutter/material.dart';
import 'notification_plugin.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'camera_screen.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';
import 'profile_screen.dart';
import 'progress_page.dart';
import 'lock_in_page.dart';
import 'shop_page.dart';
import 'guide_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'billing_service.dart';
import 'notification_service.dart';
import 'lock_in_notification_service.dart'; // ← NEW
import 'scan_cooldown_service.dart';
import 'deleted_users_service.dart';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'ad_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'user_sync_service.dart';

void main() {
  runZonedGuarded(() async {
    // 1. WAKE UP FLUTTER FIRST
    WidgetsFlutterBinding.ensureInitialized();
    
    // CUSTOM ERROR UI
    ErrorWidget.builder = (FlutterErrorDetails details) {
      bool isDebug = false;
      assert(() { isDebug = true; return true; }());
      if (isDebug) {
        return ErrorWidget(details.exception);
      }
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Material(
          color: const Color(0xFF0A0A0A),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.error_outline, color: Color(0xFFFFD700), size: 60),
                SizedBox(height: 20),
                Text('Something went wrong', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('Please try again', style: TextStyle(color: Colors.white54, fontSize: 14)),
              ],
            ),
          ),
        ),
      );
    };

    // RUN SPLASH APP IMMEDIATELY
    runApp(const SplashApp());
  }, (error, stack) {
    debugPrint('Uncaught error in runZonedGuarded: $error');
    try {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    } catch (e) {
      debugPrint('Failed to report to Crashlytics: $e');
    }
  });
}

class SplashApp extends StatelessWidget {
  const SplashApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initApp();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initApp() async {
    // 2. WAKE UP FIREBASE SECOND (with timeout)
    try {
      await Firebase.initializeApp().timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Firebase timeout'),
      );
    } catch (e) {
      debugPrint("Firebase init failed: $e");
    }

    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (_) {}

    try {
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    } catch (_) {}

    try {
      await LockInNotificationService.initialize().timeout(const Duration(seconds: 3));
      } catch (_) {}

    // Initialize FCM notifications (permissions, token, foreground/background handlers)
    try {
      // Removed the 5-second timeout because the OS permission dialog pauses 
      // execution until the user clicks Allow/Deny. 
      await NotificationService.initialize();
    } catch (e) {
      debugPrint("Notification init failed: $e");
    }


    try {
      await ScanCooldownService.initialize().timeout(const Duration(seconds: 3));
    } catch (_) {}

    try {
      await BillingService().initialize().timeout(const Duration(seconds: 5));
    } catch (_) {}

    // Scope ALL per-user state to the currently signed-in user.
    // This prevents cross-account leakage of premium, cooldown, and ad state.
    final earlyUser = FirebaseAuth.instance.currentUser;
    if (earlyUser != null) {
      // Clear stale local cache from any previous account
      try {
        await ScanCooldownService.clearLocalCache();
      } catch (_) {}

      // Re-sync cooldown from Firestore for THIS user
      try {
        await ScanCooldownService.syncFromFirestore().timeout(const Duration(seconds: 5));
      } catch (_) {}

      // Bind premium state to THIS user
      try {
        await BillingService().resetForUser(earlyUser.uid).timeout(const Duration(seconds: 5));
      } catch (_) {}
    } else {
      BillingService().clearPremiumState();
    }

    try {
      await AdService().initialize().timeout(const Duration(seconds: 5));
    } catch (_) {}

    // Scope ad state to current user
    if (earlyUser != null) {
      try {
        AdService().resetForUser(earlyUser.uid);
      } catch (_) {}
    } else {
      AdService().clearOnSignOut();
    }

    // Show app open ad after 2s delay so the ad has time to preload.
    // Only once per session, only for free users, only if already signed in.
    // If the user is on the login screen (no user), skip — the ad will be
    // triggered after login navigates to MainNavigation instead.
    Future.delayed(const Duration(seconds: 2), () async {
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          debugPrint('[AdService] No user signed in — skipping app open ad');
          return;
        }
        final billing = BillingService();
        if (!billing.isPremium) {
          await AdService().showAppOpenAdIfReady();
        }
      } catch (_) {}
    });

    final user = FirebaseAuth.instance.currentUser;
    Widget initialScreen = const LoginScreen();

    if (user != null) {
      // Check if user is in deletion cooldown
      try {
        final cooldown = await DeletedUsersService.checkCooldown(user.uid);
        if (cooldown.blocked) {
          // User is in cooldown — sign them out and force login screen
          BillingService().clearPremiumState();
          await FirebaseAuth.instance.signOut();
          initialScreen = const LoginScreen();
        } else {
          initialScreen = await _resolveUserScreen(user.uid);
        }
      } catch (_) {
        // Cooldown check failed (offline?) — fallback to normal flow
        initialScreen = await _resolveUserScreen(user.uid);
      }
    }

    if (mounted) {
      runApp(MyApp(initialScreen: initialScreen));
    }
  }

  /// Shared helper: fetch user profile from cache, sync to local, and
  /// return the correct initial screen.
  Future<Widget> _resolveUserScreen(String uid) async {
    try {
      final result = await UserSyncService.fetchAndSync(uid);
      switch (result) {
        case UserSyncResult.ready:
          return const MainNavigation();
        case UserSyncResult.needsOnboarding:
          return const OnboardingScreen();
      }
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      final hasUsername = prefs.getString('username') != null &&
          prefs.getString('username') != '';
      return hasUsername ? const MainNavigation() : const LoginScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pulsing glow icon
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Color.lerp(
                        Colors.transparent,
                        const Color(0xFFFFD700).withValues(alpha: 0.3),
                        _pulseAnimation.value,
                      )!,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.08 * _pulseAnimation.value),
                        blurRadius: 60 * _pulseAnimation.value,
                        spreadRadius: 15 * _pulseAnimation.value,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.face_retouching_natural_rounded,
                    color: Color(0xFFFFD700),
                    size: 80,
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            // Brand name
            const Text(
              'LEVEL MAX',
              style: TextStyle(
                color: Color(0xFFFFD700),
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Unlock Your True Potential',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 48),
            // Loading indicator
            SizedBox(
              width: 160,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const LinearProgressIndicator(
                  minHeight: 3,
                  backgroundColor: Color(0xFF1A1A1A),
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  final Widget initialScreen;
  const MyApp({super.key, required this.initialScreen});

  @override
  Widget build(BuildContext context) {
   return MaterialApp(
      title: 'Level Max',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      navigatorKey: navigatorKey,
      onGenerateRoute: (settings) {
        if (settings.name == '/main') {
          final tabIndex = settings.arguments as int? ?? 0;
          return MaterialPageRoute(
            builder: (_) => MainNavigation(initialTab: tabIndex),
          );
        }
        return null;
      },
      home: initialScreen,
    );
  }
}

class MainNavigation extends StatefulWidget {
  final int initialTab;
  const MainNavigation({super.key, this.initialTab = 0});
 
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}
 
class _MainNavigationState extends State<MainNavigation> {
  late int _currentIndex;
 
  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
  }

  final List<Widget> _pages = [
    const FaceRatingPage(),
    const ProgressPage(),
    const LockInPage(),
    const GuidePage(),
    const ShopPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF111111),
        selectedItemColor: const Color(0xFFFFD700),
        unselectedItemColor: Colors.white38,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.face), label: 'Face Rating'),
          BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart), label: 'Progress'),
          BottomNavigationBarItem(
              icon: Icon(Icons.lock), label: 'Lock In'),
          BottomNavigationBarItem(
              icon: Icon(Icons.book), label: 'Guide'),
          BottomNavigationBarItem(
              icon: Icon(Icons.shopping_bag_outlined), label: 'Shop'),
        ],
      ),
    );
  }
}

class FaceRatingPage extends StatefulWidget {
  const FaceRatingPage({super.key});

  @override
  State<FaceRatingPage> createState() => _FaceRatingPageState();
}

class _FaceRatingPageState extends State<FaceRatingPage> {
  final BillingService _billingService = BillingService();

  // Countdown timer state
  Duration _remaining = Duration.zero;
  bool _canScan = false; // start false — set correctly after _refreshCooldown
  bool _cooldownLoaded = false; // prevents button showing before first check
  double _cooldownProgress = 1.0;

  @override
  void initState() {
  super.initState();
  _billingService.addListener(_onBillingUpdated);
  if (!_billingService.isInitialized) _billingService.initialize();
  _refreshCooldown();
  // Tick every second for the live countdown
  _startTicker();
 }

  void _startTicker() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      await _refreshCooldown();
      return true; // keep looping
    });
  }

  Future<void> _refreshCooldown() async {
    final isPremium = _billingService.isPremium;
    final remaining =
        await ScanCooldownService.getRemainingDuration(isPremium: isPremium);
    final progress =
        await ScanCooldownService.getCooldownProgress(isPremium: isPremium);
    if (mounted) {
      setState(() {
        _remaining = remaining;
        _canScan = remaining == Duration.zero;
        _cooldownProgress = progress;
        _cooldownLoaded = true; // now safe to show button
      });
    }
  }

  void _onBillingUpdated() {
    if (mounted) {
      setState(() {});
      _refreshCooldown();
    }
  }

  @override
  void dispose() {
    _billingService.removeListener(_onBillingUpdated);
    super.dispose();
  }

  void _showPremiumBottomSheet() {
    // 1. Grab the real products dynamically from Google Play
    // ignore: prefer_typing_uninitialized_variables
    var monthly, sixMonth, yearly;
    try {
      monthly = _billingService.products.firstWhere((p) => p.id == BillingService.monthlyId);
    } catch (_) {}
    try {
      sixMonth = _billingService.products.firstWhere((p) => p.id == BillingService.sixMonthId);
    } catch (_) {}
    try {
      yearly = _billingService.products.firstWhere((p) => p.id == BillingService.yearlyId);
    } catch (_) {}

    // 2. Dynamically calculate the monthly breakdown math
    String monthlyDesc = 'Billed monthly. Cancel anytime.';
    
    String sixMonthDesc = 'Save 16%. Billed every 6 months.';
    if (sixMonth != null) {
      double monthlyRaw = sixMonth.rawPrice / 6;
      sixMonthDesc = 'Save 16%. Only ${sixMonth.currencySymbol}${monthlyRaw.toStringAsFixed(0)}/month. Billed every 6 months.';
    }
    
    String yearlyDesc = 'Best Value! Save 22%. Billed annually.';
    if (yearly != null) {
      double monthlyRaw = yearly.rawPrice / 12;
      yearlyDesc = 'Best Value! Save 22%. Only ${yearly.currencySymbol}${monthlyRaw.toStringAsFixed(0)}/month. Billed annually.';
    }

    // 3. Show the sheet with the dynamic data
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom,
              left: 20,
              right: 20,
              top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '👑 Unlock Premium',
                style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 24,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Scan without ads, plus get detailed attractiveness insights.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 24),
              
              // SMART PRICING CARDS
              _buildPricingCard(
                  duration: '1 Month',
                  price: monthly != null ? monthly.price : 'Loading...',
                  description: monthlyDesc,
                  productId: BillingService.monthlyId),
              const SizedBox(height: 12),
              _buildPricingCard(
                  duration: '6 Months',
                  price: sixMonth != null ? sixMonth.price : 'Loading...',
                  description: sixMonthDesc,
                  productId: BillingService.sixMonthId,
                  isPopular: true),
              const SizedBox(height: 12),
              _buildPricingCard(
                  duration: '12 Months',
                  price: yearly != null ? yearly.price : 'Loading...',
                  description: yearlyDesc,
                  productId: BillingService.yearlyId),
              
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPricingCard(
      {required String duration,
      required String price,
      required String description,
      required String productId,
      bool isPopular = false}) {
    return GestureDetector(
      onTap: () {
        try {
          final product = _billingService.products
              .firstWhere((p) => p.id == productId);
          _billingService.buySubscription(product);
          Navigator.pop(context);
        } catch (e) {
          debugPrint('Product not found: $productId');
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Purchase not ready yet. Check Google Play Console.',
                  style: TextStyle(color: Colors.white)),
              backgroundColor: Color(0xFF222200)));
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isPopular
              ? const Color(0xFFFFD700).withValues(alpha:0.15)
              : Colors.white.withValues(alpha:0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isPopular
                  ? const Color(0xFFFFD700)
                  : Colors.white.withValues(alpha:0.1),
              width: isPopular ? 2 : 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(duration,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      if (isPopular) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('MOST POPULAR',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        )
                      ]
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(description,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            Text(price,
                style: TextStyle(
                    color: isPopular ? const Color(0xFFFFD700) : Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // ── Countdown bar widget ─────────────────────────────────────────────────

  Widget _buildCooldownBar() {
    final isPremium = _billingService.isPremium;
    final barColor = const Color(0xFFFFD700);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: barColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.timer_outlined, color: barColor, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Next Scan Available In',
                      style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ScanCooldownService.formatRemaining(_remaining),
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: barColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: barColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${(_cooldownProgress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(color: barColor, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              )
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _cooldownProgress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: const Color(0xFF222222),
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
          if (!isPremium) ...[
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _showPremiumBottomSheet,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFFD700).withValues(alpha: 0.15),
                      const Color(0xFFFFD700).withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.workspace_premium, color: Color(0xFFFFD700), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Upgrade for ad-free scans',
                      style: TextStyle(color: Color(0xFFFFD700), fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Face Rating', style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage()));
              },
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.5), width: 2),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFFFD700).withValues(alpha: 0.2), blurRadius: 10),
                  ],
                ),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF161616),
                  child: FirebaseAuth.instance.currentUser?.photoURL != null
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: FirebaseAuth.instance.currentUser!.photoURL!,
                            width: 32, height: 32, fit: BoxFit.cover,
                            placeholder: (_, _) => const Icon(Icons.person, color: Colors.white54, size: 18),
                            errorWidget: (_, _, _) => const Icon(Icons.person, color: Colors.white54, size: 18),
                          ),
                        )
                      : const Icon(Icons.person, color: Colors.white54, size: 18),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 32),
              
              // Premium Glowing Icon
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.15), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.1),
                      blurRadius: 50,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(Icons.face_retouching_natural_rounded, color: Color(0xFFFFD700), size: 90),
              ),
              
              const SizedBox(height: 32),
              
              const Text('Scan Your Face',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.0)),
              const SizedBox(height: 8),
              
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF161616),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _billingService.isPremium ? Icons.workspace_premium : Icons.stars_rounded,
                      color: _billingService.isPremium ? const Color(0xFFFFD700) : Colors.white54,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _billingService.isPremium ? 'Premium: 1 scan every 24 hours' : 'Free: 1 scan every 24 hours',
                      style: TextStyle(
                        color: _billingService.isPremium ? const Color(0xFFFFD700) : Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 48),
              
              // CTA Button Area
              if (!_canScan) _buildCooldownBar(),
              
              if (_canScan) ...[
                 Container(
                  width: double.infinity,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _cooldownLoaded ? () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const CameraScreen()));
                      await _refreshCooldown();
                    } : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD700),
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!_billingService.isPremium) ...[
                          const Icon(Icons.play_circle_filled_rounded, size: 22),
                          const SizedBox(width: 10),
                          const Text(
                            'WATCH AD & SCAN',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 0.5),
                          ),
                        ] else ...[
                          const Text(
                            'START SCAN',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 0.5),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _billingService.isPremium
                      ? 'Your scan is ready! Tap above to analyse your face.'
                      : 'Watch a short ad to unlock your face scan.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
              
              const SizedBox(height: 32),
              
              // ── Action Bars ─────────────────────────────────────────
              _buildActionBar(
                icon: Icons.psychology_rounded,
                label: 'Ask Coach',
                subtitle: 'Your personal looks advisor',
                iconColor: const Color(0xFF9C6FFF),
                borderColor: const Color(0xFF9C6FFF),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AskCoachPage())),
              ),

              const SizedBox(height: 12),

              _buildActionBar(
                icon: Icons.info_outline_rounded,
                label: 'How to Use Scan',
                subtitle: 'Tips for accurate results',
                iconColor: const Color(0xFF4FC3F7),
                borderColor: const Color(0xFF4FC3F7),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const HowToScanPage())),
              ),

              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: !_billingService.isPremium
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: GestureDetector(
                onTap: _showPremiumBottomSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2A2200), Color(0xFF141000)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.4), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Row(
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0x26FFD700),
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.workspace_premium, color: Color(0xFFFFD700), size: 28),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Upgrade to Premium', style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.w800, fontSize: 16)),
                            SizedBox(height: 2),
                            Text('Ad-free scans & detailed insights', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFFFD700), size: 16),
                    ],
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildActionBar({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color iconColor,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF161616),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: iconColor.withValues(alpha: 0.2)),
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withValues(alpha: 0.6), size: 14),
            ),
          ],
        ),
      ),
    );
  }
}


// ASK COACH — COMING SOON PAGE
// ─────────────────────────────────────────────────────────────────────────────

class AskCoachPage extends StatefulWidget {
  const AskCoachPage({super.key});

  @override
  State<AskCoachPage> createState() => _AskCoachPageState();
}

class _AskCoachPageState extends State<AskCoachPage> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  bool _notifyPressed = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF9C6FFF);
    const gold = Color(0xFFFFD700);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        title: const Text('Ask Coach', style: TextStyle(color: purple)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: purple, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
        child: Column(
          children: [
            // ── Animated brain icon ──
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (context, child) {
                return Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: purple.withValues(alpha: 0.06),
                    border: Border.all(
                      color: purple.withValues(alpha: 0.2 * _pulseAnim.value),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: purple.withValues(alpha: 0.08 * _pulseAnim.value),
                        blurRadius: 60 * _pulseAnim.value,
                        spreadRadius: 15 * _pulseAnim.value,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.psychology_rounded, color: purple, size: 72),
                );
              },
            ),

            const SizedBox(height: 28),

            // ── Title ──
            const Text(
              'Your Coach is\nBeing Trained',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                height: 1.2,
              ),
            ),

            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: purple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: purple.withValues(alpha: 0.3)),
              ),
              child: const Text(
                'COMING SOON',
                style: TextStyle(
                  color: purple,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'We\'re building an AI-powered looks coach that learns your face, understands your goals, and gives you a personalized action plan.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 14, height: 1.5),
            ),

            const SizedBox(height: 32),



            // ── Feature preview cards ──
            const _CoachFeatureCard(
              icon: Icons.auto_fix_high_rounded,
              title: 'Personalized Tips',
              description: 'Get specific advice based on your unique facial features and scores',
              color: gold,
            ),
            const SizedBox(height: 12),
            const _CoachFeatureCard(
              icon: Icons.calendar_month_rounded,
              title: 'Daily Routine',
              description: 'Custom skincare and grooming routines tailored to your needs',
              color: Color(0xFF4FC3F7),
            ),
            const SizedBox(height: 12),
            const _CoachFeatureCard(
              icon: Icons.shopping_bag_rounded,
              title: 'Product Recommendations',
              description: 'Curated product suggestions matched to your face analysis',
              color: Color(0xFF66BB6A),
            ),

            const SizedBox(height: 32),

            // ── Notify Me button ──
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _notifyPressed
                    ? null
                    : () {
                        setState(() => _notifyPressed = true);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('🔔 We\'ll notify you when Coach is ready!'),
                            backgroundColor: Color(0xFF1A1A1A),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _notifyPressed ? const Color(0xFF222222) : purple,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF222222),
                  disabledForegroundColor: Colors.white54,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_notifyPressed ? Icons.check_circle : Icons.notifications_active_rounded, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      _notifyPressed ? 'You\'ll Be Notified' : 'Notify Me When Ready',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoachFeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _CoachFeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(description,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12.5, height: 1.3)),
              ],
            ),
          ),
          Icon(Icons.lock_outline_rounded, color: color.withValues(alpha: 0.4), size: 18),
        ],
      ),
    );
  }
}


// HOW TO USE SCAN PAGE
// ─────────────────────────────────────────────────────────────────────────────

class HowToScanPage extends StatelessWidget {
  const HowToScanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        title: const Text('How to Use Scan',
            style: TextStyle(color: Color(0xFFFFD700))),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              color: Color(0xFFFFD700), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Center(
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4FC3F7).withValues(alpha:0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFF4FC3F7).withValues(alpha:0.4),
                          width: 1.5),
                    ),
                    child: const Icon(Icons.camera_alt_outlined,
                        color: Color(0xFF4FC3F7), size: 30),
                  ),
                  const SizedBox(height: 14),
                  const Text('How to Get Accurate Results',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text(
                      'Follow these tips every scan for consistent scores',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38, fontSize: 13)),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // DO section
            _buildSectionCard(
              title: '✅  Do This',
              color: const Color(0xFF4CAF50),
              items: const [
                'Use the same camera for every scan',
                'Keep the same background each time',
                'Maintain the same angle and distance',
                'Ensure consistent lighting (prefer natural light)',
                'Keep a neutral face — no expressions',
                'Scan without makeup or filters',
              ],
            ),

            const SizedBox(height: 14),

            // DON'T section
            _buildSectionCard(
              title: "❌  Don't Do This",
              color: const Color(0xFFEF5350),
              items: const [
                'Change camera or device frequently',
                'Use different backgrounds or messy surroundings',
                'Tilt your face or change angles',
                'Scan in poor or uneven lighting',
                'Apply makeup, filters, or edits',
              ],
            ),

            const SizedBox(height: 14),

            // Scoring info
            _buildInfoCard(
              icon: Icons.info_outline_rounded,
              title: 'How Your Score Works',
              color: const Color(0xFFFFD700),
              content:
                  'Your final score is a blend of two equal metrics:\n\n'
                  '• 50% Appeal — overall facial harmony, skin, and aesthetic impression\n\n'
                  '• 50% PSL — scientific bone structure metrics including jawline, cheekbones, symmetry, and proportions\n\n'
                  'Scores are computer-generated estimates and not absolute measures of beauty.',
            ),

            const SizedBox(height: 14),

            // Disclaimer
            _buildInfoCard(
              icon: Icons.shield_outlined,
              title: 'Safety Disclaimer',
              color: const Color(0xFF9C6FFF),
              content:
                  'This feature is designed for entertainment and self-analysis purposes only. '
                  'Results should not be taken as definitive judgments of personal appearance or worth.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required Color color,
    required List<String> items,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha:0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 5),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                          color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(item,
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              height: 1.4)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required Color color,
    required String content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha:0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(title,
                style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 12),
          Text(content,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 14, height: 1.6)),
        ],
      ),
    );
  }
}