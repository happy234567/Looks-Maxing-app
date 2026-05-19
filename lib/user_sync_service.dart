import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shared utility to sync a Firestore user document into SharedPreferences.
///
/// Used by:
///   - main.dart (_initApp) — on cold start
///   - login_screen.dart (_signInWithGoogle) — after login
///
/// Eliminates duplicated sync logic and ensures consistent field handling
/// across all entry points.
class UserSyncService {
  /// Syncs user profile fields from a Firestore document snapshot into
  /// SharedPreferences. Returns `true` if onboarding is complete (age != null).
  ///
  /// Does NOT check `deleted` or `username` — the caller should do that before
  /// calling this method, as different callers handle those cases differently.
  static Future<bool> syncToLocal(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', data['username'] ?? '');
    await prefs.setString('firstName', data['firstName'] ?? '');
    await prefs.setString('gender', data['gender'] ?? '');
    if (data['age'] != null) await prefs.setInt('age', data['age'] as int);
    if (data['weight'] != null) {
      await prefs.setDouble('weight', (data['weight'] as num).toDouble());
    }
    if (data['weightUnit'] != null) {
      await prefs.setString('weightUnit', data['weightUnit'] as String);
    }
    if (data['height'] != null) {
      await prefs.setDouble('height', (data['height'] as num).toDouble());
    }
    if (data['heightUnit'] != null) {
      await prefs.setString('heightUnit', data['heightUnit'] as String);
    }

    return data['age'] != null; // true = onboarding complete
  }

  /// Fetches the user document from Firestore (cache first, server fallback)
  /// and syncs to local storage. Returns a [UserSyncResult].
  ///
  /// Throws if Firestore is unreachable and no cache is available.
  static Future<UserSyncResult> fetchAndSync(String uid, {Source source = Source.cache}) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get(GetOptions(source: source))
        .timeout(
          const Duration(seconds: 3),
          onTimeout: () => throw Exception('Firestore timeout'),
        );

    if (!doc.exists ||
        doc.data()?['deleted'] == true ||
        doc.data()?['username'] == null ||
        doc.data()?['username'] == '') {
      return UserSyncResult.needsOnboarding;
    }

    final onboardingComplete = await syncToLocal(doc.data()!);
    return onboardingComplete
        ? UserSyncResult.ready
        : UserSyncResult.needsOnboarding;
  }
}

enum UserSyncResult {
  /// User profile is fully loaded — navigate to MainNavigation
  ready,

  /// User needs onboarding (no age, no username, or doc doesn't exist)
  needsOnboarding,
}
