"use strict";

const {setGlobalOptions} = require("firebase-functions");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const {GoogleAuth} = require("google-auth-library");
const {google} = require("googleapis");

setGlobalOptions({maxInstances: 10});

if (!admin.apps.length) {
  admin.initializeApp();
}

const PLAY_SERVICE_ACCOUNT_JSON = defineSecret("PLAY_SERVICE_ACCOUNT_JSON");
const IPINFO_TOKEN = defineSecret("IPINFO_TOKEN");

// ضع هنا Android applicationId الفعلي.
const PLAY_PACKAGE_NAME = "com.example.maintenance";
const IPINFO_URL = "https://ipinfo.io";
const PRICE_CACHE_TTL_MS = 15 * 60 * 1000;
const regionalPriceCache = new Map();
const countryCache = new Map();
const COUNTRY_CACHE_TTL_MS = 60 * 60 * 1000;

/**
 * يتحقق من صيغة معرّف المنتج.
 * @param {string} value معرّف Google Play product.
 * @return {boolean} هل المعرّف صالح؟
 */
function isValidProductId(value) {
  return typeof value === "string" && /^[A-Za-z0-9._-]{1,150}$/.test(value);
}

/**
 * يستخرج مدة الفوترة من Base Plan.
 * @param {Object} basePlan كائن الخطة الأساسية من Google API.
 * @return {string} مدة الخطة مثل P1M أو P1Y.
 */
function getBillingPeriod(basePlan) {
  return (basePlan && basePlan.autoRenewingBasePlanType &&
    basePlan.autoRenewingBasePlanType.billingPeriodDuration) || "";
}

/**
 * يختار Base Plan النشط المطابق للشهري أو السنوي.
 * @param {Array<Object>} basePlans الخطط الأساسية للاشتراك.
 * @param {string} period monthly أو yearly.
 * @return {?Object} الخطة المطابقة أو null.
 */
function selectBasePlan(basePlans, period) {
  const activePlans = (basePlans || []).filter(
      (item) => item.state === "ACTIVE",
  );
  const expected = period === "monthly" ? "P1M" : "P1Y";
  const match = activePlans.find(
      (item) => getBillingPeriod(item).toUpperCase() === expected,
  );
  if (match) return match;

  // استخدم الخطة الوحيدة فقط إذا لم ترجع Google مدتها.
  if (activePlans.length === 1 && !getBillingPeriod(activePlans[0])) {
    return activePlans[0];
  }
  return null;
}

/**
 * يستخرج عنوان IP الذي استقبلته Cloud Functions.
 * لا نأخذ IP من request.data لأنه قابل للتزوير من العميل.
 * @param {Object} request طلب callable من Firebase.
 * @return {string} عنوان IP.
 */
function getClientIp(request) {
  const rawIp = request.rawRequest && request.rawRequest.ip;
  if (typeof rawIp !== "string" || rawIp.trim() === "") {
    throw new HttpsError(
        "failed-precondition",
        "لم يتمكن الخادم من قراءة عنوان IP للطلب.",
    );
  }

  // Express قد يعيد IPv4 بصيغة IPv4-mapped IPv6.
  return rawIp.trim().replace(/^::ffff:/i, "");
}

/**
 * يحدد رمز البلد من IP باستخدام IPinfo.
 * @param {string} ip عنوان IP الذي قرأه الخادم.
 * @return {Promise<string>} رمز الدولة بحرفين كبيرين.
 */
async function resolveCountryFromIp(ip) {
  const cached = countryCache.get(ip);
  if (cached && cached.expiresAt > Date.now()) return cached.country;

  const url = `${IPINFO_URL}/${encodeURIComponent(ip)}/country` +
    `?token=${encodeURIComponent(IPINFO_TOKEN.value())}`;
  const response = await fetch(url, {method: "GET"});

  if (!response.ok) {
    logger.error("IP geolocation provider returned an error", {
      status: response.status,
    });
    throw new HttpsError(
        "unavailable",
        "تعذر تحديد الدولة من عنوان IP. حاول مرة أخرى لاحقًا.",
    );
  }

  const country = (await response.text()).trim().toUpperCase();
  if (!/^[A-Z]{2}$/.test(country)) {
    throw new HttpsError(
        "not-found",
        "لم يتمكن مزود الموقع من تحديد دولة عنوان IP.",
    );
  }

  countryCache.set(ip, {
    country,
    expiresAt: Date.now() + COUNTRY_CACHE_TTL_MS,
  });
  return country;
}

/**
 * يسترجع سعرًا إقليميًا مخزنًا مؤقتًا إن كان صالحًا.
 * @param {string} key مفتاح التخزين المؤقت.
 * @return {?Object} السعر المخزن أو null.
 */
