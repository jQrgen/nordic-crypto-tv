#!/bin/sh
# Takes one 1920x1080 screenshot per screen from a booted tvOS simulator.
# Usage: support/screenshots.sh <simulator-id> <path/to/Nordic Crypto.app> <out-dir>
set -e
SIM="$1"; APP="$2"; OUT="$3"
mkdir -p "$OUT"
xcrun simctl install "$SIM" "$APP"
shot() {
  name="$1"; shift
  xcrun simctl terminate "$SIM" no.cryptonordic.tv 2>/dev/null || true
  xcrun simctl launch "$SIM" no.cryptonordic.tv "$@" >/dev/null
  sleep 5
  xcrun simctl io "$SIM" screenshot "$OUT/$name.png" >/dev/null 2>&1
  echo "$OUT/$name.png"
}
shot 1-top
shot 2-nordics -NCScreen nordics
shot 3-events -NCScreen events
shot 4-newsletter -NCScreen brief
shot 5-story -NCOpen story
shot 6-event -NCScreen events -NCOpen event
shot 7-reader -NCScreen brief -NCOpen reader
