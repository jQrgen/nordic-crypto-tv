#!/usr/bin/env bash
# One-time setup of the app push server (push/, docs/push.md). Run by the
# owner on a trusted Mac; agents never run it. It never prints a secret value:
# values go from files or a hidden prompt straight into `wrangler secret put`
# and `gh secret set` on stdin.
#
#   bash scripts/setup-push-secrets.sh \
#     --p8 ~/keys/AuthKey_ABCDE12345.p8 --key-id ABCDE12345 \
#     [--team-id YQBXSUUVJD] \
#     [--fcm-service-account ~/keys/nordic-crypto-push-firebase-adminsdk.json] \
#     [--google-services ~/keys/google-services.json] \
#     [--skip-deploy]
#
# What it does:
#   1. asks for a Cloudflare API token (hidden) unless CLOUDFLARE_API_TOKEN is set;
#      permissions: Account > Workers Scripts > Edit, Account > D1 > Edit,
#      Account > Account Settings > Read
#   2. deploys the Worker once with push/deploy.sh (creates the D1 database)
#   3. Worker secrets: APNS_KEY_P8, APNS_KEY_ID, APNS_TEAM_ID and, when given,
#      FCM_SERVICE_ACCOUNT_JSON
#   4. GitHub secrets on jQrgen/nordic-crypto-tv: CLOUDFLARE_API_TOKEN and
#      CLOUDFLARE_ACCOUNT_ID (the push workflow deploys with them) and, when
#      --google-services is given, FIREBASE_APP_ID, FIREBASE_API_KEY,
#      FIREBASE_PROJECT_ID, FIREBASE_SENDER_ID for the Android build
#
# The APNs key must belong to the personal team YQBXSUUVJD. Never use the
# Bitcoin Unlimited team (8A87667ULD).
set -euo pipefail
REPO=jQrgen/nordic-crypto-tv
ROOT=$(cd "$(dirname "$0")/.." && pwd)
P8="" KEY_ID="" TEAM_ID=YQBXSUUVJD FCM_JSON="" GOOGLE_SERVICES="" SKIP_DEPLOY=""

die() { echo "error: $*" >&2; exit 1; }
say() { printf '\n== %s\n' "$*"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --p8) P8=$2; shift 2 ;;
    --key-id) KEY_ID=$2; shift 2 ;;
    --team-id) TEAM_ID=$2; shift 2 ;;
    --fcm-service-account) FCM_JSON=$2; shift 2 ;;
    --google-services) GOOGLE_SERVICES=$2; shift 2 ;;
    --skip-deploy) SKIP_DEPLOY=1; shift ;;
    -h|--help) sed -n '2,32p' "$0"; exit 0 ;;
    *) die "unknown option $1 (see --help)" ;;
  esac
done

[ -n "$P8" ] && [ -n "$KEY_ID" ] || die "--p8 and --key-id are required (see --help)"
[ "$TEAM_ID" != "8A87667ULD" ] || die "8A87667ULD is the Bitcoin Unlimited team. Use the personal team YQBXSUUVJD."
[[ "$TEAM_ID" =~ ^[A-Z0-9]{10}$ ]] || die "--team-id must be 10 letters/digits"
[[ "$KEY_ID" =~ ^[A-Z0-9]{10}$ ]] || die "--key-id must be the 10-character APNs key id"
[ -r "$P8" ] || die "cannot read $P8"
grep -q -- "-----BEGIN PRIVATE KEY-----" "$P8" || die "$P8 is not an APNs .p8 key"
if [ -n "$FCM_JSON" ]; then
  [ -r "$FCM_JSON" ] || die "cannot read $FCM_JSON"
  node -e 'const s=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));if(s.type!=="service_account"||!s.private_key||!s.client_email||!s.project_id)process.exit(1)' "$FCM_JSON" \
    || die "$FCM_JSON is not a Google service account key"
fi
if [ -n "$GOOGLE_SERVICES" ]; then
  [ -r "$GOOGLE_SERVICES" ] || die "cannot read $GOOGLE_SERVICES"
