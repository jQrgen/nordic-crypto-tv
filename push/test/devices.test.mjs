import { test } from "node:test";
import assert from "node:assert/strict";
import { handleFetch } from "../src/worker.js";
import { parseRegistration } from "../src/devices.js";
import { FakeD1 } from "./d1.mjs";

const APPLE = "a1".repeat(32);
const FCM = "fGx7:APA91b" + "Z".repeat(140);
const base = "https://push.example/";

function req(method, path, body, headers = {}) {
  return new Request(base + path.replace(/^\//, ""), {
    method,
    headers: { "content-type": "application/json", "cf-connecting-ip": "203.0.113.9", ...headers },
    body: body === undefined ? undefined : typeof body === "string" ? body : JSON.stringify(body),
  });
}

test("parseRegistration validates and normalises", () => {
  const ok = parseRegistration({ token: APPLE.toUpperCase(), platform: "iOS", countries: ["NO", "SE", "NO"], language: "nn", environment: "sandbox" }, 5);
  assert.deepEqual(ok.device, { token: APPLE, platform: "ios", environment: "sandbox", language: "nn", countries: ["NO", "SE"], updated_at: 5 });
  assert.equal(parseRegistration({ token: FCM, platform: "android", countries: [], language: "klingon", environment: "sandbox" }, 1).device.environment, "production");
  assert.equal(parseRegistration({ token: FCM, platform: "android", countries: [], language: "klingon" }, 1).device.language, "en");
  assert.equal(parseRegistration({ token: APPLE, platform: "tvos", countries: [] }).error, "bad_platform");
  assert.equal(parseRegistration({ token: "xyz", platform: "ios", countries: [] }).error, "bad_token");
  assert.equal(parseRegistration({ token: APPLE, platform: "ios", countries: ["US"] }).error, "bad_countries");
  assert.equal(parseRegistration({ token: APPLE, platform: "ios", countries: "NO" }).error, "bad_countries");
  assert.equal(parseRegistration({ token: APPLE, platform: "ios", countries: [], environment: "dev" }).error, "bad_environment");
  assert.equal(parseRegistration([]).error, "bad_body");
});

test("register, update and delete a device; only token and preferences are stored", async () => {
  const DB = new FakeD1();
  const env = { DB };
  let res = await handleFetch(req("POST", "/v1/devices", { token: APPLE, platform: "ipados", countries: ["NO"], language: "nb", name: "Ola's iPad" }), env, 1000);
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), { ok: true, stored: true, delivery: false });
  res = await handleFetch(req("POST", "/v1/devices", { token: APPLE, platform: "ipados", countries: ["SE", "DK"], language: "sv" }), env, 2000);
  assert.equal(res.status, 200);
  const rows = DB.rows("SELECT * FROM devices");
  assert.deepEqual(rows, [{ token: APPLE, platform: "ipados", environment: "production", language: "sv", countries: ",SE,DK,", updated_at: 2000 }]);
  assert.ok(!JSON.stringify(rows).includes("203.0.113.9"));
  res = await handleFetch(req("DELETE", "/v1/devices/" + APPLE), env);
  assert.deepEqual(await res.json(), { ok: true, removed: true });
  assert.equal(DB.rows("SELECT * FROM devices").length, 0);
  res = await handleFetch(req("DELETE", "/v1/devices/" + APPLE), env);
  assert.deepEqual(await res.json(), { ok: true, removed: false });
});

test("no countries means nothing is kept", async () => {
  const DB = new FakeD1();
  await handleFetch(req("POST", "/v1/devices", { token: FCM, platform: "android", countries: ["FI"], language: "fi" }), { DB });
  const res = await handleFetch(req("POST", "/v1/devices", { token: FCM, platform: "android", countries: [], language: "fi" }), { DB });
  assert.deepEqual(await res.json(), { ok: true, stored: false, delivery: false });
  assert.equal(DB.rows("SELECT * FROM devices").length, 0);
});

test("delivery tells the app whether this server has credentials for its platform", async () => {
  const DB = new FakeD1();
  const env = { DB, APNS_KEY_P8: "k", APNS_KEY_ID: "i", APNS_TEAM_ID: "t", APNS_TOPIC: "no.cryptonordic.tv" };
  const res = await handleFetch(req("POST", "/v1/devices", { token: APPLE, platform: "macos", countries: ["IS"], language: "is" }), env);
  assert.equal((await res.json()).delivery, true);
  const health = await (await handleFetch(req("GET", "/v1/health"), env)).json();
  assert.equal(health.apns, true);
  assert.equal(health.fcm, false);
});

test("bad requests, methods, size and rate limits", async () => {
  const DB = new FakeD1();
  const env = { DB };
  assert.equal((await handleFetch(req("POST", "/v1/devices", "{not json"), env)).status, 400);
  assert.equal((await handleFetch(req("POST", "/v1/devices", { token: APPLE, platform: "tvos", countries: ["NO"] }), env)).status, 400);
  assert.equal((await handleFetch(req("POST", "/v1/devices", "x".repeat(5000)), env)).status, 413);
  assert.equal((await handleFetch(req("GET", "/v1/devices"), env)).status, 405);
  assert.equal((await handleFetch(req("PUT", "/v1/devices/" + APPLE, {}), env)).status, 405);
  assert.equal((await handleFetch(req("DELETE", "/v1/devices/%E0%A4%A"), env)).status, 400);
  assert.equal((await handleFetch(req("GET", "/nope"), env)).status, 404);
  const keys = [];
  const limited = { DB, REGISTER_LIMIT: { limit: async ({ key }) => { keys.push(key); return { success: false }; } } };
  const res = await handleFetch(req("POST", "/v1/devices", { token: APPLE, platform: "ios", countries: ["NO"] }), limited);
  assert.equal(res.status, 429);
  assert.equal(DB.rows("SELECT * FROM devices").length, 0);
  assert.deepEqual(keys, ["ip:203.0.113.9"]);
});
