const functions = require("firebase-functions");
const admin = require("firebase-admin");
const jwt = require("jsonwebtoken");
const { v4: uuidv4 } = require("uuid");
const axios = require("axios");
const vision = require("@google-cloud/vision");

const visionClient = new vision.ImageAnnotatorClient();

admin.initializeApp();
const db = admin.firestore();

// ─── Yardımcı fonksiyonlar ────────────────────────────────────────────────────

function getOneSignalConfig() {
  const appId = process.env.ONESIGNAL_APP_ID;
  const restApiKey = process.env.ONESIGNAL_REST_API_KEY;
  if (!appId || !restApiKey) {
    console.warn("OneSignal anahtarları (ONESIGNAL_APP_ID, ONESIGNAL_REST_API_KEY) tanımlı değil!");
    return { appId: null, restApiKey: null };
  }
  return { appId, restApiKey };
}

function generateManagementToken() {
  const accessKey = process.env.HMS_ACCESS_KEY;
  // .env dosyasında HMS_SECRET veya HMS_APP_SECRET olarak tanımlanabilir
  const secretKey = process.env.HMS_SECRET || process.env.HMS_APP_SECRET;
  if (!accessKey || !secretKey) {
    throw new Error(
      `Sunucuda 100ms API anahtarları eksik! ` +
      `HMS_ACCESS_KEY=${accessKey ? 'OK' : 'EKSİK'}, HMS_SECRET=${secretKey ? 'OK' : 'EKSİK'}`
    );
  }
  const payload = {
    access_key: accessKey,
    type: "management",
    version: 2,
    jti: uuidv4(),
    iat: Math.floor(Date.now() / 1000),
    nbf: Math.floor(Date.now() / 1000),
    exp: Math.floor(Date.now() / 1000) + 24 * 3600,
  };
  return jwt.sign(payload, secretKey, { algorithm: "HS256" });
}

// ─── getOrCreateHmsRoom ───────────────────────────────────────────────────────
exports.getOrCreateHmsRoom = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Bu işlemi yapmak için giriş yapmış olmalısınız."
    );
  }

  const { roomId } = data;
  if (!roomId) {
    throw new functions.https.HttpsError("invalid-argument", "roomId parametresi gereklidir.");
  }

  try {
    let roomRef = db.collection("rooms").doc(roomId);
    let roomSnap = await roomRef.get();

    if (!roomSnap.exists) {
      roomRef = db.collection("directMessages").doc(roomId);
      roomSnap = await roomRef.get();
    }

    if (!roomSnap.exists) {
      throw new functions.https.HttpsError(
        "not-found",
        `Firestore'da ${roomId} adında oda veya DM bulunamadı.`
      );
    }

    const roomData = roomSnap.data();
    let currentHmsCode = roomData.hmsCode;
    let currentHmsRoomId = roomData.hmsRoomId;

    const token = generateManagementToken();
    const headers = { Authorization: `Bearer ${token}` };

    let isFull = false;

    if (currentHmsRoomId) {
      try {
        // 100ms üzerinden odanın kodlarını alarak hem varlığını doğrulayalım hem de güncelleyelim
        const codesRes = await axios.post(
          `https://api.100ms.live/v2/room-codes/room/${currentHmsRoomId}`,
          {},
          { headers }
        );
        const codes = codesRes.data.data;

        // Oda mevcutsa, aktiflik ve doluluk kontrolü yapalım
        try {
          const activeRes = await axios.get(
            `https://api.100ms.live/v2/active-rooms/${currentHmsRoomId}`,
            { headers }
          );
          const peers = activeRes.data.session && activeRes.data.session.peers ? activeRes.data.session.peers : [];
          const peerCount = Object.keys(peers).length;
          if (peerCount >= 5) {
            isFull = true;
            console.log(`Oda ${currentHmsRoomId} dolu (${peerCount} kişi). Yeni oda oluşturulacak.`);
          }
        } catch (err) {
          if (err.response && err.response.status === 404) {
            // Aktif session yok, oda boş ve kullanılabilir
            isFull = false;
          } else {
            console.error("active-rooms API hatası:", err.message);
          }
        }

        // Doluluk kontrolünden sonra eğer oda dolu değilse ve kodlar varsa doğrula/güncelle
        if (!isFull && codes && codes.length > 0) {
          let targetCode = "";
          const preferredRoles = ["speaker", "host", "guest", "moderator"];
          for (const role of preferredRoles) {
            const codeObj = codes.find((c) => c.role === role);
            if (codeObj) {
              targetCode = codeObj.code;
              break;
            }
          }
          if (!targetCode) {
            targetCode = codes[0].code;
          }

          if (targetCode && currentHmsCode !== targetCode) {
            console.log(`Firestore'daki hmsCode (${currentHmsCode}) güncelleniyor -> (${targetCode})`);
            await roomRef.update({ hmsCode: targetCode });
            currentHmsCode = targetCode;
          }
        }
      } catch (err) {
        if (err.response && err.response.status === 404) {
          // Oda 100ms'ten silinmiş veya geçersiz!
          console.log(`Oda ${currentHmsRoomId} 100ms üzerinde bulunamadı (404). Yeniden oluşturulacak.`);
          currentHmsCode = null;
          currentHmsRoomId = null;
        } else {
          console.error("100ms API check hatası:", err.message);
        }
      }
    }

    if (currentHmsCode && !isFull) {
      return { roomCode: currentHmsCode };
    }

    // Mevcut oda yoksa veya doluysa yeni bir oda oluştur
    const createRoomRes = await axios.post(
      "https://api.100ms.live/v2/rooms",
      {
        name: `r-${roomId.toLowerCase().replace(/[^a-z0-9-]/g, "-")}-${Date.now()
          .toString()
          .slice(-4)}`,
        description: `Voice Channel for ${roomId}`,
        template_id: process.env.HMS_TEMPLATE_ID || "69d5610ab635cb7c6d5fc731",
      },
      { headers }
    );

    const hmsRoomId = createRoomRes.data.id;
    const codesRes = await axios.post(
      `https://api.100ms.live/v2/room-codes/room/${hmsRoomId}`,
      {},
      { headers }
    );

    const codes = codesRes.data.data;
    if (!codes || codes.length === 0) {
      throw new Error("100ms Room Code oluşturulamadı.");
    }

    // Sesli oda sohbetinde herkesin konuşabilmesi için en uygun konuşma rolünün (speaker/host/guest/moderator) kodunu seçelim
    let targetCode = "";
    const preferredRoles = ["speaker", "host", "guest", "moderator"];
    for (const role of preferredRoles) {
      const codeObj = codes.find((c) => c.role === role);
      if (codeObj) {
        targetCode = codeObj.code;
        break;
      }
    }
    if (!targetCode) {
      targetCode = codes[0].code;
    }

    await roomRef.update({ hmsCode: targetCode, hmsRoomId });
    return { roomCode: targetCode };
  } catch (error) {
    // Axios API hatasından daha açıklayıcı mesaj üret
    let errMsg = error.message;
    if (error.response && error.response.data) {
      const d = error.response.data;
      errMsg = `100ms API hatası (${error.response.status}): ${d.message || JSON.stringify(d)}`;
    }
    console.error("getOrCreateHmsRoom hatası:", errMsg);
    throw new functions.https.HttpsError("internal", errMsg);
  }
});

