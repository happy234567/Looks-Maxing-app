import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CHALLENGE DATA MODEL
// Stored at: users/{userId}/challenge/current
// ─────────────────────────────────────────────────────────────────────────────

class ChallengeData {
  String planType; // "6_month" or "12_month"
  int totalDays; // always 150
  DateTime startDate;
  int completedDays;
  double accuracy;
  int streak;
  DateTime? lastCheckIn;
  bool isActive;
  bool isCompleted;
  bool isEligible;
  bool resultNotified;

  ChallengeData({
    required this.planType,
    required this.totalDays,
    required this.startDate,
    this.completedDays = 0,
    this.accuracy = 0.0,
    this.streak = 0,
    this.lastCheckIn,
    this.isActive = true,
    this.isCompleted = false,
    this.isEligible = false,
    this.resultNotified = false,
  });

  /// Current challenge day (today - startDate + 1), clamped to totalDays
  int get challengeDay {
    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);
    final startNorm = DateTime(startDate.year, startDate.month, startDate.day);
    final day = todayNorm.difference(startNorm).inDays + 1;
    return day.clamp(1, totalDays);
  }

  /// How many calendar days have elapsed since challenge start
  int get daysElapsed {
    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);
    final startNorm = DateTime(startDate.year, startDate.month, startDate.day);
    final elapsed = todayNorm.difference(startNorm).inDays + 1;
    return elapsed.clamp(0, totalDays);
  }

  /// Days left in the challenge
  int get daysRemaining => (totalDays - daysElapsed).clamp(0, totalDays);

  /// Progress fraction (0.0 to 1.0) based on elapsed days
  double get progress =>
      totalDays > 0 ? (daysElapsed / totalDays).clamp(0.0, 1.0) : 0.0;

  /// Accuracy = completedDays / daysElapsed
  double get calculatedAccuracy =>
      daysElapsed > 0 ? (completedDays / daysElapsed).clamp(0.0, 1.0) : 0.0;

  Map<String, dynamic> toFirestore() => {
        'planType': planType,
        'totalDays': totalDays,
        'startDate': Timestamp.fromDate(startDate),
        'completedDays': completedDays,
        'accuracy': accuracy,
        'streak': streak,
        'lastCheckIn':
            lastCheckIn != null ? Timestamp.fromDate(lastCheckIn!) : null,
        'isActive': isActive,
        'isCompleted': isCompleted,
        'isEligible': isEligible,
        'resultNotified': resultNotified,
      };

  factory ChallengeData.fromFirestore(Map<String, dynamic> data) {
    DateTime startDate;
    if (data['startDate'] is Timestamp) {
      startDate = (data['startDate'] as Timestamp).toDate();
    } else {
      startDate = DateTime.now();
    }

    DateTime? lastCheckIn;
    if (data['lastCheckIn'] is Timestamp) {
      lastCheckIn = (data['lastCheckIn'] as Timestamp).toDate();
    }

    return ChallengeData(
      planType: data['planType'] ?? '6_month',
      totalDays: data['totalDays'] ?? 150,
      startDate: startDate,
      completedDays: data['completedDays'] ?? 0,
      accuracy: (data['accuracy'] ?? 0.0).toDouble(),
      streak: data['streak'] ?? 0,
      lastCheckIn: lastCheckIn,
      isActive: data['isActive'] ?? true,
      isCompleted: data['isCompleted'] ?? false,
      isEligible: data['isEligible'] ?? false,
      resultNotified: data['resultNotified'] ?? false,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CHALLENGE SERVICE — Firestore CRUD + business logic
// ─────────────────────────────────────────────────────────────────────────────

class ChallengeService {
  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static DocumentReference? get _challengeDoc => _uid == null
      ? null
      : FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('challenge')
          .doc('current');

  // ── Load current challenge from Firestore ─────────────────────────────────

  static Future<ChallengeData?> loadChallenge() async {
    try {
      if (_challengeDoc == null) return null;
      final snap = await _challengeDoc!.get();
      if (!snap.exists) return null;
      final data = snap.data() as Map<String, dynamic>?;
      if (data == null) return null;
      return ChallengeData.fromFirestore(data);
    } catch (e) {
      debugPrint('[ChallengeService] Error loading challenge: $e');
      return null;
    }
  }

  // ── Save / update current challenge ───────────────────────────────────────

  static Future<void> saveChallenge(ChallengeData challenge) async {
    try {
      if (_challengeDoc == null) return;
      await _challengeDoc!.set(challenge.toFirestore(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('[ChallengeService] Error saving challenge: $e');
    }
  }

  /// Save with server timestamp for lastCheckIn (anti-cheat)
  static Future<void> _saveWithServerTimestamp(ChallengeData challenge) async {
    try {
      if (_challengeDoc == null) return;
      final data = challenge.toFirestore();
      // Override lastCheckIn with server timestamp for integrity
      data['lastCheckIn'] = FieldValue.serverTimestamp();
      await _challengeDoc!.set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[ChallengeService] Error saving with server timestamp: $e');
    }
  }

  // ── Create a new challenge (triggered on premium purchase) ────────────────

  static Future<ChallengeData> createChallenge({
    required String planType,
  }) async {
    // Archive any existing challenge first (repurchase safety)
    await _archiveCurrentChallenge();

    const totalDays = 150; // Same 150-day giveaway for all premium plans
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day);

    final challenge = ChallengeData(
      planType: planType,
      totalDays: totalDays,
      startDate: startDate,
    );

    // Save with server timestamp for startDate
    if (_challengeDoc != null) {
      await _challengeDoc!.set({
        ...challenge.toFirestore(),
        'startDate': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Read back to get resolved server timestamp
      try {
        final snap = await _challengeDoc!.get(
          const GetOptions(source: Source.server),
        );
        if (snap.exists) {
          return ChallengeData.fromFirestore(
              snap.data() as Map<String, dynamic>);
        }
      } catch (_) {
        // If server read fails, use local time (offline case)
      }
    }

    return challenge;
  }

  // ── Archive old challenge to history (repurchase logic) ───────────────────

  static Future<void> _archiveCurrentChallenge() async {
    try {
      if (_uid == null) return;
      final current = await loadChallenge();
      if (current == null) return;

      // Move to history subcollection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('challenge_history')
          .doc() // auto-generated ID
          .set({
        ...current.toFirestore(),
        'archivedAt': FieldValue.serverTimestamp(),
      });

      // Delete current
      await _challengeDoc?.delete();
    } catch (e) {
      debugPrint('[ChallengeService] Error archiving challenge: $e');
    }
  }

  // ── Daily completion handler ──────────────────────────────────────────────
  // Called when user completes all tasks for the day.
  // Returns updated ChallengeData.

  static Future<ChallengeData?> onDayCompleted(
      ChallengeData challenge) async {
    if (!challenge.isActive || challenge.isCompleted) return challenge;

    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);
    final startNorm = DateTime(
        challenge.startDate.year, challenge.startDate.month,
        challenge.startDate.day);

    // Not yet started
    if (todayNorm.isBefore(startNorm)) return challenge;

    // Past challenge end → finalize
    final dayInChallenge = todayNorm.difference(startNorm).inDays + 1;
    if (dayInChallenge > challenge.totalDays) {
      challenge.isActive = false;
      challenge.isCompleted = true;
      challenge.accuracy = challenge.calculatedAccuracy;
      challenge.isEligible = challenge.accuracy >= 0.8;
      await _saveWithServerTimestamp(challenge);
      return challenge;
    }

    // Already checked in today → skip
    if (challenge.lastCheckIn != null) {
      final lastNorm = DateTime(challenge.lastCheckIn!.year,
          challenge.lastCheckIn!.month, challenge.lastCheckIn!.day);
      if (lastNorm.isAtSameMomentAs(todayNorm)) return challenge;
    }

    // ── Update streak ──
    if (challenge.lastCheckIn != null) {
      final lastNorm = DateTime(challenge.lastCheckIn!.year,
          challenge.lastCheckIn!.month, challenge.lastCheckIn!.day);
      final diff = todayNorm.difference(lastNorm).inDays;
      challenge.streak = (diff == 1) ? challenge.streak + 1 : 1;
    } else {
      challenge.streak = 1;
    }

    challenge.completedDays++;
    challenge.lastCheckIn = todayNorm;
    challenge.accuracy = challenge.calculatedAccuracy;

    // ── Check challenge completion ──
    if (challenge.completedDays >= challenge.totalDays) {
      challenge.isActive = false;
      challenge.isCompleted = true;
      challenge.isEligible = challenge.accuracy >= 0.8;
    }

    await _saveWithServerTimestamp(challenge);
    return challenge;
  }

  // ── Notify admin when user becomes giveaway-eligible ──────────────────────

  static Future<void> notifyAdminEligible(ChallengeData challenge) async {
    try {
      if (_uid == null) return;
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance
          .collection('giveaway_entries')
          .doc(_uid)
          .set({
        'uid': _uid,
        'email': user?.email ?? 'No Email',
        'displayName': user?.displayName ?? '',
        'timestamp': FieldValue.serverTimestamp(),
        'planType': challenge.planType,
        'totalDays': challenge.totalDays,
        'completedDays': challenge.completedDays,
        'accuracy': challenge.accuracy,
        'streak': challenge.streak,
        'isEligible': true,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[ChallengeService] Error notifying admin: $e');
    }
  }

  // ── Mark result as notified (prevent showing again) ───────────────────────

  static Future<void> markResultNotified(ChallengeData challenge) async {
    challenge.resultNotified = true;
    await saveChallenge(challenge);
  }
}
