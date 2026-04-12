import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdService {
  // ── Singleton ──────────────────────────────────────────────────────────────
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  // ── Ad Unit IDs ────────────────────────────────────────────────────────────
  static const String _interstitialAdUnitId = 'ca-app-pub-1840880800077412~2473190094'; // test
  static const String _appOpenAdUnitId      = 'ca-app-pub-1840880800077412~2473190094'; // test
  // Real IDs look like: 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX'

  // ── Config ─────────────────────────────────────────────────────────────────
  static const int _maxAdsPerDay   = 5;
  static const int _appOpenCooldownMinutes = 10;

  // ── State ──────────────────────────────────────────────────────────────────
  InterstitialAd? _interstitialAd;
  AppOpenAd?      _appOpenAd;
  bool _isLoadingInterstitial = false;
  bool _appOpenShownThisSession = false;
  DateTime? _lastAppOpenShown;
  bool _initialized = false;

  // ── Init ───────────────────────────────────────────────────────────────────
  Future<void> initialize() async {
    if (_initialized) return;
    await MobileAds.instance.initialize();
    _initialized = true;
    debugPrint('[AdService] Initialized');
    _preloadInterstitial();
    _preloadAppOpen();
  }

  // ── Daily Ad Count (Firestore) ─────────────────────────────────────────────
  Future<int> _getTodayAdCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(user.uid).get();
      final data = doc.data();
      if (data == null) return 0;
      final lastReset = (data['adLastReset'] as String?);
      final today = DateTime.now().toIso8601String().substring(0, 10);
      if (lastReset != today) return 0; // new day, count resets
      return (data['adCountToday'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _incrementAdCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      await FirebaseFirestore.instance
          .collection('users').doc(user.uid)
          .set({
        'adCountToday': FieldValue.increment(1),
        'adLastReset': today,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<bool> _canShowAd() async {
    final count = await _getTodayAdCount();
    return count < _maxAdsPerDay;
  }

  // ── Interstitial ───────────────────────────────────────────────────────────
  void _preloadInterstitial() {
    if (_isLoadingInterstitial) return;
    _isLoadingInterstitial = true;
    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isLoadingInterstitial = false;
          debugPrint('[AdService] Interstitial loaded');
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          _isLoadingInterstitial = false;
          debugPrint('[AdService] Interstitial failed: $error');
        },
      ),
    );
  }

  /// Show interstitial before scan results. Calls [onComplete] when done
  /// (whether ad showed or not — results always show).
  Future<void> showScanAd({required VoidCallback onComplete}) async {
    // Skip if daily limit reached
    if (!await _canShowAd()) {
      debugPrint('[AdService] Daily ad limit reached, skipping');
      onComplete();
      return;
    }

    final ad = _interstitialAd;
    if (ad == null) {
      debugPrint('[AdService] No interstitial loaded, skipping');
      onComplete();
      _preloadInterstitial(); // load for next time
      return;
    }

    bool completed = false;

    void safeComplete() {
      if (!completed) {
        completed = true;
        _interstitialAd = null;
        _preloadInterstitial(); // preload next
        onComplete();
      }
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        safeComplete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        debugPrint('[AdService] Interstitial failed to show: $error');
        safeComplete();
      },
      onAdShowedFullScreenContent: (_) {
        _incrementAdCount();
        debugPrint('[AdService] Interstitial showing');
      },
    );

    // Safety timeout — if ad hangs, show results anyway
    Timer(const Duration(seconds: 35), safeComplete);

    await ad.show();
  }

  // ── App Open Ad ────────────────────────────────────────────────────────────
  void _preloadAppOpen() {
    AppOpenAd.load(
      adUnitId: _appOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          debugPrint('[AdService] App open ad loaded');
        },
        onAdFailedToLoad: (error) {
          _appOpenAd = null;
          debugPrint('[AdService] App open ad failed: $error');
        },
      ),
    );
  }

  /// Call this when app comes to foreground.
  /// Shows app open ad max once per session + 10 min cooldown.
  Future<void> showAppOpenAdIfReady() async {
    // Only once per session
    if (_appOpenShownThisSession) return;

    // 10 min cooldown
    if (_lastAppOpenShown != null) {
      final diff = DateTime.now().difference(_lastAppOpenShown!).inMinutes;
      if (diff < _appOpenCooldownMinutes) return;
    }

    if (!await _canShowAd()) return;

    final ad = _appOpenAd;
    if (ad == null) {
      _preloadAppOpen();
      return;
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _appOpenAd = null;
        _preloadAppOpen();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _appOpenAd = null;
        _preloadAppOpen();
      },
      onAdShowedFullScreenContent: (_) {
        _appOpenShownThisSession = true;
        _lastAppOpenShown = DateTime.now();
        _incrementAdCount();
        debugPrint('[AdService] App open ad showing');
      },
    );

    await ad.show();
  }
}