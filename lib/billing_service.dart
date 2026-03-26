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
      return '\$50';
    case 'GBP':
      return '£40';
    case 'EUR':
      return '€45';
    case 'AUD':
      return 'A\$70';
    case 'CAD':
      return 'C\$65';
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
  bool isLoadingProducts  = false;   // true while queryProductDetails runs
  bool isProcessingPurchase = false; // true while a purchase is in-flight
  String? productsLoadError;         // non-null if product fetch failed

  List<ProductDetails> products = [];
  bool isPremium = false;

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
      onError: (error) => debugPrint('[BillingService] Stream error: $error'),
    );

    await _loadProducts();
    await _checkPremiumStatusFirebase();
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

  // ── Deliver Product ────────────────────────────────────────────────────────
  Future<void> _deliverProduct(PurchaseDetails purchase) async {
    isPremium = true;
    isProcessingPurchase = false;
    lastPurchaseOutcome = PurchaseOutcome.success;
    notifyListeners();
    await _updatePremiumInFirebase(true);
  }

  // ── Firebase Helpers ───────────────────────────────────────────────────────
  Future<void> _updatePremiumInFirebase(bool premium) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'isPremium': premium,
        'premiumUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[BillingService] Firebase update error: $e');
    }
  }

  Future<void> _checkPremiumStatusFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists &&
          doc.data()!['isPremium'] == true) {
        isPremium = true;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[BillingService] Firebase check error: $e');
    }
  }

  // ── Cleanup ────────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }
}