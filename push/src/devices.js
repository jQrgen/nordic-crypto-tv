// POST /v1/devices and DELETE /v1/devices/:token. No account: the push token is the key.
import { LANGS } from "./copy.js";

export const PLATFORMS = { ios: "apns", ipados: "apns", macos: "apns", visionos: "apns", android: "fcm" };
export const COUNTRIES = ["NO", "SE", "DK", "FI", "IS", "NORDIC", "EU"];
export const MAX_BODY = 4096;

export function transportFor(platform) {
  return PLATFORMS[platform] || null;
}

/** APNs tokens are hex (32 bytes today); FCM registration tokens are URL-safe text. */
export function validToken(platform, token) {
  if (typeof token !== "string") return false;
  if (transportFor(platform) === "apns") return /^[0-9a-f]{64,200}$/i.test(token);
  if (transportFor(platform) === "fcm") return /^[A-Za-z0-9_:-]{32,4096}$/.test(token);
  return false;
}

/** Validates a registration. Returns {device} or {error}. */
export function parseRegistration(body, nowMs) {
  if (!body || typeof body !== "object" || Array.isArray(body)) return { error: "bad_body" };
  const platform = typeof body.platform === "string" ? body.platform.toLowerCase() : "";
  if (!transportFor(platform)) return { error: "bad_platform" };
  if (!validToken(platform, body.token)) return { error: "bad_token" };
  if (!Array.isArray(body.countries) || body.countries.length > COUNTRIES.length * 2) return { error: "bad_countries" };
  const countries = [];
  for (const c of body.countries) {
    if (!COUNTRIES.includes(c)) return { error: "bad_countries" };
    if (!countries.includes(c)) countries.push(c);
  }
  const language = LANGS.includes(body.language) ? body.language : "en";
  let environment = "production";
  if (body.environment !== undefined) {
    if (body.environment !== "production" && body.environment !== "sandbox") return { error: "bad_environment" };
    if (transportFor(platform) === "apns") environment = body.environment;
  }
  const token = transportFor(platform) === "apns" ? body.token.toLowerCase() : body.token;
  return { device: { token, platform, environment, language, countries, updated_at: nowMs } };
}

export function countriesColumn(countries) {
  return "," + countries.join(",") + ",";
}
