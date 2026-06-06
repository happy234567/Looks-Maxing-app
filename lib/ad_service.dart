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

  // ── AdMob Ad Unit IDs ──────────────────────────────────────────────────────
  // PRODUCTION Rewarded Ad unit
  static const String _rewardedAdUnitId = 'ca-app-pub-1840880800077412/2124414737'; 
  
  // PRODUCTION App Open Ad unit
  static const String _appOpenAdUnitId  = 'ca-app-pub-1840880800077412/6573352674'; 



  // ── Config ─────────────────────────────────────────────────────────────────
  static const int _maxAdsPerDay   = 5;
  static const int _appOpenCooldownMinutes = 10;
  static const int _maxRetries = 3;
  static const int _retryBaseSeconds = 30; // 30s, 60s, 90s backoff

  // ── State ──────────────────────────────────────────────────────────────────
  RewardedAd? _rewardedAd;
  AppOpenAd?  _appOpenAd;
  bool _isLoadingRewarded = false;
  bool _isLoadingAppOpen  = false;
  int  _rewardedRetryCount = 0;
  int  _appOpenRetryCount  = 0;
  DateTime? _lastAppOpenShown;
  bool _initialized = false;

  // Food scan interstitial (TEST ID — swap to production before release)
  // PRODUCTION: 'ca-app-pub-1840880800077412/4819448534'
  static const String _foodInterstitialId = 'ca-app-pub-3940256099942544/1033173712';
  InterstitialAd? _foodInterstitialAd;
  bool _isLoadingFoodInterstitial = false;

  /// Timestamp when the app open ad was loaded. Ads expire after ~4 hours;
  /// we conservatively discard after 3 hours to avoid showing stale ads.
  DateTime? _appOpenAdLoadTime;
  static const int _appOpenAdMaxAgeMinutes = 180; // 3 hours

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
    preloadFoodInterstitial();
  }

  // ── Account-scoped reset ─────────────────────────────────────────────────
  /// Call on every login / account switch to bind ad state to the current user.
  /// Resets per-session ad state so the new user starts fresh.
  void resetForUser(String userId) {
    debugPrint('[AdService] resetForUser: $_activeUserId → $userId');
    _activeUserId = userId;

    // Always reset session-level ad state so the app open ad can show
    // again after a fresh app launch (even for the same user).
    _lastAppOpenShown = null;

    // Dispose existing preloaded ads (they may carry the old user's context)
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _appOpenAd?.dispose();
    _appOpenAd = null;
    _appOpenAdLoadTime = null;
    _isLoadingRewarded = false;
    _isLoadingAppOpen  = false;
    _rewardedRetryCount = 0;
    _appOpenRetryCount  = 0;

    _foodInterstitialAd?.dispose();
    _foodInterstitialAd = null;
    _isLoadingFoodInterstitial = false;

    // Preload fresh ads for the new user
    _preloadRewarded();
    _preloadAppOpen();
    preloadFoodInterstitial();
  }

  /// Call on sign-out to immediately clear all ad state.
  void clearOnSignOut() {
    debugPrint('[AdService] clearOnSignOut — wiping ad state');
    _activeUserId = null;
    _lastAppOpenShown = null;

    _rewardedAd?.dispose();
    _rewardedAd = null;
    _appOpenAd?.dispose();
    _appOpenAd = null;
    _appOpenAdLoadTime = null;
    _isLoadingRewarded = false;
    _isLoadingAppOpen  = false;
    _rewardedRetryCount = 0;
    _appOpenRetryCount  = 0;

    _foodInterstitialAd?.dispose();
    _foodInterstitialAd = null;
    _isLoadingFoodInterstitial = false;
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

  // ── AdMob Rewarded Ad (primary) ────────────────────────────────────────────

  /// Kick off a rewarded ad load early (e.g. when a scan starts) so the ad
  /// is ready by the time results arrive. No-op if one is already loaded.
  void preloadRewardedNow() {
    if (_rewardedAd != null || _isLoadingRewarded) return;
    _rewardedRetryCount = 0; // reset on explicit preload
    debugPrint('[AdService] Early preload requested — loading rewarded ad');
    _preloadRewarded();
  }

  void _preloadRewarded() {
    if (_isLoadingRewarded) return;
    _isLoadingRewarded = true;
    debugPrint('[AdService] Loading rewarded ad…');
    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isLoadingRewarded = false;
          _rewardedRetryCount = 0;
          debugPrint('[AdService] ✅ Rewarded Ad loaded');
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _isLoadingRewarded = false;
          debugPrint('[AdService] ❌ Rewarded Ad failed: $error');
          if (_rewardedRetryCount < _maxRetries) {
            _rewardedRetryCount++;
            final delay = Duration(seconds: _retryBaseSeconds * _rewardedRetryCount);
            debugPrint('[AdService] Retrying rewarded ad in ${delay.inSeconds}s (attempt $_rewardedRetryCount/$_maxRetries)');
            Future.delayed(delay, () {
              if (_rewardedAd == null && !_isLoadingRewarded) {
                _preloadRewarded();
              }
            });
          } else {
            debugPrint('[AdService] Rewarded ad retries exhausted ($_maxRetries), will reload on next trigger');
          }
        },
      ),
    );
  }



  // ── Show Rewarded Ad (AdMob + Meta AN via mediation) ──────────────────────

  /// Show Rewarded Ad before scan results. Calls [onComplete] when done.
  /// AdMob serves ads with Meta Audience Network via mediation bidding.
  Future<void> showScanAd({required VoidCallback onComplete}) async {
    if (!await _canShowAd()) {
      debugPrint('[AdService] Daily ad limit reached, skipping');
      onComplete();
      return;
    }

    // ── Try AdMob first ──
    final ad = _rewardedAd;
    if (ad != null) {
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
      return;
    }

    // ── No ad available ──
    debugPrint('[AdService] No ad available, skipping');
    onComplete();
    _preloadRewarded();
  }

  // ── App Open Ad ────────────────────────────────────────────────────────────
  void _preloadAppOpen() {
    if (_isLoadingAppOpen) return;
    _isLoadingAppOpen = true;
    debugPrint('[AdService] Loading app open ad…');
    AppOpenAd.load(
      adUnitId: _appOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          _appOpenAdLoadTime = DateTime.now();
          _isLoadingAppOpen = false;
          _appOpenRetryCount = 0;
          debugPrint('[AdService] ✅ App open ad loaded');
        },
        onAdFailedToLoad: (error) {
          _appOpenAd = null;
          _appOpenAdLoadTime = null;
          _isLoadingAppOpen = false;
          debugPrint('[AdService] ❌ App open ad failed: $error');
          if (_appOpenRetryCount < _maxRetries) {
            _appOpenRetryCount++;
            final delay = Duration(seconds: _retryBaseSeconds * _appOpenRetryCount);
            debugPrint('[AdService] Retrying app open ad in ${delay.inSeconds}s (attempt $_appOpenRetryCount/$_maxRetries)');
            Future.delayed(delay, () {
              if (_appOpenAd == null && !_isLoadingAppOpen) {
                _preloadAppOpen();
              }
            });
          } else {
            debugPrint('[AdService] App open ad retries exhausted ($_maxRetries), will reload on next trigger');
          }
        },
      ),
    );
  }

  /// Returns true if an app open ad was loaded too long ago (stale).
  bool _isAppOpenAdExpired() {
    if (_appOpenAdLoadTime == null) return true;
    return DateTime.now().difference(_appOpenAdLoadTime!).inMinutes >= _appOpenAdMaxAgeMinutes;
  }

  /// Show the app open ad if one is loaded and ready.
  /// 
  /// This method has a built-in wait: if the ad is currently loading,
  /// it will wait up to [maxWaitSeconds] for it to finish before giving up.
  /// This prevents the race condition where the ad hadn't loaded yet
  /// when called shortly after app start.
  Future<void> showAppOpenAdIfReady({int maxWaitSeconds = 8}) async {
    // Cooldown: don't spam the user
    if (_lastAppOpenShown != null) {
      final diff = DateTime.now().difference(_lastAppOpenShown!).inMinutes;
      if (diff < _appOpenCooldownMinutes) {
        debugPrint('[AdService] App open ad cooldown ($diff/${_appOpenCooldownMinutes}min), skipping');
        return;
      }
    }

    if (!await _canShowAd()) {
      debugPrint('[AdService] Daily ad limit reached, skipping app open ad');
      return;
    }

    // If the ad is still loading, wait for it (up to maxWaitSeconds)
    if (_appOpenAd == null && _isLoadingAppOpen) {
      debugPrint('[AdService] App open ad is loading, waiting up to ${maxWaitSeconds}s…');
      final deadline = DateTime.now().add(Duration(seconds: maxWaitSeconds));
      while (_isLoadingAppOpen && DateTime.now().isBefore(deadline)) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    // Check if ad is available
    final ad = _appOpenAd;
    if (ad == null) {
      debugPrint('[AdService] No app open ad available after wait, preloading for next time');
      _preloadAppOpen();
      return;
    }

    // Discard expired ads (loaded too long ago)
    if (_isAppOpenAdExpired()) {
      debugPrint('[AdService] App open ad expired (loaded $_appOpenAdLoadTime), reloading');
      ad.dispose();
      _appOpenAd = null;
      _appOpenAdLoadTime = null;
      _preloadAppOpen();
      return;
    }

    debugPrint('[AdService] Showing app open ad now');

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('[AdService] App open ad dismissed');
        ad.dispose();
        _appOpenAd = null;
        _appOpenAdLoadTime = null;
        _preloadAppOpen();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('[AdService] App open ad failed to show: $error');
        ad.dispose();
        _appOpenAd = null;
        _appOpenAdLoadTime = null;
        _preloadAppOpen();
      },
      onAdShowedFullScreenContent: (_) {
        _lastAppOpenShown = DateTime.now();
        _incrementAdCount();
        debugPrint('[AdService] ✅ App open ad showing');
      },
    );

    await ad.show();
  }

  void preloadFoodInterstitial() {
    if (_foodInterstitialAd != null || _isLoadingFoodInterstitial) return;
    _isLoadingFoodInterstitial = true;
    InterstitialAd.load(
      adUnitId: _foodInterstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _foodInterstitialAd = ad;
          _isLoadingFoodInterstitial = false;
        },
        onAdFailedToLoad: (error) {
          _foodInterstitialAd = null;
          _isLoadingFoodInterstitial = false;
          debugPrint('[AdService] Food interstitial failed: $error');
        },
      ),
    );
  }

  Future<void> showFoodScanAd({required VoidCallback onComplete}) async {
    final ad = _foodInterstitialAd;
    _foodInterstitialAd = null;
    if (ad == null) {
      onComplete();
      preloadFoodInterstitial();
      return;
    }
    bool done = false;
    void finish() {
      if (!done) {
        done = true;
        preloadFoodInterstitial();
        onComplete();
      }
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        finish();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        finish();
      },
      onAdShowedFullScreenContent: (_) => _incrementAdCount(),
    );
    Timer(const Duration(seconds: 30), finish);
    await ad.show();
  }
}