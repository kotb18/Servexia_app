/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {setGlobalOptions} = require("firebase-functions");
const {onRequest} = require("firebase-functions/https");
const logger = require("firebase-functions/logger");

// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
setGlobalOptions({ maxInstances: 10 });

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

admin.initializeApp();

exports.sendTaskDataMessage = onCall(async (request) => {
  // ============================================================
  // 1️⃣ التأكد أن المستخدم مسجل دخول
  // ============================================================
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "يجب تسجيل الدخول أولاً"
    );
  }

  // ============================================================
  // 2️⃣ قراءة البيانات القادمة من Flutter
  // ============================================================
  const {
    topic,
    taskId,
    title,
    taskDateTime,
    reminderMinutes,
  } = request.data;

  // ============================================================
  // 3️⃣ التأكد من وجود البيانات المطلوبة
  // ============================================================
  if (!topic || !taskId || !title || !taskDateTime) {
    throw new HttpsError(
      "invalid-argument",
      "بيانات المهمة غير مكتملة"
    );
  }

  // ============================================================
  // 4️⃣ إرسال Data Message إلى Topic
  //
  // مهم:
  // نحن نرسل data فقط.
  //
  // لا نضع notification هنا لأننا نريد أن يستقبل
  // Background Handler البيانات ويقوم بجدولة
  // Local Notification بنفسه.
  // ============================================================

  const message = {
    topic: topic,

    data: {
      type: "schedule_task",
      taskId: String(taskId),
      title: String(title),
      taskDateTime: String(taskDateTime),
      reminderMinutes: String(reminderMinutes ?? 15),
    },

    android: {
      priority: "high",
    },
  };

  // ============================================================
  // 5️⃣ إرسال الرسالة عن طريق Firebase Cloud Messaging
  // ============================================================

  const response = await admin.messaging().send(message);

  // ============================================================
  // 6️⃣ إرجاع نتيجة الإرسال إلى Flutter
  // ============================================================

  return {
    success: true,
    messageId: response,
  };
});