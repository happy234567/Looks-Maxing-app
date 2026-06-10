import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'notification_service.dart';
import 'billing_service.dart';

/// Result of checking whether a deleted user's cooldown has expired.
class DeletedUserCheckResult {
  /// Whether login should be blocked.
  final bool blocked;

  /// Number of full days remaining before re-registration is allowed (0 if not blocked).
  final int daysRemaining;

  /// Human-readable message to show the user when blocked.
  final String? message;

  const DeletedUserCheckResult({
    required this.blocked,
    this.daysRemaining = 0,
    this.message,
  });
}

/// Manages account deletion cooldown to prevent abuse of delete-and-recreate.
///
/// When a user deletes their account:
///   1. Their UID + email is stored in the `deleted_users` collection
///   2. The user's Firestore data is marked as `deleted: true`
///   3. The user is signed out (but NOT deleted from Firebase Auth immediately)
///
/// When someone tries to sign in:
///   1. We check if their UID exists in `deleted_users`
///   2. If <7 days have passed -> block sign-in
///   3. If >=7 days -> allow sign-in, remove from `deleted_users`, and
///      clean up the old Firestore data
class DeletedUsersService {
  static const int cooldownDays = 7;

  static final _firestore = FirebaseFirestore.instance;
  static final _deletedUsersCol = _firestore.collection('deleted_users');

  // --- CHECK IF USER IS IN COOLDOWN ---

  /// Checks if the given [uid] is in the deleted_users cooldown window.
  ///
  /// Returns a [DeletedUserCheckResult] indicating whether login is blocked
  /// and how many days remain.
  static Future<DeletedUserCheckResult> checkCooldown(String uid) async {
    try {
      final doc = await _deletedUsersCol.doc(uid).get();

      if (!doc.exists) {
        // Not in deleted_users -> allowed to proceed
        return const DeletedUserCheckResult(blocked: false);
      }

      final data = doc.data()!;
      final deletedAtStr = data['deletedAt'] as String?;

      if (deletedAtStr == null) {
        // Corrupted entry, treat as expired - clean up
        await _deletedUsersCol.doc(uid).delete();
        return const DeletedUserCheckResult(blocked: false);
      }

      final deletedAt = DateTime.parse(deletedAtStr);
      final now = DateTime.now();
      final diff = now.difference(deletedAt);

      if (diff.inDays >= cooldownDays) {
        // Cooldown expired -> allow re-registration
        await _deletedUsersCol.doc(uid).delete();
        await _cleanupDeletedUserData(uid);
        return const DeletedUserCheckResult(blocked: false);
      } else {
        // Still in cooldown
        final remaining = cooldownDays - diff.inDays;
        return DeletedUserCheckResult(
          blocked: true,
          daysRemaining: remaining,
          message:
              'You can create your account after $remaining day${remaining == 1 ? '' : 's'}.',
        );
      }
    } catch (e) {
      debugPrint('Error checking deleted user cooldown: $e');
      return const DeletedUserCheckResult(blocked: false);
    }
  }

  // --- SOFT DELETE ACCOUNT ---

  /// Performs a soft deletion of the current user's account.
  ///
  /// 1. Deletes all face scan images from Firebase Storage
  /// 2. Stores UID + metadata in `deleted_users` collection
  /// 3. Marks the user's Firestore profile as deleted
  /// 4. Removes notification tokens
  /// 5. Clears local preferences
  /// 6. Signs out (Firebase Auth entry deleted after 7 days via Cloud Function)
  static Future<void> softDeleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final email = user.email ?? '';
    final now = DateTime.now();

    // 1. Delete all face scan images from Firebase Storage (recursive)
    // This ensures user's biometric data (face photos) is removed immediately,
    // including any nested sub-folders under the user's storage path.
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('users/$uid/scans');
      final count = await _deleteStorageRecursive(storageRef);
      debugPrint('Deleted $count scan images for UID: $uid');
    } catch (e) {
      debugPrint('Storage cleanup failed (non-fatal): $e');
    }

    // 2. Store in deleted_users collection
    await _deletedUsersCol.doc(uid).set({
      'uid': uid,
      'email': email,
      'deletedAt': now.toIso8601String(),
      'deletedAtTimestamp': Timestamp.fromDate(now),
    });

    // 3. Mark user profile as deleted
    await _firestore.collection('users').doc(uid).set({
      'deleted': true,
      'deletedAt': now.toIso8601String(),
    }, SetOptions(merge: true));

    // 4. Remove notification tokens
    try {
      await NotificationService.removeTokenOnLogout();
    } catch (_) {}

    // 5. Clear local preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // 5b. Clear premium state from singleton
    BillingService().clearPremiumState();

    // 6. Sign out (Firebase Auth entry is deleted after 7 days via Cloud Function)
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
  }

  // --- CLEANUP AFTER COOLDOWN EXPIRES ---

  /// Removes old Firestore data for a deleted user after cooldown expires.
  static Future<void> _cleanupDeletedUserData(String uid) async {
    try {
      final userRef = _firestore.collection('users').doc(uid);

      await _deleteSubcollection(userRef.collection('tokens'));
      await _deleteSubcollection(userRef.collection('scans'));
      await _deleteSubcollection(userRef.collection('data'));
      await userRef.delete();

      debugPrint('Cleaned up deleted user data for UID: $uid');
    } catch (e) {
      debugPrint('Error cleaning up deleted user data: $e');
    }
  }

  /// Recursively deletes all files under a Firebase Storage [ref],
  /// including files in nested sub-folders (prefixes).
  /// Returns the total number of files deleted.
  static Future<int> _deleteStorageRecursive(Reference ref) async {
    int deleted = 0;
    try {
      final ListResult result = await ref.listAll();
      // Delete all files at this level
      for (final item in result.items) {
        await item.delete();
        deleted++;
      }
      // Recurse into sub-folders
      for (final prefix in result.prefixes) {
        deleted += await _deleteStorageRecursive(prefix);
      }
    } catch (e) {
      debugPrint('Recursive storage delete error at ${ref.fullPath}: $e');
    }
    return deleted;
  }

  /// Deletes all documents in a subcollection.
  static Future<void> _deleteSubcollection(CollectionReference col) async {
    try {
      final snapshots = await col.limit(100).get();
      for (final doc in snapshots.docs) {
        await doc.reference.delete();
      }
      if (snapshots.docs.length == 100) {
        await _deleteSubcollection(col);
      }
    } catch (_) {}
  }

  // --- RESTORE ACCOUNT (OPTIONAL) ---

  /// Restores a soft-deleted account if still within the cooldown period.
  static Future<bool> restoreAccount(String uid) async {
    try {
      final doc = await _deletedUsersCol.doc(uid).get();
      if (!doc.exists) return false;

      await _firestore.collection('users').doc(uid).update({
        'deleted': FieldValue.delete(),
        'deletedAt': FieldValue.delete(),
        'restoredAt': DateTime.now().toIso8601String(),
      });

      await _deletedUsersCol.doc(uid).delete();

      debugPrint('Account restored for UID: $uid');
      return true;
    } catch (e) {
      debugPrint('Error restoring account: $e');
      return false;
    }
  }
}