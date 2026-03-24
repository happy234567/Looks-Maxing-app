import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BillingService extends ChangeNotifier {
  static final BillingService _instance = BillingService._internal();
  factory BillingService() => _instance;
  BillingService._internal();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  // ✅ These MUST match exactly what you created in Google Play Console
  static const String monthlyId = 'premium_monthly';
  static const String sixMonthsId = 'premium_6_months';
  static const String yearlyId = 'premium_12_months';

  final List<String> _productIds = [monthlyId, sixMonthsId, yearlyId];

  bool isAvailable = false;
  List<ProductDetails> products = [];
  bool isPremium = false;
  bool isLoading = false;

  Future<void> initialize() async {
    isAvailable = await _inAppPurchase.isAvailable();
    if (!isAvailable) {
      debugPrint('Store is not available.');
      return;
    }

    // Cancel any existing subscription before creating a new one
    await _subscription?.cancel();

    final Stream<List<PurchaseDetails>> purchaseUpdated =
        _inAppPurchase.purchaseStream;

    _subscription = purchaseUpdated.listen(
      (purchaseDetailsList) {
        _listenToPurchaseUpdated(purchaseDetailsList);
      },
      onDone: () {
        _subscription?.cancel();
      },
      onError: (error) {
        debugPrint('Purchase Stream Error: $error');
      },
    );

    await _loadProducts();
    await _checkPremiumStatusFirebase();
  }

  Future<void> _loadProducts() async {
    final ProductDetailsResponse response =
        await _inAppPurchase.queryProductDetails(_productIds.toSet());

    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('Products NOT found in Play Console: ${response.notFoundIDs}');
    }

    if (response.error == null) {
      products = response.productDetails;
      notifyListeners();
    } else {
      debugPrint('Error loading products: ${response.error!.message}');
    }
  }

  // ✅ Fixed: uses GooglePlayPurchaseParam for subscriptions
  Future<void> buySubscription(ProductDetails productDetails) async {
    try {
      final GooglePlayPurchaseParam purchaseParam = GooglePlayPurchaseParam(
        productDetails: productDetails,
      );
      await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      debugPrint('Error starting purchase: $e');
    }
  }

  Future<void> restorePurchases() async {
    await _inAppPurchase.restorePurchases();
  }

  void _listenToPurchaseUpdated(
      List<PurchaseDetails> purchaseDetailsList) {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        debugPrint('Purchase pending...');
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint('Purchase error: ${purchaseDetails.error}');
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          _deliverProduct(purchaseDetails);
        } else if (purchaseDetails.status == PurchaseStatus.canceled) {
          debugPrint('Purchase canceled by user.');
        }

        if (purchaseDetails.pendingCompletePurchase) {
          _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
  }

  Future<void> _deliverProduct(PurchaseDetails purchaseDetails) async {
    isPremium = true;
    notifyListeners();
    await _updatePremiumStatusInFirebase(true);
  }

  Future<void> _updatePremiumStatusInFirebase(bool premium) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'isPremium': premium,
          'premiumUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Error updating premium in Firebase: $e');
      }
    }
  }

  Future<void> _checkPremiumStatusFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists &&
            doc.data()!.containsKey('isPremium') &&
            doc.data()!['isPremium'] == true) {
          isPremium = true;
          notifyListeners();
        }
      } catch (e) {
        debugPrint('Error checking Firebase premium: $e');
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}