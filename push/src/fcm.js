// Firebase Cloud Messaging HTTP v1 with a service account (OAuth 2.0 JWT bearer grant, RS256).
import { signJwt } from "./jwt.js";
import { fcmMessage } from "./payload.js";

export const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";

export function parseServiceAccount(raw) {
  if (!raw) return null;
  try {
    const sa = typeof raw === "string" ? JSON.parse(raw) : raw;
    if (!sa.client_email || !sa.private_key || !sa.project_id) return null;
    return {
      clientEmail: sa.client_email,
      privateKey: sa.private_key,
      projectId: sa.project_id,
      tokenUri: sa.token_uri || "https://oauth2.googleapis.com/token",
    };
  } catch {
    return null;
  }
}

export function fcmConfigured(env) {
  return parseServiceAccount(env.FCM_SERVICE_ACCOUNT_JSON) !== null;
}

/** The token request: a signed JWT exchanged for a one-hour access token. */
export async function fcmTokenRequest(sa, iat) {
  const assertion = await signJwt("RS256", { typ: "JWT" }, {
    iss: sa.clientEmail,
    scope: FCM_SCOPE,
    aud: sa.tokenUri,
    iat,
    exp: iat + 3600,
  }, sa.privateKey);
  return {
    url: sa.tokenUri,
    init: {
      method: "POST",
      headers: { "content-type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion }).toString(),
    },
  };
}

export function fcmRequest(sa, accessToken, device, item) {
  return {
    url: `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(sa.projectId)}/messages:send`,
    init: {
      method: "POST",
      headers: { authorization: `Bearer ${accessToken}`, "content-type": "application/json" },
      body: JSON.stringify({ message: fcmMessage(device.token, item, device.language) }),
    },
  };
}

/** ok | remove | auth | retry | drop, like classifyApns. */
export function classifyFcm(status, body) {
  if (status === 200) return "ok";
  let err = {};
  try { err = JSON.parse(body || "{}").error || {}; } catch { err = {}; }
  const codes = (err.details || []).map((d) => d && d.errorCode).filter(Boolean);
  if (status === 404 || codes.includes("UNREGISTERED")) return "remove";
  if (status === 400 && /registration token/i.test(err.message || "")) return "remove";
  if (status === 401) return "auth";
  if (status === 429 || status >= 500 || codes.includes("QUOTA_EXCEEDED") || codes.includes("UNAVAILABLE")) return "retry";
  return "drop";
}