function getCachedPrice(key) {
  const entry = regionalPriceCache.get(key);
  if (!entry) return null;
  if (entry.expiresAt <= Date.now()) {
    regionalPriceCache.delete(key);
    return null;
  }
  return entry.value;
}

exports.getPlayRegionalPrice = onCall(
    {
      secrets: [PLAY_SERVICE_ACCOUNT_JSON, IPINFO_TOKEN],
    },
    async (request) => {
      const data = request.data || {};
      const productId = data.productId;
      const period = data.period;

      if (!isValidProductId(productId)) {
        throw new HttpsError(
            "invalid-argument",
            "معرّف منتج Google Play غير صالح.",
        );
      }
      if (period !== "monthly" && period !== "yearly") {
        throw new HttpsError(
            "invalid-argument",
            "الفترة يجب أن تكون monthly أو yearly.",
        );
      }

      try {
        // البلد يأتي من IP كما رآه الخادم، وليس من بيانات Flutter.
        const ip = getClientIp(request);
        const country = await resolveCountryFromIp(ip);
        const cacheKey = `${productId}|${period}|${country}`;
        const cached = getCachedPrice(cacheKey);
        if (cached) return cached;

        const credentials = JSON.parse(PLAY_SERVICE_ACCOUNT_JSON.value());
        const auth = new GoogleAuth({
          credentials,
          scopes: ["https://www.googleapis.com/auth/androidpublisher"],
        });
        const publisher = google.androidpublisher({version: "v3", auth});
        const apiResponse = await publisher.monetization.subscriptions.get({
          packageName: PLAY_PACKAGE_NAME,
          productId,
        });

        const subscription = apiResponse.data;
        const basePlan = selectBasePlan(subscription.basePlans, period);
        if (!basePlan) {
          throw new HttpsError(
              "not-found",
              "لم يتم العثور على Base Plan نشط للفترة المطلوبة. " +
                "تحقق من إعداد مدة P1M أو P1Y في Play Console.",
          );
        }

        const regionalConfig = (basePlan.regionalConfigs || []).find(
            (item) =>
              String(item.regionCode || "").toUpperCase() === country,
        );
        if (!regionalConfig) {
          throw new HttpsError(
              "not-found",
              `لا يوجد سعر إقليمي مضبوط للبلد ${country}.`,
          );
        }
        if (regionalConfig.newSubscriberAvailability !== true) {
          throw new HttpsError(
              "failed-precondition",
              `الخطة غير متاحة للمشتركين الجدد في البلد ${country}.`,
          );
        }

        const money = regionalConfig.price;
        if (!money || !money.currencyCode) {
          throw new HttpsError(
              "not-found",
              `لم يرجع Google Play سعرًا صالحًا للبلد ${country}.`,
          );
        }

        const units = String(money.units || "0");
        const nanos = Number(money.nanos || 0);
        const amount = Number(units) + nanos / 1000000000;
        if (!Number.isFinite(amount)) {
          throw new HttpsError("data-loss", "قيمة السعر المرجعة غير صالحة.");
        }

        const result = {
          productId,
          basePlanId: basePlan.basePlanId,
          period,
          regionCode: country,
          currencyCode: money.currencyCode,
          amount,
          units,
          nanos,
          source: "google_play_regional_config",
        };

        regionalPriceCache.set(cacheKey, {
          value: result,
          expiresAt: Date.now() + PRICE_CACHE_TTL_MS,
        });
        return result;
      } catch (error) {
        if (error instanceof HttpsError) throw error;
        logger.error("Google Play regional price request failed", {
          message: error.message,
          code: error.code,
          response: error.response && error.response.data,
        });
        throw new HttpsError(
            "unavailable",
            "تعذر جلب السعر. تحقق من إعداد Google Play API وحساب الخدمة.",
        );
      }
    },
);

/**
 * يرسل بيانات تذكير المهمة عبر Firebase Cloud Messaging.
 */
exports.sendTaskDataMessage = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "يجب تسجيل الدخول أولاً");
  }

  const data = request.data || {};
  const topic = data.topic;
  const taskId = data.taskId;
  const title = data.title;
  const taskDateTime = data.taskDateTime;
  const reminderMinutes = data.reminderMinutes;

  if (!topic || !taskId || !title || !taskDateTime) {
    throw new HttpsError("invalid-argument", "بيانات المهمة غير مكتملة");
  }

  const message = {
    topic: String(topic),
    data: {
      type: "schedule_task",
      taskId: String(taskId),
      title: String(title),
      taskDateTime: String(taskDateTime),
      reminderMinutes: String(reminderMinutes || 15),
    },
    android: {priority: "high"},
  };

  const messageId = await admin.messaging().send(message);
  return {success: true, messageId};
});
