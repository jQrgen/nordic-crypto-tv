#!/bin/sh
# Replaces the bundled API snapshot with the published API v1 files.
# Run from the repo root: support/refresh_snapshot.sh
set -e
BASE="${NC_API_BASE:-https://raw.githubusercontent.com/jQrgen/nordic-crypto/gh-pages/api/v1}"
DIR=NordicCrypto/Resources/Snapshot
mkdir -p "$DIR/newsletters"
for p in news.json events.json newsletters.json sources.json orgchart.json academia.json; do
  curl -fsS --max-time 30 "$BASE/$p" -o "$DIR/$p"
done
for id in $(python3 -c "import json;print(' '.join(i['id'] for i in json.load(open('$DIR/newsletters.json'))['issues']))"); do
  curl -fsS --max-time 30 "$BASE/newsletters/$id.json" -o "$DIR/newsletters/$id.json"
done
python3 -c "import json;d=json.load(open('$DIR/news.json'));print('snapshot generated', d.get('generated_at'), 'stories', d.get('count'))"