exports.syncVoiceUsage = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Bu işlemi yapmak için giriş yapmış olmalısınız."
    );
  }

  const uid = context.auth.uid;
  const userRef = db.collection("users").doc(uid);
  const userSnap = await userRef.get();

  if (!userSnap.exists) {
    throw new functions.https.HttpsError("not-found", "Kullanıcı bulunamadı.");
  }

  const user = userSnap.data() || {};
  const now = admin.firestore.Timestamp.now().toDate();
  const lastReset = user.lastResetDate && user.lastResetDate.toDate
    ? user.lastResetDate.toDate()
    : now;
  const isNewDay =
    lastReset.getFullYear() !== now.getFullYear() ||
    lastReset.getMonth() !== now.getMonth() ||
    lastReset.getDate() !== now.getDate();

  let currentSeconds = Number.isInteger(user.dailyVoiceSeconds) ? user.dailyVoiceSeconds : 0;
  if (currentSeconds === 0 && Number.isInteger(user.dailyVoiceMinutes)) {
    currentSeconds = user.dailyVoiceMinutes * 60;
  }

  if (isNewDay) {
    currentSeconds = 0;
  }

  if (data && data.usedSeconds !== undefined) {
    if (data.usedSeconds > currentSeconds) {
      currentSeconds = data.usedSeconds;
    }
  } else if (data && data.increment === true) {
    currentSeconds += 60; // Geriye dönük uyumluluk
  }

  await userRef.set(
    {
      dailyVoiceSeconds: currentSeconds,
      dailyVoiceMinutes: Math.floor(currentSeconds / 60), // Geriye dönük uyumluluk
      lastResetDate: admin.firestore.Timestamp.fromDate(now),
    },
    { merge: true }
  );

  return {
    dailyVoiceSeconds: currentSeconds,
    lastResetDate: now.toISOString(),
    isPremium: user.isPremium === true,
  };
});

// ─── sendMessageNotification ──────────────────────────────────────────────────
/**
 * DM sohbetine yeni mesaj eklendiğinde otomatik tetiklenir.
 */
