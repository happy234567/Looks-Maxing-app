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
  // PRODUCTION Rewarded Ad unit
  static const String _rewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917'; 
  
  // PRODUCTION App Open Ad unit
  static const String _appOpenAdUnitId  = 'ca-app-pub-3940256099942544/9257395921'; 

  // ── Config ─────────────────────────────────────────────────────────────────
  static const int _maxAdsPerDay   = 5;
  static const int _appOpenCooldownMinutes = 10;

  // ── State ──────────────────────────────────────────────────────────────────
  RewardedAd? _rewardedAd;
  AppOpenAd?  _appOpenAd;
  bool _isLoadingRewarded = false;
  bool _appOpenShownThisSession = false;
  DateTime? _lastAppOpenShown;
  bool _initialized = false;

  /// The userId this ad state belongs to. Prevents cross-account leakage.
  String? _activeUserId;

  // ── Init ───────────────────────────────────────────────────────────────────
  Future<void> initialize() async {
    if (_initialized) return;
    await MobileAds.instance.initialize();
    _initialized = true;
    _activeUserId = FirebaseAuth.instance.currentUser?.uid;
    debugPrint('[AdService] Initialized for user=$_activeUserId');
    _preloadRewarded();
    _preloadAppOpen();
  }

  // ── Account-scoped reset ─────────────────────────────────────────────────
  /// Call on every login / account switch to bind ad state to the current user.
  /// Resets per-session ad state so the new user starts fresh.
  void resetForUser(String userId) {
    if (_activeUserId == userId) {
      debugPrint('[AdService] resetForUser: same user $userId — no change');
      return;
    }

    debugPrint('[AdService] resetForUser: switching from $_activeUserId → $userId');
    _activeUserId = userId;

    // Reset session-level ad state for the new user
    _appOpenShownThisSession = false;
    _lastAppOpenShown = null;

    // Dispose existing preloaded ads (they may carry the old user's context)
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _appOpenAd?.dispose();
    _appOpenAd = null;
    _isLoadingRewarded = false;

    // Preload fresh ads for the new user
    _preloadRewarded();
    _preloadAppOpen();
  }

  /// Call on sign-out to immediately clear all ad state.
  void clearOnSignOut() {
    debugPrint('[AdService] clearOnSignOut — wiping ad state');
    _activeUserId = null;
    _appOpenShownThisSession = false;
    _lastAppOpenShown = null;

    _rewardedAd?.dispose();
    _rewardedAd = null;
    _appOpenAd?.dispose();
    _appOpenAd = null;
    _isLoadingRewarded = false;
  }

  // ── Daily Ad Count (Firestore, per-user) ───────────────────────────────────
  Future<int> _getTodayAdCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;
    // Safety: only read ad count for the user we're tracking
    if (_activeUserId != null && _activeUserId != user.uid) {
      debugPrint('[AdService] WARN: _getTodayAdCount userId mismatch, returning 0');
      return 0;
    }
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
    // Safety: only write ad count for the user we're tracking
    if (_activeUserId != null && _activeUserId != user.uid) {
      debugPrint('[AdService] WARN: _incrementAdCount userId mismatch, aborting');
      return;
    }
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

  // ── Rewarded Ad (20-30 sec forced) ─────────────────────────────────────────
  void _preloadRewarded() {
    if (_isLoadingRewarded) return;
    _isLoadingRewarded = true;
    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isLoadingRewarded = false;
          debugPrint('[AdService] Rewarded Ad loaded');
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _isLoadingRewarded = false;
          debugPrint('[AdService] Rewarded Ad failed: $error');
        },
      ),
    );
  }

  /// Show Rewarded Ad before scan results. Calls [onComplete] when done.
  Future<void> showScanAd({required VoidCallback onComplete}) async {
    if (!await _canShowAd()) {
      debugPrint('[AdService] Daily ad limit reached, skipping');
      onComplete();
      return;
    }

    final ad = _rewardedAd;
    if (ad == null) {
      debugPrint('[AdService] No Rewarded Ad loaded, skipping');
      onComplete();
      _preloadRewarded(); 
      return;
    }

    bool completed = false;

    void safeComplete() {
      if (!completed) {
        completed = true;
        _rewardedAd = null;
        _preloadRewarded(); 
        onComplete();
      }
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        safeComplete(); // Go to results when they close the ad
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        debugPrint('[AdService] Rewarded Ad failed to show: $error');
        safeComplete();
      },
      onAdShowedFullScreenContent: (_) {
        _incrementAdCount();
        debugPrint('[AdService] Rewarded Ad showing');
      },
    );

    // Safety timeout — if ad hangs for some reason, show results after 45s anyway
    Timer(const Duration(seconds: 45), safeComplete);

    await ad.show(onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
      debugPrint('[AdService] User earned reward! (Watched the full ad)');
      // The user successfully watched the 30 seconds! 
    });
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

  Future<void> showAppOpenAdIfReady() async {
    if (_appOpenShownThisSession) return;

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