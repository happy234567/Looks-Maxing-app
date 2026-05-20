const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();

// ═══════════════════════════════════════════════════════════════════════════════
// REUSABLE HELPER: Send push notification to a specific user
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * Sends a push notification to all devices registered for a given user.
 *
 * @param {string} userId - The Firebase Auth UID of the target user.
 * @param {string} title  - Notification title.
 * @param {string} body   - Notification body text.
 * @param {Object} [data] - Optional data payload (e.g. { screen: "progress" }).
 * @returns {Promise<{sent: number, failed: number, cleaned: number}>}
 */
async function sendPushNotification(userId, title, body, data = {}) {
  const result = { sent: 0, failed: 0, cleaned: 0 };

  try {
    const tokensSnap = await db
      .collection("users")
      .doc(userId)
      .collection("tokens")
      .get();

    if (tokensSnap.empty) {
      logger.info(`[Push] No tokens found for user ${userId} — skipping`);
      return result;
    }

    const tokens = tokensSnap.docs.map((doc) => ({
      id: doc.id,
      token: doc.data().token,
    }));

    logger.info(`[Push] Sending to ${tokens.length} device(s) for user ${userId}`);

    const sendPromises = tokens.map(async ({ id, token }) => {
      try {
        await messaging.send({
          token,
          notification: { title, body },
          data: data,
          android: {
            priority: "high",
            notification: {
              channelId: "high_importance_channel",
              priority: "max",
              defaultSound: true,
              defaultVibrateTimings: true,
            },
          },
        });
        result.sent++;
        logger.info(`[Push] ✅ Sent to token ${id.substring(0, 15)}...`);
      } catch (err) {
        result.failed++;
        const code = err.code || "";
        logger.warn(`[Push] ❌ Failed token ${id.substring(0, 15)}...: ${code}`);

        // Auto-clean invalid/expired tokens from Firestore
        if (
          code === "messaging/invalid-registration-token" ||
          code === "messaging/registration-token-not-registered" ||
          code === "messaging/invalid-argument"
        ) {
          try {
            await db
              .collection("users")
              .doc(userId)
              .collection("tokens")
              .doc(id)
              .delete();
            result.cleaned++;
            logger.info(`[Push] 🧹 Cleaned invalid token ${id.substring(0, 15)}...`);
          } catch (delErr) {
            logger.error(`[Push] Failed to clean token: ${delErr.message}`);
          }
        }
      }
    });

    await Promise.all(sendPromises);
    logger.info(
      `[Push] Done for ${userId}: sent=${result.sent} failed=${result.failed} cleaned=${result.cleaned}`
    );
  } catch (err) {
    logger.error(`[Push] sendPushNotification error: ${err.message}`);
  }

  return result;
}

/**
 * Sends a push notification to ALL users (e.g. for announcements).
 * Use sparingly — this reads every user document.
 *
 * @param {string} title - Notification title.
 * @param {string} body  - Notification body text.
 * @param {Object} [data] - Optional data payload.
 */
