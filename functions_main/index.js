const { onDocumentUpdated, onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { onRequest } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const axios = require("axios");
const SECRET = "CPX_SECRET_9x3K2L1mQz_2026";
const crypto = require("crypto");
admin.initializeApp();
const messaging = admin.messaging();

/* =========================
   🔐 PAYPAL SECRETS
========================= */
const PAYPAL_CLIENT_ID = defineSecret("PAYPAL_CLIENT_ID_LIVE");
const PAYPAL_SECRET = defineSecret("PAYPAL_SECRET_LIVE");

/* =========================
   🔐 FAUCETPAY SECRET
========================= */
const FAUCETPAY_KEY = defineSecret("FAUCETPAY_KEY");

/* =========================
   PAYPAL PAYOUT
========================= */
async function getAccessToken() {
  const auth = Buffer.from(
    `${PAYPAL_CLIENT_ID.value()}:${PAYPAL_SECRET.value()}`
  ).toString("base64");

  const res = await axios.post(
    "https://api-m.paypal.com/v1/oauth2/token",
    "grant_type=client_credentials",
    {
      headers: {
        Authorization: `Basic ${auth}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
    }
  );

  return res.data.access_token;
}

async function payout(email, amount) {
  const token = await getAccessToken();

  return await axios.post(
    "https://api-m.paypal.com/v1/payments/payouts",
    {
      sender_batch_header: {
        sender_batch_id: Date.now().toString(),
        email_subject: "You received a payout",
      },
      items: [
        {
          recipient_type: "EMAIL",
          receiver: email,
          amount: {
            value: Number(amount).toFixed(2),
            currency: "USD",
          },
        },
      ],
    },
    {
      headers: {
        Authorization: `Bearer ${token}`,
      },
    }
  );
}

/* =========================
   💰 PAYPAL WITHDRAW
========================= */
exports.processPaypalWithdraw = onDocumentUpdated(
  {
    document: "withdraw_requests/{id}",
    secrets: [PAYPAL_CLIENT_ID, PAYPAL_SECRET],
  },
  async (event) => {
console.log("RAW EVENT:", JSON.stringify(event, null, 2));
    const before = event.data.before.data();
    const after = event.data.after.data();
    const ref = event.data.after.ref;

    // 🔥 Debug أول نقطة دخول
    console.log("🔥 PAYPAL WITHDRAW START:", {
      id: event.params.id,
      after,
      before
    });

    // ⛔ لو اتعالج قبل كده اخرج
    if (after.processed) {
      console.log("⛔ Already processed, skipping");
      return;
    }

    // 📊 تتبع تغيير الحالة
    console.log("➡️ STATUS CHECK:", {
      before: before.status,
      after: after.status
    });

    // 🚀 شرط التنفيذ
    if (before.status !== "approved" && after.status === "approved") {
      try {

        console.log("💰 Sending payout to:", after.email);

        const result = await payout(after.email, after.amount);

        console.log("✅ PAYOUT SUCCESS:", result.data);

        await ref.set({
          status: "completed",
          processed: true,
        }, { merge: true });

        if (after.fcmToken) {
          await messaging.send({
            token: after.fcmToken,
            notification: {
              title: "Withdrawal Completed 🎉",
              body: `You received $${after.amount}`,
            },
          });
        }

      } catch (e) {

        console.error("❌ PAYPAL WITHDRAW ERROR FULL:", {
          message: e.message,
          status: e.response?.status,
          data: e.response?.data,
        });

        await ref.set({
          status: "failed",
          processed: true,
          reason: e.response?.data?.message || e.message || "unknown error"
        }, { merge: true });
      }
    }
  }
);

/* =========================
   💸 FAUCETPAY BTC WITHDRAW
========================= */
exports.processBTCWithdraw = onDocumentCreated(
  {
    document: "withdraw_requests/{id}",
    secrets: [FAUCETPAY_KEY],
  },
  async (event) => {

console.log("RAW EVENT:", JSON.stringify(event, null, 2));

    const data = event.data.data();

    const ref = event.data.ref;

    // 🔥 أول نقطة تتبع
    console.log("🚀 BTC WITHDRAW START:", {
      id: event.params.id,
      data
    });

    const apiKey = FAUCETPAY_KEY.value();

    const userRef = admin.firestore().collection("users").doc(data.uid);

    try {

      console.log("👤 Fetching user:", data.uid);

      const userSnap = await userRef.get();
      const currentCoins = userSnap.data()?.totalCoins || 0;

      console.log("💰 USER BALANCE:", currentCoins);
      console.log("💸 REQUEST COINS:", data.coins);

      // ❌ رصيد غير كافي
      if (currentCoins < data.coins) {
        console.log("⛔ INSUFFICIENT BALANCE");

        return ref.update({
          status: "failed",
          reason: "Insufficient balance"
        });
      }

      console.log("📡 Sending request to FaucetPay...");

      const response = await axios.post(
        "https://faucetpay.io/api/v1/send",
        {
          api_key: apiKey,
          to: data.wallet,
          amount: data.amount,
          currency: "BTC"
        }
      );

      console.log("📩 FAUCETPAY RESPONSE:", response.data);

      // ✅ نجاح العملية
      if (response.data.status === 200) {

        console.log("✅ PAYMENT SUCCESS");

        await admin.firestore().runTransaction(async (tx) => {

          tx.update(userRef, {
            totalCoins: currentCoins - data.coins
          });

          tx.update(ref, {
            status: "completed",
            processed: true,
            txid: response.data.data?.transaction_id || "",
          });

        });

      } else {

        console.log("❌ FAUCETPAY FAILED:", response.data);

        await ref.update({
          status: "failed",
          reason: response.data.message || "Unknown error"
        });
      }

    } catch (e) {

      console.error("🔥 BTC WITHDRAW ERROR FULL:", {
        message: e.message,
        status: e.response?.status,
        data: e.response?.data
      });

      await ref.update({
        status: "error",
        reason: e.response?.data?.message || e.message || "unknown error"
      });
    }
  }
);

/* =========================
   🎁 REFERRAL SYSTEM
========================= */
exports.applyReferralCode = onCall(async (request) => {

  const uid = request.auth?.uid;
  const code = (request.data.code || "").trim().toUpperCase();

  if (!uid) throw new HttpsError("unauthenticated", "Login required");

  const db = admin.firestore();

  const userRef = db.collection("users").doc(uid);

  const query = await db.collection("users")
    .where("referralCode", "==", code)
    .limit(1)
    .get();

  if (query.empty) throw new HttpsError("not-found", "Invalid code");

  const owner = query.docs[0];

  if (owner.id === uid) {
    throw new HttpsError("invalid-argument", "Self referral not allowed");
  }

  await db.runTransaction(async (tx) => {

    const userSnap = await tx.get(userRef);
    const ownerSnap = await tx.get(owner.ref);

    tx.update(userRef, {
      totalCoins: (userSnap.data().totalCoins || 0) + 50,
      usedReferral: true,
    });

    tx.update(owner.ref, {
      totalCoins: (ownerSnap.data().totalCoins || 0) + 50,
    });

  });

  return { success: true };
});




exports.cpxPostback = onRequest(async (req, res) => {
  try {
    console.log("🔥 POSTBACK:", req.query);

    const userId = req.query.user_id;
    const amountUsd = Number(req.query.amount_usd || 0);
    const transId = req.query.trans_id;
    const status = Number(req.query.status || 1);

    const hash = req.query.hash;

    // ✅ تحقق من البيانات
    if (!userId || !transId) {
      return res.status(400).send("Invalid data");
    }

const expectedHash = crypto
  .createHash("md5")
  .update(transId + SECRET)
  .digest("hex");

if (hash && hash !== expectedHash) {
  console.log("❌ INVALID HASH");
  return res.status(403).send("FORBIDDEN");
}
    // 🔒 منع التكرار
    const logRef = admin.firestore().collection("cpx_logs").doc(transId);
    const logSnap = await logRef.get();

    if (logSnap.exists) {
      return res.status(200).send("DUPLICATE");
    }

    const userRef = admin.firestore().collection("users").doc(userId);

    let coins = 0;

    // 🎯 تحديد المكافأة
    if (status === 1) {

      if (amountUsd < 0.2) {
        coins = 500;
      } else if (amountUsd < 0.8) {
        coins = 800;
      } else {
        coins = 1500;
      }

    } else if (status === 2) {

      // ❌ Screenout reward
      coins = 100;
    }

    // 💰 إضافة العملات للرصيد الكلي
    await userRef.set({
      totalCoins: admin.firestore.FieldValue.increment(coins),
      cpxEarnings: admin.firestore.FieldValue.increment(amountUsd),
    }, { merge: true });

    // 🧾 تسجيل العملية
    await logRef.set({
      userId,
      amountUsd,
      status,
      coins,
      transId,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    console.log("✅ Coins Added:", coins);

    return res.status(200).send("OK");

  } catch (e) {

    console.error("❌ ERROR:", e);

    return res.status(500).send("Server Error");
  }
});



 exports.theoremreachPostback = onRequest(async (req, res) => {
  try {
    // ================= INPUT =================
    const userId =
      req.query.user_id ||
      req.query.external_id ||
      req.query.partner_user_id;

    const reward = Number(req.query.reward || 0);

    const tx_id =
      req.query.tx_id ||
      req.query.transaction_id ||
      req.query.id;

    const screenout = Number(req.query.screenout || 0);
    const debug = req.query.debug;

    // ================= LOGS =================
    console.log("🔥 THEOREM POSTBACK:", req.query);
    console.log("🔥 USER ID:", userId);
    console.log("🔥 TX ID:", tx_id);

    // ❌ تجاهل test mode
    if (debug === "true") {
      return res.status(200).send("DEBUG IGNORED");
    }

    // ❌ تحقق من البيانات
    if (!userId || !tx_id) {
      console.log("❌ Missing data");
      return res.status(400).send("Invalid data");
    }

    // 🔒 منع التكرار
    const logRef = admin.firestore().collection("tr_logs").doc(tx_id);
    const logSnap = await logRef.get();

    if (logSnap.exists) {
      console.log("⚠️ Duplicate:", tx_id);
      return res.status(200).send("DUPLICATE");
    }

    // ================= COINS =================
    let coins = 0;

    if (screenout == 1) {
      coins = 50;
    } else if (reward <= 0.10) {
      coins = 500;
    } else if (reward <= 0.50) {
      coins = 800;
    } else {
      coins = 1500;
    }

    console.log("💰 Coins:", coins);

    // ================= USER UPDATE =================
    const userRef = admin.firestore().collection("users").doc(userId);

    await userRef.set({
      totalCoins: admin.firestore.FieldValue.increment(coins),
      theoremEarnings: admin.firestore.FieldValue.increment(reward),
    }, { merge: true });

    // ================= LOG SAVE =================
    await logRef.set({
      userId,
      reward,
      tx_id,
      coins,
      screenout,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    console.log("✅ DONE:", userId);

    return res.status(200).send("OK");

  } catch (e) {
    console.error("❌ ERROR:", e);
    return res.status(500).send("ERROR");
  }
});








  exports.adgemPostback = onRequest(async (req, res) => {
    try {
      // ================= INPUT =================
      const userId =
        req.query.user_id ||
        req.query.external_id ||
        req.query.partner_user_id;

      const reward = Number(req.query.reward || 0);

      const tx_id =
        req.query.tx_id ||
        req.query.transaction_id ||
        req.query.id;

      const screenout = Number(req.query.screenout || 0);
      const debug = req.query.debug;

      // ================= LOGS =================
      console.log("🔥 ADGEM POSTBACK:", req.query);
      console.log("🔥 USER ID:", userId);
      console.log("🔥 TX ID:", tx_id);

      // ❌ تجاهل الاختبارات
      if (debug === "true") {
        return res.status(200).send("DEBUG IGNORED");
      }

      // ❌ تحقق من البيانات
      if (!userId || !tx_id) {
        console.log("❌ Missing data");
        return res.status(400).send("INVALID DATA");
      }

      // ================= DUPLICATE CHECK =================
      const logRef = admin.firestore().collection("adgem_logs").doc(tx_id);
      const logSnap = await logRef.get();

      if (logSnap.exists) {
        console.log("⚠️ DUPLICATE TRANSACTION:", tx_id);
        return res.status(200).send("DUPLICATE");
      }

      // ================= COINS CALCULATION =================
      let coins = 0;

      if (screenout === 1) {
        coins = 50;
      } else if (reward <= 0.10) {
        coins = 500;
      } else if (reward <= 0.50) {
        coins = 800;
      } else if (reward <= 1) {
        coins = 1200;
      } else {
        coins = 1500;
      }

      console.log("💰 COINS AWARDED:", coins);

      // ================= UPDATE USER =================
      const userRef = admin.firestore().collection("users").doc(userId);

      await userRef.set(
        {
          totalCoins: admin.firestore.FieldValue.increment(coins),
          totalEarnings: admin.firestore.FieldValue.increment(reward),
          lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      // ================= SAVE LOG =================
      await logRef.set({
        userId,
        reward,
        tx_id,
        coins,
        screenout,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log("✅ SUCCESS:", userId);

      return res.status(200).send("OK");

    } catch (error) {
      console.error("❌ ERROR:", error);
      return res.status(500).send("ERROR");
    }
  });









 exports.admantumPostback = onRequest(async (req, res) => {
   try {

     // ================= INPUT =================
     const userId =
       req.query.user_id ||
       req.query.uid ||
       req.query.external_id;

     const reward = Number(
       req.query.reward ||
       req.query.payout ||
       0
     );

     const tx_id =
       req.query.tx_id ||
       req.query.transaction_id ||
       req.query.id;

     const status = Number(req.query.status || 1);

     // ================= LOGS =================
     console.log("🔥 ADMANTUM POSTBACK:", req.query);

     // ❌ تحقق من البيانات
     if (!userId || !tx_id) {
       return res.status(400).send("INVALID DATA");
     }

     // ================= DUPLICATE CHECK =================
     const logRef = admin
       .firestore()
       .collection("admantum_logs")
       .doc(tx_id);

     const logSnap = await logRef.get();

     if (logSnap.exists) {
       return res.status(200).send("DUPLICATE");
     }

     // ================= COINS =================
     let coins = 0;

     if (reward <= 0.10) {
       coins = 500;
     } else if (reward <= 0.50) {
       coins = 800;
     } else if (reward <= 1) {
       coins = 1200;
     } else {
       coins = 1500;
     }

     // ================= STATUS =================
     // status = 1 => add coins
     // status = 0 => reversal

     if (status === 0) {
       coins = -coins;
     }

     // ================= UPDATE USER =================
     const userRef =
       admin.firestore().collection("users").doc(userId);

     await userRef.set(
       {
         totalCoins:
           admin.firestore.FieldValue.increment(coins),

         admantumEarnings:
           admin.firestore.FieldValue.increment(reward),

         lastUpdated:
           admin.firestore.FieldValue.serverTimestamp(),
       },
       { merge: true }
     );

     // ================= SAVE LOG =================
     await logRef.set({
       userId,
       reward,
       tx_id,
       coins,
       status,

       createdAt:
         admin.firestore.FieldValue.serverTimestamp(),
     });

     console.log("✅ ADMANTUM SUCCESS:", userId);

     return res.status(200).send("OK");

   } catch (e) {

     console.error("❌ ADMANTUM ERROR:", e);

     return res.status(500).send("ERROR");
   }
 });