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
const Busboy = require("busboy");
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

    const userId =
      req.query.ext_user_id ||
      req.query.user_id ||
      req.query.external_id ||
      req.query.partner_user_id;

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

const rate = 1000; // 1$ = 1000 coins

let coins = 0;

if (status === 1) {
  coins = Math.floor(amountUsd * rate);
}
else if (status === 2) {
  coins = 100;
}

    // 💰 إضافة العملات للرصيد الكلي
    await userRef.set({
      totalCoins: admin.firestore.FieldValue.increment(coins),
      lastUpdate: admin.firestore.FieldValue.serverTimestamp(),
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

    console.log("🔥 THEOREM POSTBACK:", req.query);

    // ================= USER ID =================
    let userId = (
      req.query.external_id ||
      req.query.user_id ||
      req.query.partner_user_id ||
      req.query.uid
    );

    userId = userId?.toString().trim().replace(/\s/g, "");

    // ================= REWARD =================
    const reward = Number(req.query.reward || 0);

    // ================= TX ID =================
    const tx_id = (
      req.query.tx_id ||
      req.query.transaction_id ||
      req.query.id
    )?.toString().trim();

    const screenout = Number(req.query.screenout || 0);
    const debug = req.query.debug;

    // ================= VALIDATION =================
    if (!userId || !tx_id) {
      console.log("❌ INVALID DATA");
      return res.status(400).send("INVALID DATA");
    }

    // ⚠️ لا توقف النظام في debug
    if (debug === "true") {
      console.log("⚠️ DEBUG MODE - still processing");
    }

    // ================= DUPLICATE CHECK =================
    const logRef = admin.firestore().collection("tr_logs").doc(tx_id);
    const logSnap = await logRef.get();

    if (logSnap.exists) {
      console.log("⚠️ DUPLICATE:", tx_id);
      return res.status(200).send("DUPLICATE");
    }

    // ================= COINS =================
    let coins = Math.floor(reward * 1000);

    if (screenout == 1) {
      coins = Math.max(coins, 50);
    }

    console.log("💰 COINS:", coins);

    // ================= UPDATE USER =================
    const userRef = admin.firestore().collection("users").doc(userId);

    await userRef.set({
      totalCoins: admin.firestore.FieldValue.increment(coins),
      theoremEarnings: admin.firestore.FieldValue.increment(reward),
      lastUpdate: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    // ================= LOG =================
    await logRef.set({
      userId,
      reward,
      tx_id,
      coins,
      screenout,
      debug: debug || false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log("✅ SUCCESS:", userId);

    return res.status(200).send("OK");

  } catch (error) {
    console.error("❌ ERROR:", error);
    return res.status(500).send("ERROR");
  }
});







exports.myleadPostback = onRequest(async (req, res) => {
  try {

    console.log("🔥 MYLEAD POSTBACK:", req.query);

    const data = req.method === "POST" ? req.body : req.query;

    // ================= USER =================
    const userId =
      data.subid ||
      data.sub_id ||
      data.external_id ||
      data.user_id;

    // ================= TRANSACTION =================
    const tx_id =
      data.transaction_id ||
      data.tx_id ||
      `${Date.now()}`;

    // ================= PAYOUT =================
    const payout = Number(data.payout || data.amount || 0);

    // ================= STATUS =================
    const status = Number(data.status ?? 1);

    // ================= VALIDATION =================
    if (!userId) {
      console.log("❌ Missing userId");
      return res.status(200).send("OK");
    }

    // ================= DUPLICATE CHECK =================
    const logRef = admin.firestore()
      .collection("mylead_logs")
      .doc(tx_id);

    const logSnap = await logRef.get();

    if (logSnap.exists) {
      console.log("⚠️ DUPLICATE:", tx_id);
      return res.status(200).send("OK");
    }

    // ================= COINS =================
    let coins = Math.floor(payout * 1000);

    // لو rejected
    if (status === 0 || status === 2) {
      coins = 0;
    }

    const userRef = admin.firestore().collection("users").doc(userId);

    await userRef.set({
      totalCoins: admin.firestore.FieldValue.increment(coins),
      myleadEarnings: admin.firestore.FieldValue.increment(payout),
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    // ================= LOG =================
    await logRef.set({
      userId,
      tx_id,
      payout,
      coins,
      status,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log("✅ MYLEAD SUCCESS:", { userId, coins });

    return res.status(200).send("OK");

  } catch (e) {
    console.error("❌ MYLEAD ERROR:", e);
    return res.status(500).send("ERROR");
  }
});







exports.admantumPostback = onRequest(async (req, res) => {
  try {

    // 🔥 دعم GET + POST معاً
    const data = req.method === "POST" ? req.body : req.query;

    console.log("🔥 RAW POSTBACK:", {
      method: req.method,
      query: req.query,
      body: req.body,
    });

    const userId =
      data.uid ||
      data.user_id ||
      data.external_id ||
      data.userId;

    const reward = Number(
      data.virtual_currency ||
      data.reward ||
      data.payout ||
      data.amount ||
      0
    );

    const tx_id =
      data.transaction_id ||
      data.tx_id ||
      data.id ||
      data.of_id ||
      `${Date.now()}`;

    const status = Number(data.status ?? 1);

    // ❌ مهم جداً: لا تقفل بدري
    if (!userId) {
      console.log("❌ Missing userId");
      return res.status(200).send("OK"); // بدل INVALID DATA
    }

    const logId = `${userId}_${tx_id}`;

    const logRef = admin.firestore()
      .collection("admantum_logs")
      .doc(logId);

    const logSnap = await logRef.get();

    if (logSnap.exists) {
      return res.status(200).send("OK"); // duplicate safe
    }

    const coins = Math.floor(reward * 1000);

    const finalCoins = status === 0 ? -coins : coins;

    const userRef = admin.firestore()
      .collection("users")
      .doc(userId);

    await userRef.set({
      totalCoins: admin.firestore.FieldValue.increment(finalCoins),
      admantumEarnings: admin.firestore.FieldValue.increment(reward),
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    await logRef.set({
      userId,
      reward,
      tx_id,
      status,
      coins: finalCoins,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return res.status(200).send("OK");

  } catch (e) {
    console.error("❌ ADMANTUM ERROR:", e);
    return res.status(500).send("ERROR");
  }
});










exports.bitcotasksPostback = onRequest(async (req, res) => {
  try {

    const data = req.method === "POST" ? req.body : req.query;

    const userId = data.subId;
    const reward = Number(data.reward || 0);
    const status = Number(data.status || 1);
    const tx_id = data.transId;

    if (!userId) return res.status(200).send("ok");

    const logId = `${userId}_${tx_id}`;
    const logRef = admin.firestore().collection("bitcotasks_logs").doc(logId);

    const snap = await logRef.get();
    if (snap.exists) return res.status(200).send("ok");

    const coins = Math.floor(reward * 1000);
    const finalCoins = status === 2 ? -coins : coins;

    const userRef = admin.firestore().collection("users").doc(userId);

    await userRef.set({
      totalCoins: admin.firestore.FieldValue.increment(finalCoins),
      bitcotasksEarnings: admin.firestore.FieldValue.increment(reward),
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    await logRef.set({
      userId,
      reward,
      tx_id,
      status,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return res.status(200).send("ok");

  } catch (e) {
    console.error(e);
    return res.status(500).send("error");
  }
});






exports.pollmaticPostback = onRequest(async (req, res) => {
  try {

    const busboy = Busboy({ headers: req.headers });
    const data = {};

    busboy.on("field", (key, value) => {
      data[key] = value;
    });

    busboy.on("finish", async () => {

      console.log("📦 PARSED DATA:", data);

      const userId = data.subId;
      const tx_id = data.transId;

      const reward = Number(data.reward || data.reward_value || data.payout || 0);
      const status = Number(data.status || 1);

      console.log("💰 reward:", reward);
      console.log("👤 userId:", userId);
      console.log("🧾 tx_id:", tx_id);

      if (!userId || !tx_id) {
        console.log("❌ INVALID DATA");
        return res.status(200).send("ok");
      }

      const logRef = admin.firestore()
        .collection("pollmatic_logs")
        .doc(tx_id);

      if ((await logRef.get()).exists) {
        console.log("⚠️ DUPLICATE");
        return res.status(200).send("ok");
      }

    let coins = Math.floor(reward * 1);

      await admin.firestore()
        .collection("users")
        .doc(userId)
        .set({
          totalCoins: admin.firestore.FieldValue.increment(coins),
          pollmaticEarnings: admin.firestore.FieldValue.increment(reward),
          lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });

      await logRef.set({
        userId,
        tx_id,
        reward,
        coins,
        status,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log("✅ SUCCESS:", { userId, coins });

      return res.status(200).send("ok");
    });

    busboy.end(req.rawBody); // 🔥 مهم جدًا في Firebase Functions v2

  } catch (e) {
    console.error("❌ ERROR:", e);
    return res.status(500).send("error");
  }

});










exports.rapidoreachCallback = onRequest(async (req, res) => {
  try {
    console.log("🔥 RAW CALLBACK:", req.query);

    // =========================
    // 🔹 GET ONLY (حسب التوثيق)
    // =========================
    const data = req.query;

    // =========================
    // 👤 USER ID (الأهم)
    // =========================
    const userId = data.endUserId || data.userId;

    // =========================
    // 🧾 TRANSACTION ID
    // =========================
    const transactionId = data.transactionId;

    // =========================
    // 💰 REWARD
    // =========================
    const rewardCoins = Number(data.currencyAmt || 0);
    const rewardUsd = Number(data.amt || 0);

    // =========================
    // 📌 STATUS
    // COMPLETE / QUOTAFULL / TERMINATION
    // =========================
    const status = data.status;

    // =========================
    // ❌ VALIDATION
    // =========================
    if (!userId || !transactionId) {
      console.log("❌ Missing data:", data);
      return res.status(200).send("0"); // فشل
    }

    // =========================
    // 🔒 DUPLICATE CHECK
    // =========================
    const logRef = admin.firestore()
      .collection("rapidoreach_logs")
      .doc(transactionId);

    const logSnap = await logRef.get();

    if (logSnap.exists) {
      console.log("⚠️ Duplicate transaction:", transactionId);
      return res.status(200).send("1");
    }

    // =========================
    // 💰 CALCULATE COINS
    // =========================
    let coins = Math.floor(rewardCoins);

    // Status handling
    if (status === "COMPLETE") {
      // OK
    }
    else if (status === "QUOTAFULL" || status === "TERMINATION") {
      coins = 0; // لا مكافأة أو ممكن سالب لو عايز
    }

    // =========================
    // 👤 UPDATE USER
    // =========================
    const userRef = admin.firestore()
      .collection("users")
      .doc(userId);

    await userRef.set({
      totalCoins: admin.firestore.FieldValue.increment(coins),
      rapidoreachEarnings: admin.firestore.FieldValue.increment(rewardUsd),
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    // =========================
    // 🧾 SAVE LOG
    // =========================
    await logRef.set({
      userId,
      transactionId,
      rewardCoins,
      rewardUsd,
      status,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log("✅ SUCCESS:", { userId, coins });

    // =========================
    // ✅ RESPONSE (مهم جداً)
    // =========================
    return res.status(200).send("1");

  } catch (e) {
    console.error("❌ ERROR:", e);
    return res.status(200).send("0");
  }
});





exports.cpagripPostback = onRequest(async (req, res) => {
  try {
    console.log("🔥 QUERY:", req.query);
    console.log("🔥 BODY:", req.body);

    const data = Object.keys(req.body || {}).length ? req.body : req.query;

    const password = data.password;
    const userId = (data.tracking_id || data.subid || "").trim();
    const payout = Number(data.payout || 0);
    const offerId = data.offer_id || "unknown";

    const EXPECTED_PASSWORD = "goearn_secret_2026";

    // ❌ password check
    if (password !== EXPECTED_PASSWORD) {
      console.log("❌ WRONG PASSWORD:", password);
      return res.status(403).send("INVALID PASSWORD");
    }

    // ❌ user check
    if (!userId) {
      console.log("❌ NO USER ID");
      return res.status(400).send("NO USER");
    }

    if (payout <= 0) {
      return res.status(400).send("INVALID PAYOUT");
    }

    const coins = Math.floor(payout * 1000);

    const userRef = admin.firestore().collection("users").doc(userId);

    await userRef.set({
      totalCoins: admin.firestore.FieldValue.increment(coins),
      lastUpdate: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    await admin.firestore().collection("cpagrip_logs").add({
      userId,
      payout,
      offerId,
      coins,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log("✅ ADDED COINS:", coins, "TO:", userId);

    return res.status(200).send("OK");

  } catch (e) {
    console.error("❌ ERROR:", e);
    return res.status(500).send("ERROR");
  }
});












exports.mobideaPostback = onRequest(async (req, res) => {
  try {

    console.log("🔥 MOBIDEA POSTBACK:", req.query);

    // =========================
    // 👤 USER ID
    // =========================
    const userId =
      req.query.external_id ||
      req.query.user_id;

    // =========================
    // 💰 PAYOUT
    // =========================
    const payout = Number(req.query.payout || 0);

    // =========================
    // 🧾 TRANSACTION ID
    // =========================
    const tx_id =
      req.query.transaction_id ||
      req.query.conversion_id ||
      `${Date.now()}`;

    // =========================
    // ❌ VALIDATION
    // =========================
    if (!userId) {
      console.log("❌ Missing USER ID");
      return res.status(200).send("OK");
    }

    // =========================
    // 🔒 DUPLICATE CHECK
    // =========================
    const logRef = admin.firestore()
      .collection("mobidea_logs")
      .doc(tx_id);

    const logSnap = await logRef.get();

    if (logSnap.exists) {
      console.log("⚠️ DUPLICATE");
      return res.status(200).send("OK");
    }

    // =========================
    // 💰 CALCULATE COINS
    // =========================
    const coins = Math.floor(payout * 1000);

    // =========================
    // 👤 UPDATE USER
    // =========================
    const userRef = admin.firestore()
      .collection("users")
      .doc(userId);

    await userRef.set({
      totalCoins: admin.firestore.FieldValue.increment(coins),
      mobideaEarnings: admin.firestore.FieldValue.increment(payout),
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    // =========================
    // 🧾 SAVE LOG
    // =========================
    await logRef.set({
      userId,
      payout,
      tx_id,
      coins,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log("✅ MOBIDEA SUCCESS:", {
      userId,
      coins
    });

    return res.status(200).send("OK");

  } catch (e) {

    console.error("❌ MOBIDEA ERROR:", e);

    return res.status(500).send("ERROR");
  }
});