exports.sendMessageNotification = functions.firestore
  .document("directMessages/{chatId}/messages/{messageId}")
  .onCreate(async (snapshot, context) => {
    const message = snapshot.data();
    const { chatId } = context.params;

    if (!message) return null;

    const senderId = message.senderId;
    const text = message.text || "Yeni bir mesaj aldınız";

    const chatDoc = await db.collection("directMessages").doc(chatId).get();
    if (!chatDoc.exists) return null;

    const participants = chatDoc.data().participants || [];
    const recipientId = participants.find((id) => id !== senderId);
    if (!recipientId) return null;

    const senderDoc = await db.collection("users").doc(senderId).get();
    const senderName = senderDoc.exists ? senderDoc.data().displayName || "Biri" : "Biri";

    const { appId: oneSignalAppId, restApiKey } = getOneSignalConfig();
    if (!oneSignalAppId || !restApiKey) {
      console.warn("OneSignal bildirim gönderimi atlandı: API anahtarları eksik.");
      return null;
    }
    const payload = {
      app_id: oneSignalAppId,
      include_aliases: { external_id: [recipientId] },
      target_channel: "push",
      headings: { en: senderName, tr: senderName },
      contents: { en: text, tr: text },
      data: { chatId, senderId, type: "dm_message" },
      android_channel_id: "linguachat_messages",
    };

    try {
      await axios.post("https://onesignal.com/api/v1/notifications", payload, {
        headers: {
          "Content-Type": "application/json",
          Authorization: `Basic ${restApiKey}`,
        },
      });
      console.log(`OneSignal bildirimi gönderildi: ${senderName} -> ${recipientId}`);
    } catch (err) {
      console.error("OneSignal API hatası:", err.response ? err.response.data : err.message);
    }

    return null;
  });

// ─── sendPushNotification ─────────────────────────────────────────────────────
/**
 * Client'ın REST API key taşımasını engeller; bildirimleri server gönderir.
 */
exports.sendPushNotification = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Bu işlemi yapmak için giriş yapmış olmalısınız."
    );
  }

  const recipientId = data && data.recipientId;
  const title = data && data.title;
  const body = data && data.body;
  const extraData = (data && data.data) || null;

  if (!recipientId || !title || !body) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "recipientId, title ve body alanları gereklidir."
    );
  }

  const { appId: oneSignalAppId, restApiKey } = getOneSignalConfig();
  if (!oneSignalAppId || !restApiKey) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Sunucuda OneSignal API anahtarları yapılandırılmamış."
    );
  }
  const payload = {
    app_id: oneSignalAppId,
    include_aliases: { external_id: [String(recipientId)] },
    target_channel: "push",
    headings: { en: String(title), tr: String(title) },
    contents: { en: String(body), tr: String(body) },
    ...(extraData ? { data: extraData } : {}),
    android_channel_id: "linguachat_messages",
  };

  try {
    await axios.post("https://onesignal.com/api/v1/notifications", payload, {
      headers: {
        "Content-Type": "application/json",
        Authorization: `Basic ${restApiKey}`,
      },
    });
    return { ok: true };
  } catch (err) {
    console.error("OneSignal API hatası:", err.response ? err.response.data : err.message);
    throw new functions.https.HttpsError("internal", "Push gönderilemedi.");
  }
});

// ─── revenueCatWebhook ────────────────────────────────────────────────────────
/**
 * RevenueCat Dashboard → Integrations → Webhooks bölümünden bu URL'i ekleyin:
 *   https://us-central1-linguachat-550b1.cloudfunctions.net/revenueCatWebhook
 *
 * Güvenlik için Firebase ortam değişkenlerine REVENUECAT_WEBHOOK_SECRET ekleyin:
 *   firebase functions:config:set revenuecat.webhook_secret="<güçlü-rastgele-değer>"
 * ve RevenueCat Dashboard'da aynı değeri "Authorization Header" olarak girin.
 *
 * Desteklenen olaylar:
 *   INITIAL_PURCHASE  → isPremium: true,  premiumEndDate güncelle
 *   RENEWAL           → isPremium: true,  premiumEndDate güncelle
 *   CANCELLATION      → premiumEndDate dolunca otomatik kapanır (isPremium değişmez)
 *   EXPIRATION        → isPremium: false
 *   BILLING_ISSUE     → isPremium: false
 */
