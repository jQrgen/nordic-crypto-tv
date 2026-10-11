// Throwaway keys made for each test run. Never real credentials.
import { generateKeyPairSync } from "node:crypto";

export function testKeys() {
  const ec = generateKeyPairSync("ec", { namedCurve: "P-256" });
  const rsa = generateKeyPairSync("rsa", { modulusLength: 2048 });
  return {
    ecPem: ec.privateKey.export({ type: "pkcs8", format: "pem" }),
    ecPublic: ec.publicKey,
    rsaPem: rsa.privateKey.export({ type: "pkcs8", format: "pem" }),
    rsaPublic: rsa.publicKey,
  };
}
