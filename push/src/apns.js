// Apple Push Notification service, token-based (JWT ES256 with the team's .p8 key).
// Workers' fetch() speaks HTTP/2 to APNs from the Cloudflare edge; `wrangler dev`
// on a laptop does not, so APNs only works from the deployed Worker.
import { signJwt } from "./jwt.js";
import { apnsPayload } from "./payload.js";

export const APNS_HOSTS = {
  production: "https://api.push.apple.com",
  sandbox: "https://api.sandbox.push.apple.com",
};

export function apnsConfigured(env) {
  return Boolean(env.APNS_KEY_P8 && env.APNS_KEY_ID && env.APNS_TEAM_ID && env.APNS_TOPIC);
}

/** Provider token. Apple wants it renewed after 20-60 minutes, and not more often than every 20. */
export function apnsJwt(env, iat) {
  return signJwt("ES256", { kid: env.APNS_KEY_ID }, { iss: env.APNS_TEAM_ID, iat }, env.APNS_KEY_P8);
}

export function apnsRequest(device, item, jwt, env, nowSec) {
  const host = APNS_HOSTS[device.environment] || APNS_HOSTS.production;
  return {
    url: `${host}/3/device/${device.token}`,
    init: {
      method: "POST",
      headers: {
        authorization: `bearer ${jwt}`,
        "apns-topic": env.APNS_TOPIC,
        "apns-push-type": "alert",
        "apns-priority": "10",
        "apns-expiration": String(nowSec + 6 * 3600),
        "apns-collapse-id": String(item.id).slice(0, 64),
        "content-type": "application/json",
      },
      body: JSON.stringify(apnsPayload(item, device.language)),
    },
  };
}

const GONE = new Set(["BadDeviceToken", "DeviceTokenNotForTopic", "Unregistered"]);
const AUTH = new Set(["ExpiredProviderToken", "InvalidProviderToken", "MissingProviderToken"]);

/** ok | remove (token is dead) | auth (renew the JWT, try again) | retry | drop (give up on this one). */
export function classifyApns(status, body) {
  if (status === 200) return "ok";
  let reason = "";
  try { reason = JSON.parse(body || "{}").reason || ""; } catch { reason = ""; }
  if (status === 410 || GONE.has(reason)) return "remove";
  if (status === 403 && AUTH.has(reason)) return "auth";
  if (status === 429 || status >= 500 || reason === "TooManyProviderTokenUpdates") return "retry";
  return "drop";
}
