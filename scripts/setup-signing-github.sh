#!/usr/bin/env bash
# One-time TestFlight setup for github.com/jQrgen/nordic-crypto-tv (iPhone, iPad,
# Apple TV, Apple Vision Pro and Mac), on your PERSONAL Apple Developer account
# (team YQBXSUUVJD).
#
#   bash scripts/setup-signing-github.sh \
#     --key-id KEYID --issuer-id ISSUER --p8 /path/to/AuthKey_KEYID.p8 \
#     [--team-id YQBXSUUVJD] [--bundle-id no.cryptonordic.tv]
#
# Anything not given as an argument is asked for (input is not echoed).
#
# Prerequisites:
#   - the App Store Connect app for no.cryptonordic.tv (it exists: "Nordic Crypto");
#   - an App Store Connect API key (role Admin or App Manager) and its .p8;
#   - gh logged in to github.com as jQrgen (scopes repo, workflow);
#   - the match password of jQrgen/nordic-crypto-wallet-certificates in your
#     login keychain (service "nordic-crypto-wallet-match", account
#     MATCH_PASSWORD), as left there by the wallet's setup script. The two apps
#     share that certificates repo and its distribution certificate;
#   - Ruby 3.x + bundler, ssh-keygen.
#
# What it does:
#   1. checks the certificates repo is private and on branch main;
#   2. stores MATCH_PASSWORD (read from your login keychain) as a secret;
#   3. stores the App Store Connect API key as secrets;
#   4. runs `fastlane match appstore` (readonly false) for the bundle id with a
#      temporary keychain, once per profile platform, so CI can stay readonly:
#        --platform ios    iOS App Store profile (Apple issues it for iOS and
#                          visionOS; match has no visionos platform, and the
#                          visionOS build is signed with this profile)
#        --platform tvos   tvOS App Store profile
#        --platform macos  Mac App Store profile, plus a Mac Installer
#                          Distribution certificate for the .pkg
#                          (--additional_cert_types mac_installer_distribution)
#      Apple Distribution certificate 9A9994RT53 already in the repo is reused.
#      The certificates repo is reached over HTTPS with your gh login;
#   5. verifies each with a readonly match in a fresh temporary keychain;
#   6. creates a new read-only deploy key on the certificates repo for this
#      repo's CI, stores its private key as the secret MATCH_GIT_PRIVATE_KEY and
#      checks it can read the repo over SSH the same way the workflow does;
#   7. sets the variables APPLE_TEAM_ID, MATCH_GIT_URL and MATCH_GIT_BRANCH.
#
# Secrets live only in shell variables, in 0600 files inside a private temp dir
# that is deleted on exit, in your login keychain and in GitHub. Values reach gh
# on stdin, never argv. Nothing secret is printed. Safe to run again.
set -euo pipefail
umask 077

APP_REPO="jQrgen/nordic-crypto-tv"
CERTS_REPO="jQrgen/nordic-crypto-wallet-certificates"
CERTS_HTTPS="https://github.com/$CERTS_REPO.git"
CERTS_SSH="git@github.com:$CERTS_REPO.git"
MATCH_BRANCH="main"
FORBIDDEN_TEAM="8A87667ULD"
KC_SERVICE="nordic-crypto-wallet-match"
KC_ACCOUNT="MATCH_PASSWORD"
DEPLOY_KEY_TITLE="nordic-crypto-tv CI (read-only)"
ROOT=$(cd "$(dirname "$0")/.." && pwd)

KEY_ID="" ISSUER_ID="" P8_PATH="" TEAM_ID="YQBXSUUVJD" BUNDLE_ID="no.cryptonordic.tv"
while [ $# -gt 0 ]; do
  case "$1" in
    --key-id) KEY_ID="$2"; shift 2 ;;
    --issuer-id) ISSUER_ID="$2"; shift 2 ;;
    --p8) P8_PATH="$2"; shift 2 ;;
    --team-id) TEAM_ID="$2"; shift 2 ;;
    --bundle-id) BUNDLE_ID="$2"; shift 2 ;;
    -h|--help) sed -n '2,47p' "$0"; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