async function sendToAllUsers(title, body, data = {}) {
  try {
    const usersSnap = await db.collection("users").get();
    logger.info(`[Push] Broadcasting to ${usersSnap.size} users`);

    let totalSent = 0;
    let totalFailed = 0;

    for (const userDoc of usersSnap.docs) {
      const result = await sendPushNotification(userDoc.id, title, body, data);
      totalSent += result.sent;
      totalFailed += result.failed;
    }

    logger.info(`[Push] Broadcast complete: sent=${totalSent} failed=${totalFailed}`);
  } catch (err) {
    logger.error(`[Push] sendToAllUsers error: ${err.message}`);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// EVENT-TRIGGERED NOTIFICATIONS
// ═══════════════════════════════════════════════════════════════════════════════

// ── 1. SCAN RESULT READY ────────────────────────────────────────────────────
// Fires when the backend saves a new scan result to Firestore.
// Path: users/{userId}/scans/{scanId}
exports.notifyScanResult = onDocumentCreated(
  "users/{userId}/scans/{scanId}",
  async (event) => {
    const userId = event.params.userId;
    const scanData = event.data?.data();

    if (!scanData) {
      logger.warn("[notifyScanResult] No scan data — skipping");
      return;
    }

    const overall = scanData.overall || "—";
    await sendPushNotification(
      userId,
      "Your Scan Results Are Ready! 🎯",
      `Your face score is ${overall}/100. Tap to see the full breakdown.`,
      { screen: "progress" }
    );
  }
);

// ── 2. CHALLENGE COMPLETED ──────────────────────────────────────────────────
// Fires when a challenge result document is created.
// Path: users/{userId}/challenges/{challengeId}
exports.notifyChallengeComplete = onDocumentCreated(
  "users/{userId}/challenges/{challengeId}",
  async (event) => {
    const userId = event.params.userId;
    const data = event.data?.data();

    if (!data) return;

    const isEligible = data.eligible === true;
    const title = isEligible ? "🎉 Challenge Complete!" : "Challenge Finished 💪";
    const body = isEligible
      ? "You completed the challenge! You're entered into the giveaway."
      : "You completed the challenge. Keep pushing — try again next time!";

    await sendPushNotification(userId, title, body, { screen: "lockin" });
  }
);

// ═══════════════════════════════════════════════════════════════════════════════
// CALLABLE FUNCTION: Send notification from admin/server
// ═══════════════════════════════════════════════════════════════════════════════

// Can be called from Firebase Console > Extensions, or from a custom admin panel.
// Usage: { userId: "abc123", title: "Hello!", body: "Test message", screen: "scan" }
exports.sendNotification = onCall(async (request) => {
  // Only allow authenticated callers (or admin)
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in");
  }

  const { userId, title, body, screen } = request.data;

  if (!userId || !title || !body) {
    throw new HttpsError(
      "invalid-argument",
      "userId, title, and body are required"
    );
  }

  const data = screen ? { screen } : {};
  const result = await sendPushNotification(userId, title, body, data);
  return result;
});

// ═══════════════════════════════════════════════════════════════════════════════
// SCHEDULED: Stale Token Cleanup (runs daily)
// ═══════════════════════════════════════════════════════════════════════════════

// Removes FCM tokens that haven't been updated in 60+ days.
// This prevents wasted send attempts to devices that uninstalled the app.
exports.cleanupStaleTokens = onSchedule("every 24 hours", async () => {
  const cutoff = new Date();
  cutoff.setDate(cutoff.getDate() - 60); // 60 days ago

  let cleaned = 0;

  try {
    const usersSnap = await db.collection("users").get();

    for (const userDoc of usersSnap.docs) {
      const tokensSnap = await userDoc.ref.collection("tokens").get();

      for (const tokenDoc of tokensSnap.docs) {
        const data = tokenDoc.data();
        const updatedAt = data.updatedAt?.toDate?.();

        // Delete tokens with no updatedAt or updatedAt older than cutoff
        if (!updatedAt || updatedAt < cutoff) {
          await tokenDoc.ref.delete();
          cleaned++;
        }
      }
    }

    logger.info(`[Cleanup] Removed ${cleaned} stale token(s)`);
  } catch (err) {
    logger.error(`[Cleanup] cleanupStaleTokens error: ${err.message}`);
  }
});

// ═══════════════════════════════════════════════════════════════════════════════
// EXISTING: Deleted Users Cleanup (unchanged)
// ═══════════════════════════════════════════════════════════════════════════════

exports.cleanupDeletedUsers = onSchedule("every 24 hours", async () => {
  const now = new Date();
  const snapshot = await db.collection("deleted_users").get();

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const deletedAt = new Date(data.deletedAt);
    const diffDays = (now - deletedAt) / (1000 * 60 * 60 * 24);

    if (diffDays >= 7) {
      const uid = doc.id;

      try {
        await admin.auth().deleteUser(uid);
        logger.info(`Deleted auth user: ${uid}`);
      } catch (e) {
        logger.info(`Auth delete failed: ${e.message}`);
      }

      // Also clean up their FCM tokens
      try {
        const tokensSnap = await db
          .collection("users")
          .doc(uid)
          .collection("tokens")
          .get();
        for (const tokenDoc of tokensSnap.docs) {
          await tokenDoc.ref.delete();
        }
      } catch (_) {}

      await doc.ref.delete();
    }
  }
});