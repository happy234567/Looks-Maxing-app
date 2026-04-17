import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PURCHASE STATUS ENUM
// Used to broadcast purchase outcomes to any listening UI widget.
// ─────────────────────────────────────────────────────────────────────────────
enum PurchaseOutcome { none, pending, success, error, canceled }

// ─────────────────────────────────────────────────────────────────────────────
// LOCALIZED COURSE PRICE HELPER
// Returns the typical influencer-course price in the user's local currency.
// Used in the "15x cheaper" marketing section of the paywall.
// ─────────────────────────────────────────────────────────────────────────────
String getLocalizedCoursePrice(String? currencyCode) {
  switch (currencyCode?.toUpperCase()) {
    case 'INR':
      return '₹4,500';
    case 'USD':
      return '\$100';
    case 'GBP':
      return '£80';
    case 'EUR':
      return '€90';
    case 'AUD':
      return 'A\$130';
    case 'CAD':
      return 'C\$120';
    default:
      // Fallback: just say "typical courses" without a price
      return 'typical courses';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BILLING SERVICE
// Singleton ChangeNotifier — call BillingService() anywhere to get the same
// instance. Call initialize() once at app startup (already done in main.dart).
// ─────────────────────────────────────────────────────────────────────────────
class BillingService extends ChangeNotifier {
  // ── Singleton setup ────────────────────────────────────────────────────────
  static final BillingService _instance = BillingService._internal();
  factory BillingService() => _instance;
  BillingService._internal();

  // ── Google Play product IDs ────────────────────────────────────────────────
  // These MUST exactly match the product IDs you created in Google Play Console.
  static const String monthlyId  = 'premium_monthly';
  static const String sixMonthId = 'premium_6month';
  static const String yearlyId   = 'premium_yearly';

  static const List<String> _productIds = [monthlyId, sixMonthId, yearlyId];

  // ── Internal state ─────────────────────────────────────────────────────────
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  bool isStoreAvailable   = false;
  bool isLoadingProducts  = false;
  bool isProcessingPurchase = false;
  String? productsLoadError;

  List<ProductDetails> products = [];
  bool isPremium = false;
  bool isLongTermPremium = false;
  String? purchasedPlanType; // '6_month' or '12_month' — used by challenge system

  /// The userId this premium state belongs to. Prevents cross-account leakage.
  String? _activeUserId;

  // Broadcast the last purchase outcome so UI widgets can react
  PurchaseOutcome lastPurchaseOutcome = PurchaseOutcome.none;
  String? lastPurchaseErrorMessage;

  // ── Convenience getters ────────────────────────────────────────────────────

  /// Returns the currency code of the first loaded product (e.g. "INR", "USD").
  /// Falls back to null if products haven't loaded yet.
  String? get currencyCode {
    if (products.isEmpty) return null;
    return products.first.currencyCode;
  }

  bool get isInitialized => isStoreAvailable;

  /// Returns the ProductDetails for a given product ID, or null if not found.
  ProductDetails? productById(String id) {
    try {
      return products.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  // ── Initialization ─────────────────────────────────────────────────────────
  Future<void> initialize() async {
    isStoreAvailable = await _iap.isAvailable();
    if (!isStoreAvailable) {
      debugPrint('[BillingService] Store not available on this device.');
      return;
    }

    // Cancel any pre-existing stream subscription before re-subscribing.
    await _purchaseSubscription?.cancel();
    _purchaseSubscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _purchaseSubscription?.cancel(),
      onError: (error) => debugPrint('[BillingService] Stream error: \$error'),
    );

    await _loadProducts();
    await _checkPremiumStatusFirebase();
  }

  // ── Account-scoped reset ───────────────────────────────────────────────────
  /// Call on every login / app start to bind premium state to the current user.
  /// Clears any stale premium flags from a previous account before fetching.
  Future<void> resetForUser(String userId) async {
    if (_activeUserId == userId) {
      // Same user, just refresh from backend
      debugPrint('[BillingService] resetForUser: same user $userId — refreshing');
      await _checkPremiumStatusFirebase();
      return;
    }

    debugPrint('[BillingService] resetForUser: switching from $_activeUserId → $userId');
    // New user — wipe all premium state first
    _clearLocalPremiumState();
    _activeUserId = userId;
    await _checkPremiumStatusFirebase();
    _logPremiumState('resetForUser complete');
  }

  /// Call on sign-out to immediately remove all premium UI.
  void clearPremiumState() {
    debugPrint('[BillingService] clearPremiumState — wiping all premium flags');
    _clearLocalPremiumState();
    _activeUserId = null;
    notifyListeners();
  }

  void _clearLocalPremiumState() {
    isPremium = false;
    isLongTermPremium = false;
    purchasedPlanType = null;
    lastPurchaseOutcome = PurchaseOutcome.none;
    lastPurchaseErrorMessage = null;
  }

  void _logPremiumState(String context) {
    debugPrint('[BillingService] [$context] userId=$_activeUserId isPremium=$isPremium isLongTermPremium=$isLongTermPremium planType=$purchasedPlanType');
  }

  // ── Product Loading ────────────────────────────────────────────────────────
  Future<void> _loadProducts() async {
    isLoadingProducts = true;
    productsLoadError = null;
    notifyListeners();

    try {
      final ProductDetailsResponse response =
          await _iap.queryProductDetails(_productIds.toSet());

      if (response.notFoundIDs.isNotEmpty) {
        debugPrint(
            '[BillingService] Products NOT found in Play Console: ${response.notFoundIDs}');
      }

      if (response.error != null) {
        productsLoadError = response.error!.message;
        debugPrint('[BillingService] Product load error: ${response.error!.message}');
      } else {
        // Sort so Monthly → 6-Month → Yearly always appears in that order in UI
        products = response.productDetails
          ..sort((a, b) => _productIds.indexOf(a.id) - _productIds.indexOf(b.id));
      }
    } catch (e) {
      productsLoadError = 'Failed to load products. Please try again.';
      debugPrint('[BillingService] Exception loading products: $e');
    } finally {
      isLoadingProducts = false;
      notifyListeners();
    }
  }

  /// Call this if the first load failed and the user taps "Retry".
  Future<void> retryLoadProducts() => _loadProducts();

  // ── Purchase Flow ──────────────────────────────────────────────────────────
  /// Triggers the Google Play subscription purchase sheet for the given product.
  Future<void> buySubscription(ProductDetails productDetails) async {
    if (isProcessingPurchase) return; // prevent double-tap
    isProcessingPurchase = true;
    lastPurchaseOutcome = PurchaseOutcome.none;
    notifyListeners();

    try {
      final GooglePlayPurchaseParam purchaseParam = GooglePlayPurchaseParam(
        productDetails: productDetails,
      );
      // All our products are subscriptions → buyNonConsumable is correct.
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      debugPrint('[BillingService] Error starting purchase: $e');
      isProcessingPurchase = false;
      lastPurchaseOutcome = PurchaseOutcome.error;
      lastPurchaseErrorMessage = 'Could not start purchase. Please try again.';
      notifyListeners();
    }
  }

  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  // ── Purchase Stream Listener ───────────────────────────────────────────────
  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    for (final PurchaseDetails purchase in purchaseDetailsList) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          lastPurchaseOutcome = PurchaseOutcome.pending;
          notifyListeners();
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _deliverProduct(purchase);
          break;

        case PurchaseStatus.error:
          isProcessingPurchase = false;
          lastPurchaseOutcome = PurchaseOutcome.error;
          lastPurchaseErrorMessage =
              purchase.error?.message ?? 'Purchase failed. Please try again.';
          notifyListeners();
          break;

        case PurchaseStatus.canceled:
          isProcessingPurchase = false;
          lastPurchaseOutcome = PurchaseOutcome.canceled;
          notifyListeners();
          break;
      }

      // Always complete the purchase to acknowledge it with Google Play.
      if (purchase.pendingCompletePurchase) {
        _iap.completePurchase(purchase);
      }
    }
  }

  Future<void> _deliverProduct(PurchaseDetails purchase) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('[BillingService] _deliverProduct: no user logged in — ignoring');
      isProcessingPurchase = false;
      notifyListeners();
      return;
    }

    // Bind to current user
    _activeUserId = user.uid;
    isPremium = true;
    isProcessingPurchase = false;
    lastPurchaseOutcome = PurchaseOutcome.success;

    // Check if this is a 6-month or 12-month plan
    final isLongTermPlan = purchase.productID == sixMonthId || 
                           purchase.productID == yearlyId;

    // Track specific plan type for challenge system
    if (purchase.productID == sixMonthId) {
      purchasedPlanType = '6_month';
    } else if (purchase.productID == yearlyId) {
      purchasedPlanType = '12_month';
    }

    _logPremiumState('_deliverProduct');
    notifyListeners();
    await _updatePremiumInFirebase(true, isLongTermPlan: isLongTermPlan, planType: purchasedPlanType);
  }

  Future<void> _updatePremiumInFirebase(bool premium, {bool isLongTermPlan = false, String? planType}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    // Safety: only write to the user we're tracking
    if (_activeUserId != null && _activeUserId != user.uid) {
      debugPrint('[BillingService] WARN: _updatePremiumInFirebase userId mismatch, aborting write');
      return;
    }
    try {
      final data = <String, dynamic>{
        'isPremium': premium,
        'isLongTermPremium': isLongTermPlan,
        'premiumUpdated': FieldValue.serverTimestamp(),
      };
      if (planType != null) data['purchasedPlanType'] = planType;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[BillingService] Firebase update error: $e');
    }
  }

  Future<void> _checkPremiumStatusFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('[BillingService] _checkPremiumStatusFirebase: no user — clearing state');
      _clearLocalPremiumState();
      notifyListeners();
      return;
    }
    // Safety: if activeUserId is set, only read for that user
    if (_activeUserId != null && _activeUserId != user.uid) {
      debugPrint('[BillingService] WARN: _checkPremiumStatusFirebase userId mismatch ($_activeUserId vs ${user.uid}), clearing');
      _clearLocalPremiumState();
      notifyListeners();
      return;
    }
    _activeUserId = user.uid;
    try {
      // Force server fetch to avoid stale cache from a previous account
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.server));
      if (doc.exists && doc.data()!['isPremium'] == true) {
        isPremium = true;
        isLongTermPremium = doc.data()!['isLongTermPremium'] == true;
        purchasedPlanType = doc.data()!['purchasedPlanType'] as String?;
      } else {
        // Explicit: user doc doesn't have premium → force free
        isPremium = false;
        isLongTermPremium = false;
        purchasedPlanType = null;
      }
      _logPremiumState('_checkPremiumStatusFirebase');
      notifyListeners();
    } catch (e) {
      debugPrint('[BillingService] Firebase check error: $e — falling back to cache');
      // Fallback to cache if server unreachable
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get(const GetOptions(source: Source.cache));
        if (doc.exists && doc.data()!['isPremium'] == true) {
          isPremium = true;
          isLongTermPremium = doc.data()!['isLongTermPremium'] == true;
          purchasedPlanType = doc.data()!['purchasedPlanType'] as String?;
        } else {
          isPremium = false;
          isLongTermPremium = false;
          purchasedPlanType = null;
        }
        _logPremiumState('_checkPremiumStatusFirebase (cache fallback)');
        notifyListeners();
      } catch (e2) {
        debugPrint('[BillingService] Cache fallback also failed: $e2 — forcing free mode');
        isPremium = false;
        isLongTermPremium = false;
        purchasedPlanType = null;
        notifyListeners();
      }
    }
  }

  // ── Cleanup ────────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }
}