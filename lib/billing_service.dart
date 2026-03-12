import 'dart:async';
import 'dart:io';
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
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  // The Exact Product IDs from Google Play Console
  static const String monthlyId = 'premium_monthly';
  static const String sixMonthsId = 'premium_6_months';
  static const String yearlyId = 'premium_12_months';

  final List<String> _productIds = [monthlyId, sixMonthsId, yearlyId];

  bool isAvailable = false;
  List<ProductDetails> products = [];
  bool isPremium = false; // We also check Firebase for this

  Future<void> initialize() async {
    isAvailable = await _inAppPurchase.isAvailable();
    if (!isAvailable) {
      debugPrint("Store is not available.");
      return;
    }

    // Set up the listener for incoming purchases (both new and restoring)
    final Stream<List<PurchaseDetails>> purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      debugPrint("Purchase Stream Error: $error");
    });

    // Fetch the products from Google Play
    await _loadProducts();
    
    // Also check current status from Firebase
    await _checkPremiumStatusFirebase();
  }

  Future<void> _loadProducts() async {
    final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(_productIds.toSet());
    if (response.error == null) {
      products = response.productDetails;
      // Sort so they appear in a logical order (assuming string sorting or logical mapping)
      // Usually, Google returns them in whatever order. We can map them in UI carefully.
      notifyListeners();
    } else {
      debugPrint("Error loading products from Store: ${response.error!.message}");
    }
  }

  // Trigger the actual purchase UI
  Future<void> buySubscription(ProductDetails productDetails) async {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
    
    // Specifically mapping to Google Play logic (consumable vs non_consumable vs subscription)
    // Auto-renewing subscriptions shouldn't be consumed.
    await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> restorePurchases() async {
    await _inAppPurchase.restorePurchases();
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Show pending UI
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint("Purchase error: ${purchaseDetails.error}");
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                   purchaseDetails.status == PurchaseStatus.restored) {
          
          bool valid = _verifyPurchase(purchaseDetails);
          if (valid) {
            _deliverProduct(purchaseDetails);
          }
        }
        if (purchaseDetails.pendingCompletePurchase) {
          _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
  }

  bool _verifyPurchase(PurchaseDetails purchaseDetails) {
    // In a real production app, you would send the purchase token to a secure backend 
    // to verify with Google Play Developer API so people don't spoof purchases.
    // For this implementation, we trust the client-side signal.
    return true; 
  }

  Future<void> _deliverProduct(PurchaseDetails purchaseDetails) async {
    // Subscription purchased successfully!
    isPremium = true;
    notifyListeners();

    // Securely save this to Firebase so their account is permanently marked Premium
    await _updatePremiumStatusInFirebase(true);
  }

  Future<void> _updatePremiumStatusInFirebase(bool premium) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'isPremium': premium,
          'premiumUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint("Error updating Premium status in DB: $e");
      }
    }
  }

  Future<void> _checkPremiumStatusFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data()!.containsKey('isPremium') && doc.data()!['isPremium'] == true) {
             isPremium = true;
             notifyListeners();
        }
      } catch (e) {
         debugPrint("Error checking Firebase premium status: $e");
      }
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