say() { printf '\n==> %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
ask() { # ask VAR "prompt": read without echo
  local __v
  if [ -z "${!1}" ]; then
    read -r -s -p "$2: " __v; echo
    printf -v "$1" '%s' "$__v"
  fi
  [ -n "${!1}" ] || die "$2 is required"
}

for c in gh git python3 ruby bundle security openssl base64 ssh ssh-keygen curl; do
  command -v "$c" >/dev/null || die "$c is required"
done
gh auth status --hostname github.com >/dev/null 2>&1 || die "gh is not logged in to github.com (gh auth login)"

ask KEY_ID "App Store Connect API key id"
ask ISSUER_ID "App Store Connect issuer id"
ask P8_PATH "Path to the .p8 file"
P8_PATH="${P8_PATH/#\~/$HOME}"
[ -f "$P8_PATH" ] || die "No file at the .p8 path given"
grep -q "BEGIN PRIVATE KEY" "$P8_PATH" || die "The .p8 file does not look like an App Store Connect key"
[ "$TEAM_ID" != "$FORBIDDEN_TEAM" ] || die "That is the Bitcoin Unlimited team. Use your personal team."

TMP=$(mktemp -d "${TMPDIR:-/tmp}/nctv-signing.XXXXXX")
KEYCHAIN="nctv-match-setup-$$.keychain"
ORIG_KEYCHAINS=""
cleanup() {
  if [ -n "$ORIG_KEYCHAINS" ]; then
    # shellcheck disable=SC2086
    security list-keychains -d user -s $ORIG_KEYCHAINS
  fi
  security delete-keychain "$KEYCHAIN" >/dev/null 2>&1 || true
  rm -rf "$TMP"
}
trap cleanup EXIT

# put_secret NAME VALUE_VAR_NAME: the value goes to gh on stdin from a 0600 file.
put_secret() {
  local f="$TMP/secret"
  printf '%s' "${!2}" > "$f"
  gh secret set "$1" --repo "$APP_REPO" < "$f" >/dev/null
  rm -f "$f"
  echo "   secret $1 set"
}
put_var() { # put_var NAME VALUE (not secret)
  gh variable set "$1" --repo "$APP_REPO" --body "$2" >/dev/null
  echo "   variable $1=$2"
}
kc_get() { security find-generic-password -s "$KC_SERVICE" -a "$KC_ACCOUNT" -w 2>/dev/null; }

# 1. Certificates repo
say "1. Certificates repo $CERTS_REPO"
gh repo view "$CERTS_REPO" >/dev/null 2>&1 || die "$CERTS_REPO not found (run the wallet's scripts/setup-signing-github.sh first)"
VIS=$(gh repo view "$CERTS_REPO" --json visibility --jq .visibility)
[ "$VIS" = PRIVATE ] || die "$CERTS_REPO is $VIS, not private. Fix that first."
DEFAULT_BRANCH=$(gh repo view "$CERTS_REPO" --json defaultBranchRef --jq .defaultBranchRef.name)
[ "$DEFAULT_BRANCH" = "$MATCH_BRANCH" ] || die "$CERTS_REPO's default branch is '$DEFAULT_BRANCH', expected $MATCH_BRANCH"
echo "   private, branch $MATCH_BRANCH"

# 2. MATCH_PASSWORD: the certificates repo's existing password, from the keychain.
say "2. MATCH_PASSWORD"
MATCH_PASSWORD=$(kc_get || true)
[ -n "$MATCH_PASSWORD" ] || die "No match password in your login keychain (service $KC_SERVICE, account $KC_ACCOUNT). It is the password the wallet's setup stored; add it with: security add-generic-password -s $KC_SERVICE -a $KC_ACCOUNT -w"
echo "   read from your login keychain (service $KC_SERVICE)"
put_secret MATCH_PASSWORD MATCH_PASSWORD

# 3. App Store Connect API key
say "3. App Store Connect API key -> secrets"
# shellcheck disable=SC2034  # read indirectly by put_secret
P8_B64=$(base64 -i "$P8_PATH" | tr -d '\n')
put_secret APP_STORE_CONNECT_API_KEY_ID KEY_ID
put_secret APP_STORE_CONNECT_API_KEY_ISSUER_ID ISSUER_ID
put_secret APP_STORE_CONNECT_API_KEY P8_B64
unset P8_B64

# fastlane as pinned in this repo's Gemfile.lock, in a private bundle path.
say "Installing fastlane (Gemfile.lock) into ~/.cache/nordic-crypto-tv-fastlane"
export BUNDLE_GEMFILE="$ROOT/Gemfile"
export BUNDLE_PATH="$HOME/.cache/nordic-crypto-tv-fastlane/vendor/bundle"
bundle install --quiet --jobs 4 --retry 3
export FASTLANE_SKIP_UPDATE_CHECK=1 FASTLANE_HIDE_CHANGELOG=1 FASTLANE_OPT_OUT_USAGE=1 LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# API key file for match (key content inside; 0600 in the private temp dir)
API_JSON="$TMP/asc_api_key.json"
KEY_ID="$KEY_ID" ISSUER_ID="$ISSUER_ID" P8_PATH="$P8_PATH" python3 -I - "$API_JSON" <<'PY'
import json, os, sys
json.dump({"key_id": os.environ["KEY_ID"], "issuer_id": os.environ["ISSUER_ID"],
           "key": open(os.environ["P8_PATH"]).read(), "in_house": False,
           "duration": 1200}, open(sys.argv[1], "w"))
PY

# git over HTTPS to github.com with your gh login, for match only (environment
# config; your global git config is not changed).
export GIT_CONFIG_COUNT=2
export GIT_CONFIG_KEY_0="credential.https://github.com.helper" GIT_CONFIG_VALUE_0=""
export GIT_CONFIG_KEY_1="credential.https://github.com.helper" GIT_CONFIG_VALUE_1="!gh auth git-credential"
export GIT_TERMINAL_PROMPT=0

# Temporary keychain: the certificate never lands in the login keychain.
KC_PASS=$(openssl rand -hex 24)
ORIG_KEYCHAINS=$(security list-keychains -d user | tr -d '"' | xargs)
fresh_keychain() {
  security delete-keychain "$KEYCHAIN" >/dev/null 2>&1 || true
  security create-keychain -p "$KC_PASS" "$KEYCHAIN"
  security set-keychain-settings -lut 3600 "$KEYCHAIN"
  security unlock-keychain -p "$KC_PASS" "$KEYCHAIN"
  # shellcheck disable=SC2086
  security list-keychains -d user -s "$KEYCHAIN" $ORIG_KEYCHAINS
}

run_match() { # run_match true|false PLATFORM [extra match args]
  local readonly_flag="$1" platform="$2"; shift 2
  ( cd "$TMP" && MATCH_PASSWORD="$MATCH_PASSWORD" bundle exec fastlane run match \
      type:appstore \
      platform:"$platform" \
      readonly:"$readonly_flag" \
      storage_mode:git \
      git_url:"$CERTS_HTTPS" \
      git_branch:"$MATCH_BRANCH" \
      app_identifier:"$BUNDLE_ID" \
      team_id:"$TEAM_ID" \
      api_key_path:"$API_JSON" \
      keychain_name:"$KEYCHAIN" \
      keychain_password:"$KC_PASS" \
      shallow_clone:true "$@" )
}

# 4. match appstore per profile platform (reuses the certificate, adds profiles)
MAC_INSTALLER="additional_cert_types:mac_installer_distribution"
for platform in ios tvos macos; do
  say "4. fastlane match appstore --platform $platform (readonly false) for $BUNDLE_ID, team $TEAM_ID"
  extra=()
  [ "$platform" = macos ] && extra=("$MAC_INSTALLER")
  fresh_keychain
  run_match false "$platform" ${extra[@]+"${extra[@]}"}
done

# 5. Verify with readonly, as CI runs it
for platform in ios tvos macos; do
  say "5. Verifying $platform: readonly match in a fresh keychain"
  extra=()
  [ "$platform" = macos ] && extra=("$MAC_INSTALLER")
  fresh_keychain
  run_match true "$platform" ${extra[@]+"${extra[@]}"}
  echo "   readonly match OK ($platform)"
done
unset GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0 GIT_CONFIG_KEY_1 GIT_CONFIG_VALUE_1

# 6. Read-only deploy key for this repo's CI
say "6. Read-only deploy key on $CERTS_REPO"
ssh-keygen -q -t ed25519 -N "" -C "nordic-crypto-tv-ci-match" -f "$TMP/deploy_key"
for id in $(gh api "repos/$CERTS_REPO/keys" --jq ".[] | select(.title == \"$DEPLOY_KEY_TITLE\") | .id"); do
  gh api -X DELETE "repos/$CERTS_REPO/keys/$id" >/dev/null
  echo "   removed the previous deploy key (id $id)"
done
gh repo deploy-key add "$TMP/deploy_key.pub" --repo "$CERTS_REPO" --title "$DEPLOY_KEY_TITLE" >/dev/null
echo "   added (read-only)"
curl -fsSL https://api.github.com/meta \
  | python3 -I -c 'import json,sys; [print("github.com", k) for k in json.load(sys.stdin)["ssh_keys"]]' > "$TMP/known_hosts"
GIT_SSH_COMMAND="ssh -F /dev/null -i $TMP/deploy_key -o IdentitiesOnly=yes -o IdentityAgent=none -o UserKnownHostsFile=$TMP/known_hosts -o StrictHostKeyChecking=yes -o BatchMode=yes" \
  git ls-remote --heads "$CERTS_SSH" "$MATCH_BRANCH" >/dev/null \
  || die "The deploy key cannot read $CERTS_SSH"
echo "   deploy key can read $CERTS_SSH"
gh secret set MATCH_GIT_PRIVATE_KEY --repo "$APP_REPO" < "$TMP/deploy_key" >/dev/null
echo "   secret MATCH_GIT_PRIVATE_KEY set"

# 7. Variables (not secret)
say "7. Variables"
put_var APPLE_TEAM_ID "$TEAM_ID"
put_var MATCH_GIT_URL "$CERTS_SSH"
put_var MATCH_GIT_BRANCH "$MATCH_BRANCH"
unset MATCH_PASSWORD KC_PASS

say "Done. Every push to main now builds iPhone/iPad, Apple TV, Vision Pro and Mac and uploads them to TestFlight."
echo "   Run one now: gh workflow run testflight.yml --repo $APP_REPO --ref main"
echo "   Keep the .p8 somewhere safe offline; Apple will not let you download it again."
