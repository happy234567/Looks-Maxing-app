import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'camera_screen.dart';
import 'scan_history.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';
import 'profile_screen.dart';
import 'progress_page.dart';
import 'lock_in_page.dart';
import 'shop_page.dart';
import 'guide_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'billing_service.dart'; // Import BillingService

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  final user = FirebaseAuth.instance.currentUser;
  
  Widget initialScreen = const LoginScreen();
  
  if (user != null) {
    // Check if profile exists in Firestore
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    
    if (doc.exists) {
      // Load profile data to local storage
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

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _billingService.initialize();
    _billingService.addListener(_onBillingUpdated);
  }

  void _onBillingUpdated() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _billingService.removeListener(_onBillingUpdated);
    super.dispose();
  }

  Future<void> _loadHistory() async {
    await ScanHistory.getHistory();
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
                'Get unlimited AI scans, detailed attractiveness insights, and level-maxing track features.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 24),
              // Pricing Tiers Hardcoded display mimicking the fetched products
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
        // Find product in billing service and buy
        try {
          final product = _billingService.products
              .firstWhere((p) => p.id == productId);
          _billingService.buySubscription(product);
          Navigator.pop(context); // Close sheet
        } catch (e) {
          debugPrint('Product not found in Google Play yet: $productId');
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
      body: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.face, color: Color(0xFFFFD700), size: 90),
                  const SizedBox(height: 24),
                  const Text('Scan Your Face',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  const Text('Get your AI-powered attractiveness rating',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 14)),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const CameraScreen()));
                        _loadHistory();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD700),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text('SCAN FACE',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('View your scan history and progress in the Progress tab below', textAlign: TextAlign.center, style: TextStyle(color: Colors.white24, fontSize: 13),),
                  const SizedBox(height: 80), // Padding for bottom banner
                ],
              ),
            ),
          ),
          // ── Premium Banner ──
          if (!_billingService.isPremium)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: GestureDetector(
                onTap: _showPremiumBottomSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
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
                      Icon(Icons.workspace_premium, color: Color(0xFFFFD700), size: 36),
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
                            Text('Unlimited scans & detailed insights',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Color(0xFFFFD700)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}