fi
command -v gh >/dev/null || die "gh is not installed"
command -v node >/dev/null || die "node is not installed"
login=$(gh api user -q .login) || die "gh is not logged in"
[ "$login" = jQrgen ] || die "gh is logged in as $login, expected jQrgen"

if [ -z "${CLOUDFLARE_API_TOKEN:-}" ]; then
  read -r -s -p "Cloudflare API token (input hidden): " CLOUDFLARE_API_TOKEN; echo
fi
[ -n "$CLOUDFLARE_API_TOKEN" ] || die "no Cloudflare API token"
export CLOUDFLARE_API_TOKEN
cf() { curl -fsS -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" "https://api.cloudflare.com/client/v4$1"; }
cf /user/tokens/verify | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const d=JSON.parse(s);process.exit(d.success&&d.result.status==="active"?0:1)})' \
  || die "the Cloudflare token is not active"
if [ -z "${CLOUDFLARE_ACCOUNT_ID:-}" ]; then
  CLOUDFLARE_ACCOUNT_ID=$(cf /accounts | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const r=JSON.parse(s).result;process.stdout.write(r.length===1?r[0].id:"")})')
  [ -n "$CLOUDFLARE_ACCOUNT_ID" ] || die "the token sees no account or several; export CLOUDFLARE_ACCOUNT_ID"
fi
export CLOUDFLARE_ACCOUNT_ID

cd "$ROOT/push"
[ -d node_modules/wrangler ] || npm ci --no-audit --no-fund
if [ -z "$SKIP_DEPLOY" ]; then
  say "deploy the Worker (creates the D1 database on the first run)"
  ./deploy.sh
fi
[ -f wrangler.deploy.toml ] || die "push/wrangler.deploy.toml is missing; run without --skip-deploy once"

put() { # put NAME  (value on stdin)
  npx --no-install wrangler secret put "$1" --config wrangler.deploy.toml >/dev/null
  echo "Worker secret $1 set"
}
say "Worker secrets"
put APNS_KEY_P8 < "$P8"
printf '%s' "$KEY_ID" | put APNS_KEY_ID
printf '%s' "$TEAM_ID" | put APNS_TEAM_ID
if [ -n "$FCM_JSON" ]; then
  node -e 'process.stdout.write(JSON.stringify(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))))' "$FCM_JSON" | put FCM_SERVICE_ACCOUNT_JSON
fi

say "GitHub secrets on $REPO"
printf '%s' "$CLOUDFLARE_API_TOKEN" | gh secret set CLOUDFLARE_API_TOKEN --repo "$REPO"
printf '%s' "$CLOUDFLARE_ACCOUNT_ID" | gh secret set CLOUDFLARE_ACCOUNT_ID --repo "$REPO"
if [ -n "$GOOGLE_SERVICES" ]; then
  # The Android app's Firebase client settings (not the service account). Package no.cryptonordic.app.
  for field in app_id api_key project_id sender_id; do
    node -e '
      const g = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
      const c = (g.client || []).find((x) => x.client_info?.android_client_info?.package_name === "no.cryptonordic.app");
      if (!c) { console.error("no client for no.cryptonordic.app in google-services.json"); process.exit(1); }
      const v = { app_id: c.client_info.mobilesdk_app_id, api_key: (c.api_key || [])[0]?.current_key,
                  project_id: g.project_info.project_id, sender_id: g.project_info.project_number }[process.argv[2]];
      if (!v) process.exit(1);
      process.stdout.write(String(v));' "$GOOGLE_SERVICES" "$field" \
      | gh secret set "FIREBASE_$(echo "$field" | tr a-z A-Z)" --repo "$REPO"
  done
fi

say "done"
echo "The Worker answers at https://nordic-crypto-app-push.<your workers.dev subdomain>.workers.dev/v1/health"
echo "and sends APNs from now on. Pushes to main that touch push/ redeploy it (Push server workflow)."
