import { test } from "node:test";
import assert from "node:assert/strict";
import { apnsPayload, clip, countryName, fcmMessage, headline, notificationText } from "../src/payload.js";

const story = {
  id: "9755cf9957e9",
  country: "NO",
  source_name: "Ságat",
  language_code: "no",
  title: "Innrømmer «litt» kryptoutvinning",
  title_en: "Data-centre firm admits to “a little” crypto mining",
  title_i18n: { sv: "Datacenterföretag medger ”lite” kryptobrytning" },
};

test("headline: source language, then title_i18n, then title_en, then title", () => {
  assert.equal(headline(story, "nb"), story.title);       // no/nb/nn are one family
  assert.equal(headline(story, "nn"), story.title);
  assert.equal(headline(story, "sv"), story.title_i18n.sv);
  assert.equal(headline(story, "de"), story.title_en);
  assert.equal(headline(story, "xx"), story.title_en);    // unknown language is English
  assert.equal(headline({ title: "Only", language_code: "sv" }, "en"), "Only");
});

test("title is source and country in the reader's language", () => {
  assert.deepEqual(notificationText(story, "en"), { title: "Ságat · Norway", body: story.title_en });
  assert.equal(notificationText(story, "nn").title, "Ságat · Noreg");
  assert.equal(notificationText(story, "zh").title, "Ságat · 挪威");
  assert.equal(notificationText({ ...story, country: "NORDIC" }, "en").title, "Ságat");
  assert.equal(notificationText({ id: "x", title: "T" }, "en").title, "Nordic Crypto");
  assert.equal(countryName("SE", "fi"), "Ruotsi");
});

test("long headlines are clipped on a word", () => {
  const long = "word ".repeat(100);
  const c = clip(long, 50);
  assert.ok(c.length <= 50);
  assert.ok(c.endsWith("…"));
  assert.ok(!c.includes("  "));
});

test("APNs payload", () => {
  assert.deepEqual(apnsPayload(story, "sv"), {
    aps: {
      alert: { title: "Ságat · Norge", body: story.title_i18n.sv },
      sound: "default",
      "thread-id": "NO",
    },
    story: "9755cf9957e9",
  });
});

test("FCM v1 message", () => {
  const m = fcmMessage("tok", story, "en");
  assert.deepEqual(m, {
    token: "tok",
    notification: { title: "Ságat · Norway", body: story.title_en },
    data: { story: "9755cf9957e9", country: "NO" },
    android: {
      ttl: "21600s",
      collapse_key: "9755cf9957e9",
      notification: { channel_id: "new-stories", tag: "story-9755cf9957e9", icon: "ic_notification" },
    },
  });
  // FCM data values must be strings.
  for (const v of Object.values(m.data)) assert.equal(typeof v, "string");
});