exports.revenueCatWebhook = functions.https.onRequest(async (req, res) => {
  if (req.method !== "POST") {
    return res.status(405).send("Method Not Allowed");
  }

  // Webhook secret doğrulama
  const webhookSecret =
    (functions.config().revenuecat && functions.config().revenuecat.webhook_secret) ||
    process.env.REVENUECAT_WEBHOOK_SECRET ||
    "";

  if (webhookSecret) {
    const authHeader = req.headers["authorization"] || "";
    if (authHeader !== webhookSecret) {
      console.warn("RevenueCatWebhook: Yetkisiz istek reddedildi.");
      return res.status(401).send("Unauthorized");
    }
  } else {
    console.warn(
      "RevenueCatWebhook: ⚠️  webhook_secret tanımlı değil. " +
      "firebase functions:config:set revenuecat.webhook_secret='...' ile ayarlayın."
    );
  }

  const event = req.body;
  if (!event || !event.event) {
    return res.status(400).send("Bad Request: event body missing");
  }

  const eventType = event.event.type;
  const appUserId = event.event.app_user_id; // Firebase UID
  const expiresAtMs = event.event.expiration_at_ms;

  console.log(`RevenueCatWebhook: ${eventType} – uid: ${appUserId}`);

  if (!appUserId) {
    return res.status(400).send("Bad Request: app_user_id missing");
  }

  const userRef = db.collection("users").doc(appUserId);

  try {
    switch (eventType) {
      case "INITIAL_PURCHASE":
      case "RENEWAL":
      case "PRODUCT_CHANGE": {
        const premiumEndDate = expiresAtMs
          ? admin.firestore.Timestamp.fromMillis(expiresAtMs)
          : null;
        const updateData = { isPremium: true };
        if (premiumEndDate) updateData.premiumEndDate = premiumEndDate;
        await userRef.set(updateData, { merge: true });
        console.log(`RevenueCatWebhook: ${appUserId} → Premium aktif. Bitiş: ${expiresAtMs}`);
        break;
      }

      case "CANCELLATION": {
        // İptal edildi ama süre dolmadan premium geçerli.
        // EXPIRATION eventi gelince isPremium: false yapılacak.
        console.log(`RevenueCatWebhook: ${appUserId} aboneliği iptal etti. Süre sonunda kapanacak.`);
        break;
      }

      case "EXPIRATION": {
        await userRef.set({ isPremium: false }, { merge: true });
        console.log(`RevenueCatWebhook: ${appUserId} → Premium sona erdi.`);
        break;
      }

      case "BILLING_ISSUE": {
        await userRef.set({ isPremium: false }, { merge: true });
        console.log(`RevenueCatWebhook: ${appUserId} → Ödeme hatası, premium devre dışı.`);
        break;
      }

      case "SUBSCRIBER_ALIAS":
      case "TRANSFER":
        console.log(`RevenueCatWebhook: ${eventType} alındı, işlem yapılmadı.`);
        break;

      default:
        console.log(`RevenueCatWebhook: Bilinmeyen event: ${eventType}`);
    }

    return res.status(200).send("OK");
  } catch (err) {
    console.error("RevenueCatWebhook Firestore hatası:", err.message);
    return res.status(500).send("Internal Server Error");
  }
});

// ─── moderateImage ────────────────────────────────────────────────────────────
/**
 * Yüklenen görselin Google Cloud Vision API ile NSFW (Uygunsuz İçerik) testinden geçirilmesini sağlar.
 */
exports.moderateImage = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Bu işlemi yapmak için giriş yapmış olmalısınız."
    );
  }

  const { filePath } = data; // Yüklenen dosyanın storage yolu (örn: 'posts/UID/1234.jpg')
  if (!filePath) {
    throw new functions.https.HttpsError("invalid-argument", "filePath parametresi eksik.");
  }

  try {
    const bucketName = admin.storage().bucket().name;
    const gcsUri = `gs://${bucketName}/${filePath}`;

    // Cloud Vision SafeSearch analizi
    const [result] = await visionClient.safeSearchDetection(gcsUri);
    const detections = result.safeSearchAnnotation;

    if (!detections) {
      return { isSafe: true };
    }

    // Yetişkin içerik veya şiddet ihtimali LIKELY veya VERY_LIKELY ise engelle
    const unsafeLevels = ["LIKELY", "VERY_LIKELY"];
    const isAdult = unsafeLevels.includes(detections.adult);
    const isViolence = unsafeLevels.includes(detections.violence);
    const isMedical = unsafeLevels.includes(detections.medical); // İsteğe bağlı
    const isRacy = unsafeLevels.includes(detections.racy); // İsteğe bağlı (müstehcen)

    if (isAdult || isViolence || isRacy) {
      // Uygunsuz bulundu: Dosyayı derhal sil
      await admin.storage().bucket().file(filePath).delete();
      return { isSafe: false, reason: "NSFW_DETECTED" };
    }

    return { isSafe: true };
  } catch (err) {
    console.error("Yapay zeka resim analiz hatası (Pasif geçiş):", err.message || err);
    // Cloud Vision API aktif değilse veya kota dolduysa gönderi paylaşımını engellememek için güvenli kabul edelim.
    return { isSafe: true };
  }
});

