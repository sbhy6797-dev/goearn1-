const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.sendWithdrawNotification = functions.firestore
  .document("withdraw_requests/{id}")
  .onUpdate(async (change, context) => {

    const before = change.before.data();
    const after = change.after.data();

    // ✅ شغال فقط لما يتحول من pending إلى success
    if (before.status === "pending" && after.status === "success") {

      const uid = after.uid;

      const userDoc = await admin.firestore()
        .collection("users")
        .doc(uid)
        .get();

      const userData = userDoc.data();
      const token = userData?.fcmToken;

      if (!token) return null;

      const message = {
        notification: {
          title: "💸 تم تحويل الأرباح",
          body: `تم تحويل مبلغ ${after.amount} إلى حسابك (${after.account})`,
        },
        data: {
          type: "withdraw",
          amount: String(after.amount),
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        token: token,
      };

      await admin.messaging().send(message);

      console.log("✅ Notification sent successfully");

      return null;
    }

    return null;
  });