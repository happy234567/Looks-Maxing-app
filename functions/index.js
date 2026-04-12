const functions = require("firebase-functions/v2");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

admin.initializeApp();

exports.cleanupDeletedUsers = onSchedule("every 24 hours", async (event) => {
  const db = admin.firestore();
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
        console.log(`Deleted auth user: ${uid}`);
      } catch (e) {
        console.log(`Auth delete failed: ${e.message}`);
      }

      await doc.ref.delete();
    }
  }
});