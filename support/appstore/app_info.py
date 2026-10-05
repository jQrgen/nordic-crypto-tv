#!/usr/bin/env python3
"""Sets app-level App Store fields through the App Store Connect API:
primary category, copyright on every platform version, and the plain-text
privacy policy Apple TV needs (tvOS cannot open the policy URL).

  ASC_ISSUER_ID=... ASC_KEY_ID=... python3 support/appstore/app_info.py [--dry-run]

Content Rights and the App Privacy questionnaire are legal declarations by
the owner and are left to App Store Connect in the browser.
"""
import argparse
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from upload import ASC, BUNDLE_ID, HERE, LOCALES  # noqa: E402

CATEGORY = "NEWS"
COPYRIGHT = "2026 Jørgen S. Notland"


def policy_text():
    md = open(os.path.join(HERE, "privacy-policy.md")).read()
    text = re.sub(r"^#+\s*", "", md, flags=re.M)          # headings
    text = re.sub(r"\*\*(.+?)\*\*", r"\1", text)           # bold
    text = re.sub(r"`(.+?)`", r"\1", text)                 # code
    return text.strip()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    asc = ASC(os.environ["ASC_ISSUER_ID"], os.environ["ASC_KEY_ID"], args.dry_run)
    app = asc.get("/apps", **{"filter[bundleId]": BUNDLE_ID})["data"][0]

    info = asc.get(f"/apps/{app['id']}/appInfos")["data"]
    info_id = next((i["id"] for i in info if i["attributes"].get("appStoreState") != "READY_FOR_SALE"), info[0]["id"])
    asc.write("PATCH", f"/appInfos/{info_id}", {"data": {"type": "appInfos", "id": info_id, "relationships": {
        "primaryCategory": {"data": {"type": "appCategories", "id": CATEGORY}}}}})
    print("primary category:", CATEGORY)

    text = policy_text()
    for loc in asc.get(f"/appInfos/{info_id}/appInfoLocalizations")["data"]:
        if loc["attributes"]["locale"] in LOCALES:
            asc.write("PATCH", f"/appInfoLocalizations/{loc['id']}", {"data": {"type": "appInfoLocalizations",
                      "id": loc["id"], "attributes": {"privacyPolicyText": text}}})
            print("privacy policy text:", loc["attributes"]["locale"])

    for v in asc.get(f"/apps/{app['id']}/appStoreVersions", limit=50)["data"]:
        if v["attributes"]["appStoreState"] == "PREPARE_FOR_SUBMISSION":
            asc.write("PATCH", f"/appStoreVersions/{v['id']}", {"data": {"type": "appStoreVersions", "id": v["id"],
                      "attributes": {"copyright": COPYRIGHT}}})
            print("copyright:", v["attributes"]["platform"], v["attributes"]["versionString"])
            # Attach the newest processed build of this version and platform.
            builds = asc.get("/builds", **{"filter[app]": app["id"], "filter[processingState]": "VALID",
                             "filter[preReleaseVersion.platform]": v["attributes"]["platform"],
                             "filter[preReleaseVersion.version]": v["attributes"]["versionString"],
                             "sort": "-uploadedDate", "limit": 1})["data"]
            if builds:
                asc.write("PATCH", f"/appStoreVersions/{v['id']}/relationships/build",
                          {"data": {"type": "builds", "id": builds[0]["id"]}})
                print("  build:", builds[0]["attributes"]["version"])
            else:
                print("  no processed build yet")


if __name__ == "__main__":
    main()
