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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await NotificationService.initialize();
  await LockInNotificationService.initialize(); // ← NEW
  await ScanCooldownService.initialize();

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
              _buildPricingCard(
                  duration: '1 Month',
                  price: '₹299',
                  description: 'Billed monthly. Cancel anytime.',
                  productId: BillingService.monthlyId),
              const SizedBox(height: 12),
              _buildPricingCard(
                  duration: '6 Months',
                  price: '₹1499',
                  description: 'Save 16%. Only ₹249/month. Billed every 6 months.',
                  productId: BillingService.sixMonthsId,
                  isPopular: true),
              const SizedBox(height: 12),
              _buildPricingCard(
                  duration: '12 Months',
                  price: '₹2799',
                  description: 'Best Value! Save 22%. Only ₹233/month. Billed annually.',
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

              const SizedBox(height: 80),
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
}