import 'package:flutter/material.dart';
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
import 'dart:ui';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

void main() async {
  // 1. WAKE UP FLUTTER FIRST
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. WAKE UP FIREBASE SECOND
  await Firebase.initializeApp();

  // 3. NOW TURN ON CRASHLYTICS
  // Pass all uncaught "fatal" errors from the framework to Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // 4. INITIALIZE ALL YOUR APP SERVICES
  await NotificationService.initialize();
  await LockInNotificationService.initialize(); // ← NEW
  await ScanCooldownService.initialize();
  
  // Make sure billing initializes so users can see your paywall!
  await BillingService().initialize(); 

  // 5. CHECK LOGGED IN USER
  final user = FirebaseAuth.instance.currentUser;
  Widget initialScreen = const LoginScreen();

  if (user != null) {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', data['username'] ?? '');
      await prefs.setString('firstName', data['firstName'] ?? '');
      await prefs.setString('gender', data['gender'] ?? '');

      // Assuming MainNavigation is defined further down in your file
      initialScreen = const MainNavigation();
    } else {
      initialScreen = const OnboardingScreen();
    }
  }

  runApp(MyApp(initialScreen: initialScreen));
}

class MyApp extends StatelessWidget {
  final Widget initialScreen;
  const MyApp({super.key, required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Level Maxing',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: initialScreen,
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

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
  bool _canScan = true;
  double _cooldownProgress = 1.0;

  @override
  void initState() {
    super.initState();
    _billingService.initialize();
    _billingService.addListener(_onBillingUpdated);
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
                'Get face scans every 5 days instead of 30, plus detailed attractiveness insights.',
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
              ? const Color(0xFFFFD700).withOpacity(0.15)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isPopular
                  ? const Color(0xFFFFD700)
                  : Colors.white.withOpacity(0.1),
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
    final cooldownLabel = isPremium ? '5-day cooldown' : '30-day cooldown';
    final barColor =
        isPremium ? const Color(0xFFFFD700) : const Color(0xFF4FC3F7);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: barColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timer_outlined, color: barColor, size: 18),
              const SizedBox(width: 8),
              Text(
                'Next Scan — $cooldownLabel',
                style: TextStyle(
                    color: barColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _cooldownProgress.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                ScanCooldownService.formatRemaining(_remaining),
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
              Text(
                '${(_cooldownProgress * 100).toStringAsFixed(0)}%',
                style: TextStyle(color: barColor, fontSize: 13),
              ),
            ],
          ),
          if (!isPremium) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _showPremiumBottomSheet,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFFFFD700).withOpacity(0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.workspace_premium,
                        color: Color(0xFFFFD700), size: 14),
                    SizedBox(width: 6),
                    Text('Upgrade for 5-day cooldown',
                        style: TextStyle(
                            color: Color(0xFFFFD700), fontSize: 12)),
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
        backgroundColor: const Color(0xFF111111),
        title: const Text('Face Rating',
            style: TextStyle(color: Color(0xFFFFD700))),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ProfilePage()));
              },
              child: CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFFFD700),
                backgroundImage:
                    FirebaseAuth.instance.currentUser?.photoURL != null
                        ? NetworkImage(
                            FirebaseAuth.instance.currentUser!.photoURL!)
                        : null,
                child: FirebaseAuth.instance.currentUser?.photoURL == null
                    ? const Icon(Icons.person, color: Colors.black, size: 20)
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const SizedBox(height: 40),
              const Icon(Icons.face, color: Color(0xFFFFD700), size: 90),
              const SizedBox(height: 24),
              const Text('Scan Your Face',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(
                _billingService.isPremium
                    ? 'Premium: 1 scan every 5 days'
                    : 'Free: 1 scan every 30 days',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canScan
                      ? () async {
                          await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const CameraScreen()));
                          await _refreshCooldown();
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: Colors.black,
                    disabledBackgroundColor:
                        const Color(0xFFFFD700).withOpacity(0.3),
                    disabledForegroundColor: Colors.black45,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                  child: Text(
                    _canScan ? 'SCAN FACE' : 'SCAN LOCKED',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Show countdown bar only when locked
              if (!_canScan) _buildCooldownBar(),

              if (_canScan)
                const Padding(
                  padding: EdgeInsets.only(bottom: 20),
                  child: Text(
                    'Your scan is ready! Tap above to analyse your face.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ),

              const SizedBox(height: 8),

              // ── Two Action Bars ─────────────────────────────────────────
              _buildActionBar(
                icon: Icons.support_agent_rounded,
                label: 'Ask Coach',
                subtitle: 'Get personalised advice',
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

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      bottomSheet: !_billingService.isPremium
          ? GestureDetector(
              onTap: _showPremiumBottomSheet,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF332A00), Color(0xFF1A1500)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  border: Border(
                      top: BorderSide(
                          color: const Color(0xFFFFD700).withOpacity(0.5),
                          width: 1)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.workspace_premium,
                        color: Color(0xFFFFD700), size: 36),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Upgrade to Premium',
                              style: TextStyle(
                                  color: Color(0xFFFFD700),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                          Text('Scan every 5 days instead of 30',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Color(0xFFFFD700)),
                  ],
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: iconColor.withOpacity(0.6), size: 15),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// ASK COACH PAGE
// ─────────────────────────────────────────────────────────────────────────────

class AskCoachPage extends StatelessWidget {
  const AskCoachPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        title: const Text('Ask Coach',
            style: TextStyle(color: Color(0xFFFFD700))),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              color: Color(0xFFFFD700), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: const Color(0xFF9C6FFF).withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: const Color(0xFF9C6FFF).withOpacity(0.4),
                      width: 2),
                ),
                child: const Icon(Icons.support_agent_rounded,
                    color: Color(0xFF9C6FFF), size: 44),
              ),
              const SizedBox(height: 28),
              const Text(
                'Coming Soon',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your AI coach is being trained to give you personalised looks-maxing advice.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white54, fontSize: 15, height: 1.6),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF9C6FFF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                      color: const Color(0xFF9C6FFF).withOpacity(0.3)),
                ),
                child: const Text(
                  '🚀  Stay tuned for updates',
                  style: TextStyle(
                      color: Color(0xFF9C6FFF),
                      fontSize: 14,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
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
                      color: const Color(0xFF4FC3F7).withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFF4FC3F7).withOpacity(0.4),
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
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.2)),
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
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.2)),
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