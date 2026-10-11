#!/usr/bin/env bash
# Deploys the app push Worker: finds or creates the D1 database, applies the
# migrations, deploys, and checks /v1/health. Used by .github/workflows/push.yml
# and by hand. Needs CLOUDFLARE_API_TOKEN (and CLOUDFLARE_ACCOUNT_ID when the
# token sees more than one account). Never prints a secret.
# Token permissions: Account > Workers Scripts > Edit, Account > D1 > Edit,
# Account > Account Settings > Read.
set -euo pipefail
cd "$(dirname "$0")"
DB_NAME=nordic-crypto-app-push
[ -n "${CLOUDFLARE_API_TOKEN:-}" ] || { echo "CLOUDFLARE_API_TOKEN is not set"; exit 1; }
[ -d node_modules/wrangler ] || npm ci --no-audit --no-fund
wr() { npx --no-install wrangler "$@"; }

id=$(wr d1 list --json | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const r=JSON.parse(s).find(d=>d.name===process.argv[1]);process.stdout.write(r?r.uuid:"")})' "$DB_NAME")
if [ -z "$id" ]; then
  echo "creating D1 database $DB_NAME"
  wr d1 create "$DB_NAME" >/dev/null
  id=$(wr d1 list --json | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const r=JSON.parse(s).find(d=>d.name===process.argv[1]);process.stdout.write(r?r.uuid:"")})' "$DB_NAME")
fi
[ -n "$id" ] || { echo "could not find or create the D1 database $DB_NAME"; exit 1; }
echo "D1 $DB_NAME: $id"

# The committed wrangler.toml keeps a placeholder id; deploy from a copy with the real one.
sed "s/^database_id = \"00000000-0000-0000-0000-000000000000\"/database_id = \"$id\"/" wrangler.toml > wrangler.deploy.toml
grep -q "database_id = \"$id\"" wrangler.deploy.toml || { echo "could not set database_id"; exit 1; }

node scripts/gen-copy.mjs --check
wr d1 migrations apply "$DB_NAME" --remote --config wrangler.deploy.toml
out=$(wr deploy --config wrangler.deploy.toml 2>&1) || { echo "$out"; exit 1; }
echo "$out" | grep -viE 'token|secret|bearer' | tail -15
url=$(echo "$out" | grep -oE 'https://[A-Za-z0-9.-]+\.workers\.dev' | head -1 || true)
[ -n "$url" ] || { echo "no workers.dev URL in the deploy output"; exit 1; }
echo "worker URL: $url"
for _ in $(seq 1 20); do
  if body=$(curl -fsS --max-time 10 "$url/v1/health"); then
    echo "health: $body"
    exit 0
  fi
  sleep 3
done
echo "health check failed at $url/v1/health"
exit 1
