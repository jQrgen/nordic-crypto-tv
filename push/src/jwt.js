// Small JWS helpers on WebCrypto (Workers and Node 20+). No dependencies.

const enc = new TextEncoder();

export function b64url(bytes) {
  const u8 = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
  let s = "";
  for (let i = 0; i < u8.length; i++) s += String.fromCharCode(u8[i]);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

export function b64urlJson(obj) {
  return b64url(enc.encode(JSON.stringify(obj)));
}

export function b64urlDecode(text) {
  const s = text.replace(/-/g, "+").replace(/_/g, "/");
  const bin = atob(s + "=".repeat((4 - (s.length % 4)) % 4));
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

/** DER bytes of a PEM "PRIVATE KEY" (PKCS#8), as in an APNs .p8 file or a Google service account. */
export function pemToDer(pem) {
  const body = String(pem || "")
    .replace(/\\n/g, "\n")
    .replace(/-----BEGIN [A-Z ]+-----/, "")
    .replace(/-----END [A-Z ]+-----/, "")
    .replace(/\s+/g, "");
  if (!body) throw new Error("empty key");
  const bin = atob(body);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

const ALGS = {
  ES256: { import: { name: "ECDSA", namedCurve: "P-256" }, sign: { name: "ECDSA", hash: "SHA-256" } },
  RS256: { import: { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, sign: { name: "RSASSA-PKCS1-v1_5" } },
};

/** Signs header.claims with a PKCS#8 PEM key. ES256 signatures come out as raw r||s, which is what JWS wants. */
export async function signJwt(alg, header, claims, pem) {
  const spec = ALGS[alg];
  if (!spec) throw new Error("unsupported alg " + alg);
  const key = await crypto.subtle.importKey("pkcs8", pemToDer(pem), spec.import, false, ["sign"]);
  const input = b64urlJson({ alg, ...header }) + "." + b64urlJson(claims);
  const sig = await crypto.subtle.sign(spec.sign, key, enc.encode(input));
  return input + "." + b64url(sig);
}
