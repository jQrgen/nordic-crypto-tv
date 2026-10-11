import { test } from "node:test";
import assert from "node:assert/strict";
import { createVerify, verify } from "node:crypto";
import { b64urlDecode, pemToDer } from "../src/jwt.js";
import { apnsJwt, apnsRequest, classifyApns, APNS_HOSTS } from "../src/apns.js";
import { classifyFcm, fcmRequest, fcmTokenRequest, parseServiceAccount, FCM_SCOPE } from "../src/fcm.js";
import { testKeys } from "./keys.mjs";

const keys = testKeys();
const dec = (s) => JSON.parse(new TextDecoder().decode(b64urlDecode(s)));

test("APNs provider token is an ES256 JWT signed with the .p8 key", async () => {
  const env = { APNS_KEY_P8: keys.ecPem, APNS_KEY_ID: "ABC123DEFG", APNS_TEAM_ID: "YQBXSUUVJD", APNS_TOPIC: "no.cryptonordic.tv" };
  const jwt = await apnsJwt(env, 1_790_000_000);
  const [h, c, s] = jwt.split(".");
  assert.deepEqual(dec(h), { alg: "ES256", kid: "ABC123DEFG" });
  assert.deepEqual(dec(c), { iss: "YQBXSUUVJD", iat: 1_790_000_000 });
  const sig = b64urlDecode(s);
  assert.equal(sig.length, 64); // raw r||s, not DER
  assert.ok(verify("sha256", Buffer.from(`${h}.${c}`), { key: keys.ecPublic, dsaEncoding: "ieee-p1363" }, sig));
});

test("a .p8 pasted with literal \\n still parses", () => {
  const oneLine = keys.ecPem.replace(/\n/g, "\\n");
  assert.deepEqual(pemToDer(oneLine), pemToDer(keys.ecPem));
});

test("APNs request: host by environment, headers, payload", () => {
  const env = { APNS_TOPIC: "no.cryptonordic.tv" };
  const item = { id: "abc", country: "SE", source_name: "DI", title: "Rubrik", title_en: "Headline", language_code: "sv", title_i18n: {} };
  const prod = apnsRequest({ token: "aa".repeat(32), environment: "production", language: "en" }, item, "JWT", env, 1000);
  assert.equal(prod.url, `${APNS_HOSTS.production}/3/device/${"aa".repeat(32)}`);
  assert.equal(prod.init.method, "POST");
  assert.equal(prod.init.headers.authorization, "bearer JWT");
  assert.equal(prod.init.headers["apns-topic"], "no.cryptonordic.tv");
  assert.equal(prod.init.headers["apns-push-type"], "alert");
  assert.equal(prod.init.headers["apns-expiration"], String(1000 + 6 * 3600));
  assert.equal(prod.init.headers["apns-collapse-id"], "abc");
  assert.equal(JSON.parse(prod.init.body).aps.alert.body, "Headline");
  const sandbox = apnsRequest({ token: "bb".repeat(32), environment: "sandbox", language: "sv" }, item, "JWT", env, 1000);
  assert.ok(sandbox.url.startsWith("https://api.sandbox.push.apple.com/3/device/"));
  assert.equal(JSON.parse(sandbox.init.body).aps.alert.body, "Rubrik");
});

test("APNs responses", () => {
  assert.equal(classifyApns(200, ""), "ok");
  assert.equal(classifyApns(410, '{"reason":"Unregistered"}'), "remove");
  assert.equal(classifyApns(400, '{"reason":"BadDeviceToken"}'), "remove");
  assert.equal(classifyApns(400, '{"reason":"DeviceTokenNotForTopic"}'), "remove");
  assert.equal(classifyApns(403, '{"reason":"ExpiredProviderToken"}'), "auth");
  assert.equal(classifyApns(429, '{"reason":"TooManyRequests"}'), "retry");
  assert.equal(classifyApns(503, ""), "retry");
  assert.equal(classifyApns(400, '{"reason":"PayloadTooLarge"}'), "drop");
});

const serviceAccount = {
  type: "service_account",
  project_id: "nordic-crypto-test",
  client_email: "push@nordic-crypto-test.iam.gserviceaccount.com",
  private_key: keys.rsaPem,
  token_uri: "https://oauth2.googleapis.com/token",
};

test("FCM: service account JWT for the OAuth token endpoint (RS256)", async () => {
  const sa = parseServiceAccount(JSON.stringify(serviceAccount));
  const req = await fcmTokenRequest(sa, 1_790_000_000);
  assert.equal(req.url, "https://oauth2.googleapis.com/token");
  assert.equal(req.init.headers["content-type"], "application/x-www-form-urlencoded");
  const form = new URLSearchParams(req.init.body);
  assert.equal(form.get("grant_type"), "urn:ietf:params:oauth:grant-type:jwt-bearer");
  const [h, c, s] = form.get("assertion").split(".");
  assert.deepEqual(dec(h), { alg: "RS256", typ: "JWT" });
  assert.deepEqual(dec(c), {
    iss: serviceAccount.client_email, scope: FCM_SCOPE, aud: serviceAccount.token_uri,
    iat: 1_790_000_000, exp: 1_790_003_600,
  });
  const v = createVerify("RSA-SHA256");
  v.update(`${h}.${c}`);
  assert.ok(v.verify(keys.rsaPublic, Buffer.from(b64urlDecode(s))));
});

test("FCM: send request shape (HTTP v1)", () => {
  const sa = parseServiceAccount(serviceAccount);
  const item = { id: "abc", country: "DK", source_name: "Børsen", title: "Overskrift", title_en: "Headline", language_code: "da", title_i18n: {} };
  const req = fcmRequest(sa, "ya29.token", { token: "fcm-token-1", language: "da" }, item);
  assert.equal(req.url, "https://fcm.googleapis.com/v1/projects/nordic-crypto-test/messages:send");
  assert.equal(req.init.headers.authorization, "Bearer ya29.token");
  const body = JSON.parse(req.init.body);
  assert.equal(body.message.token, "fcm-token-1");
  assert.deepEqual(body.message.notification, { title: "Børsen · Danmark", body: "Overskrift" });
  assert.equal(body.message.data.story, "abc");
  assert.equal(body.message.android.notification.channel_id, "new-stories");
});

test("FCM responses", () => {
  assert.equal(classifyFcm(200, "{}"), "ok");
  assert.equal(classifyFcm(404, '{"error":{"status":"NOT_FOUND","details":[{"errorCode":"UNREGISTERED"}]}}'), "remove");
  assert.equal(classifyFcm(400, '{"error":{"message":"The registration token is not a valid FCM registration token"}}'), "remove");
  assert.equal(classifyFcm(401, "{}"), "auth");
  assert.equal(classifyFcm(429, "{}"), "retry");
  assert.equal(classifyFcm(500, "{}"), "retry");
  assert.equal(classifyFcm(400, '{"error":{"message":"Invalid JSON payload"}}'), "drop");
  assert.equal(parseServiceAccount("not json"), null);
  assert.equal(parseServiceAccount('{"project_id":"x"}'), null);
});
